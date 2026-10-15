import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:atur_kos/services/kos_service.dart';
import 'package:atur_kos/utils/format_utils.dart';
import 'package:atur_kos/screens/payment/midtrans_snap_payment_dialog.dart';

/// Halaman Mitigasi Kamar Kosong H-30 & Generator Poster Promosi Pemasaran (PRD Modul 5 & 7)
/// Dilengkapi AI Natural Lighting & Touch-up (mempertahankan 100% foto asli kamar tanpa dilebih-lebihkan)
class RoomPosterGeneratorScreen extends StatefulWidget {
  final String? kostId;
  final String kosName;

  const RoomPosterGeneratorScreen({
    super.key,
    required this.kostId,
    required this.kosName,
  });

  @override
  State<RoomPosterGeneratorScreen> createState() => _RoomPosterGeneratorScreenState();
}

class _RoomPosterGeneratorScreenState extends State<RoomPosterGeneratorScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _posterKey = GlobalKey();
  late TabController _tabController;

  List<Map<String, dynamic>> _rooms = [];
  Map<String, dynamic>? _selectedRoom;
  Map<String, dynamic>? _kosProfile;
  Map<String, dynamic> _aiQuota = {'quota': 30, 'used': 0, 'remaining': 30, 'tier': 'juragan'};

  bool _isLoading = true;
  bool _isGeneratingAi = false;
  bool _isUploadingPhoto = false;
  String _aspectRatio = '1:1'; // '1:1' untuk Feed IG atau '9:16' untuk Story WA/IG

  // Preset gaya pencahayaan AI natural (Vibe Presets)
  String _selectedStylePreset = 'bright_daylight';

  // Foto aktif di poster (foto asli kamar sebagai basis utama)
  String? _activePosterPhotoUrl;
  bool _useAiPhoto = true; // true = pakai filter pencahayaan AI, false = foto asli mentah

  final List<Map<String, dynamic>> _stylePresets = [
    {
      'id': 'raw_natural',
      'name': 'Foto Asli Mentah',
      'icon': Icons.camera_alt_rounded,
      'color': const Color(0xFF64748B),
      'desc': '100% foto asli tanpa filter apapun, murni jepretan kamera HP apa adanya',
    },
    {
      'id': 'bright_daylight',
      'name': 'Daylight Cerah',
      'icon': Icons.wb_sunny_rounded,
      'color': const Color(0xFFEA580C),
      'desc': 'Mencerahkan kamar yang remang dengan cahaya lembut alami siang hari',
    },
    {
      'id': 'warm_cozy',
      'name': 'Warm Cozy',
      'icon': Icons.bedtime_rounded,
      'color': const Color(0xFFD97706),
      'desc': 'Pencahayaan temaram hangat yang nyaman, kasur & ruangan tampak tenang',
    },
    {
      'id': 'modern_minimalist',
      'name': 'Modern Clean',
      'icon': Icons.cleaning_services_rounded,
      'color': const Color(0xFF2563EB),
      'desc': 'Meningkatkan ketajaman & kontras agar sprei, meja, dan dinding tampak bersih',
    },
    {
      'id': 'clean_aesthetic',
      'name': 'Soft Natural',
      'icon': Icons.spa_rounded,
      'color': const Color(0xFF059669),
      'desc': 'Warna seimbang natural, aksen kayu & lantai kamar terlihat rapi dan ramah',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      KosService.getH30RadarRooms(widget.kostId),
      KosService.getKosProfile(widget.kostId),
      KosService.getAiQuotaInfo(widget.kostId),
    ]);

    if (mounted) {
      setState(() {
        _rooms = results[0] as List<Map<String, dynamic>>;
        _kosProfile = results[1] as Map<String, dynamic>?;
        _aiQuota = results[2] as Map<String, dynamic>;

        if (_rooms.isNotEmpty) {
          _selectedRoom = _rooms.firstWhere(
            (r) => r['status'] == 'kosong' || r['status'] == 'akan_kosong',
            orElse: () => _rooms.first,
          );

          final roomPhoto = _selectedRoom?['foto_url']?.toString();
          if (roomPhoto != null && roomPhoto.isNotEmpty) {
            _activePosterPhotoUrl = roomPhoto;
            _useAiPhoto = true;
          }
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadRoomPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingPhoto = true);
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final fileName = 'room_${_selectedRoom?['id'] ?? "custom"}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'kamar/$fileName';

      String uploadedUrl = '';
      try {
        await Supabase.instance.client.storage
            .from('ai-room-variations')
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: mimeType, upsert: true),
            );
        uploadedUrl = Supabase.instance.client.storage
            .from('ai-room-variations')
            .getPublicUrl(path);
      } catch (e) {
        debugPrint('Upload error storage fallback: $e');
      }

      if (uploadedUrl.isNotEmpty && mounted) {
        setState(() {
          if (_selectedRoom != null) {
            _selectedRoom!['foto_url'] = uploadedUrl;
          }
          _activePosterPhotoUrl = uploadedUrl;
          _useAiPhoto = true;
        });

        // Simpan foto_url kamar ke database Supabase
        final roomId = _selectedRoom?['id']?.toString();
        if (roomId != null) {
          await Supabase.instance.client
              .from('rooms')
              .update({'foto_url': uploadedUrl})
              .eq('id', roomId);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto kamar asli berhasil diunggah! Siap dipoles oleh AI.'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (err) {
      debugPrint('Error pick image: $err');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _handleGenerateAiVariation() async {
    final room = _selectedRoom;
    final kostId = widget.kostId ?? _kosProfile?['id']?.toString();
    if (room == null || kostId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kamar terlebih dahulu!')),
      );
      return;
    }

    final realPhotoUrl = room['foto_url']?.toString();
    if (realPhotoUrl == null || realPhotoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan ambil atau unggah foto asli kamar terlebih dahulu!'),
          backgroundColor: Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isGeneratingAi = true);

    try {
      final result = await KosService.generateRoomVariationWithAi(
        kostId: kostId,
        roomId: room['id']?.toString(),
        imageUrl: realPhotoUrl,
        stylePreset: _selectedStylePreset,
      );

      if (result['success'] == true) {
        final newRemaining = result['credits_remaining'];

        setState(() {
          // Tetap gunakan foto asli kamar milik pemilik, terpoles dengan filter pencahayaan AI natural
          _activePosterPhotoUrl = realPhotoUrl;
          _useAiPhoto = true;
          if (newRemaining != null) {
            _aiQuota['remaining'] = newRemaining;
            _aiQuota['used'] = ((_aiQuota['used'] as num?)?.toInt() ?? 0) + 1;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(result['message'] ?? 'Pencahayaan foto kamar berhasil disempurnakan!')),
                ],
              ),
              backgroundColor: const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal memproses AI.'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kendala: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingAi = false);
    }
  }

  /// Matriks filter warna AI untuk meningkatkan pencahayaan foto kamar riil secara natural
  ColorFilter? _getColorFilterForPreset(String presetId) {
    if (!_useAiPhoto || presetId == 'raw_natural') {
      return null; // 100% foto asli mentah tanpa filter
    }

    switch (presetId) {
      case 'warm_cozy':
        // Sentuhan hangat lembut: sedikit menaikkan kehangatan lampu kamar tidur
        return const ColorFilter.matrix([
          1.06, 0.01, 0.00, 0, 6,
          0.00, 1.04, 0.00, 0, 5,
          0.00, 0.00, 0.98, 0, 0,
          0.00, 0.00, 0.00, 1, 0,
        ]);
      case 'bright_daylight':
        // Pencahayaan terang alami: mencerahkan kamar yang remang dengan cahaya lembut siang hari
        return const ColorFilter.matrix([
          1.08, 0.00, 0.00, 0, 12,
          0.00, 1.08, 0.00, 0, 12,
          0.00, 0.00, 1.09, 0, 14,
          0.00, 0.00, 0.00, 1, 0,
        ]);
      case 'modern_minimalist':
        // Bersih & jernih: meningkatkan ketajaman detail dinding dan sprei
        return const ColorFilter.matrix([
          1.04, 0.00, 0.00, 0, 6,
          0.00, 1.04, 0.00, 0, 6,
          0.00, 0.00, 1.05, 0, 8,
          0.00, 0.00, 0.00, 1, 0,
        ]);
      case 'clean_aesthetic':
        // Nada warna lembut seimbang: aksen kayu & lantai kamar terlihat ramah
        return const ColorFilter.matrix([
          1.03, 0.01, 0.00, 0, 5,
          0.00, 1.03, 0.00, 0, 4,
          0.00, 0.00, 1.00, 0, 2,
          0.00, 0.00, 0.00, 1, 0,
        ]);
      default:
        return null;
    }
  }

  Future<void> _exportPosterImage() async {
    try {
      final boundary = _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A)),
              SizedBox(width: 8),
              Text('Poster Siap Dipublikasikan!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  pngBytes,
                  height: 260,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Poster resolusi tinggi (3x HD) menggunakan foto asli kamar Anda dengan pencahayaan optimal.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _copyCaption(_generatePromoCaption(_selectedRoom ?? _rooms.first));
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Salin Caption Promosi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Export poster error: $e');
    }
  }

  String _generatePromoCaption(Map<String, dynamic> room) {
    final roomNumber = room['nomor_kamar']?.toString() ?? '01';
    final type = room['tipe']?.toString() ?? 'Standard';
    final price = (room['harga_bulanan'] as num?)?.toDouble() ?? 1200000.0;
    final facilities = (room['fasilitas'] as List?)?.map((e) => e.toString()).toList() ??
        ['Kasur Springbed', 'Lemari', 'Kamar Mandi Dalam', 'WiFi Cepat'];
    final contactNumber = _kosProfile?['nomor_kontak']?.toString() ?? '628123456789';
    final ownerName = _kosProfile?['nama_pemilik_rekening']?.toString() ?? 'Pengelola';
    final cleanPhone = contactNumber.replaceAll(RegExp(r'[^0-9]'), '');

    return '''✨ KAMAR KOS SIAP HUNI - ${widget.kosName.toUpperCase()} ✨

Hai teman-teman pencari kos nyaman dan strategis!
Telah dibuka kesempatan sewa untuk Kamar $roomNumber ($type) di ${widget.kosName}.

💰 Harga Sewa: ${FormatUtils.rupiah(price)} / bulan
📍 Lokasi: Sangat strategis, dekat kampus & perkantoran

🛋️ Fasilitas Unggulan:
${facilities.map((f) => '• $f').join('\n')}

✅ Lingkungan bersih, tenang, aman, dan nyaman untuk istirahat serta belajar.
Yuk segera survei dan amankan kamarmu sebelum terisi!

📲 Hubungi Pengelola via WhatsApp:
https://wa.me/$cleanPhone ($ownerName - ${widget.kosName})''';
  }

  void _copyCaption(String caption) {
    Clipboard.setData(ClipboardData(text: caption));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('Teks promosi berhasil disalin ke clipboard! Siap diposting di WhatsApp/IG.')),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emptyRooms = _rooms.where((r) => r['status'] == 'kosong' || r['status'] == 'akan_kosong').toList();
    final isJuragan = _kosProfile?['tier']?.toString().toLowerCase() == 'juragan';
    final remainingQuota = (_aiQuota['remaining'] as num?)?.toInt() ?? 0;
    final canAccess = isJuragan || remainingQuota > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Poster Promosi & Radar H-30',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
            ),
            Text(
              '${widget.kosName} • Mitigasi Kamar Kosong',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E40AF)),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1E40AF),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF1E40AF),
          indicatorWeight: 3,
          tabs: [
            const Tab(text: 'Generator Poster AI'),
            Tab(text: 'Radar Kamar H-30 (${emptyRooms.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)))
          : (!canAccess
              ? _buildPaywallView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPosterGeneratorTab(),
                    _buildRadarTab(),
                  ],
                )),
    );
  }

  Widget _buildPaywallView() {
    final message = 'Halo Super Admin Atur Kos, saya pemilik kos "${widget.kosName}" (ID: ${widget.kostId}). Saya ingin berlangganan Paket Juragan ⭐ untuk membuka fitur Generator Poster Promosi AI & Radar H-30. Mohon informasi rekening/QRIS pembayaran.';
    final encodedMsg = Uri.encodeComponent(message);
    final waUrl = Uri.parse('https://wa.me/6281234567890?text=$encodedMsg');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFF1D4ED8),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Kuota AI Habis / Perlu Paket Juragan ⭐',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Generator Variasi Foto Kamar AI & Radar Mitigasi H-30 memerlukan kuota aktif Paket Juragan (30 generate per bulan).',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('30x Generate Variasi Foto Kamar AI Setiap Bulan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('Desain Poster Otomatis Feed & Story WA / Instagram', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('Radar Deteksi Penghuni Selesai Sewa H-30', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Column(
                  children: [
                    Text('Biaya Langganan: Rp 50.000 / bln atau Rp 500.000 / thn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E40AF))),
                    SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF2563EB)),
                        SizedBox(width: 6),
                        Text('Pembayaran otomatis via Midtrans Snap (QRIS & VA Semua Bank)', style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final targetKostId = widget.kostId ?? _kosProfile?['id']?.toString() ?? '';
                    if (targetKostId.isNotEmpty) {
                      MidtransSnapPaymentDialog.show(
                        context,
                        kostId: targetKostId,
                        kosName: widget.kosName,
                        initialMonths: 1,
                        onPaymentSuccess: _loadData,
                      );
                    }
                  },
                  icon: const Icon(Icons.payment_rounded, size: 18),
                  label: const Text('Langganan Juragan (Midtrans Snap)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F2648),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      if (await canLaunchUrl(waUrl)) {
                        await launchUrl(waUrl, mode: LaunchMode.externalApplication);
                      } else {
                        await launchUrl(waUrl);
                      }
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Silakan hubungi WhatsApp Super Admin: 0812-3456-7890\nPesan: $message')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.chat_rounded, size: 18, color: Color(0xFF16A34A)),
                  label: const Text('Bantuan Manual via WhatsApp', style: TextStyle(color: Color(0xFF16A34A))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF16A34A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali ke Dasbor', style: TextStyle(color: Color(0xFF64748B))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPosterGeneratorTab() {
    if (_rooms.isEmpty) {
      return const Center(
        child: Text('Belum ada data kamar terdaftar.'),
      );
    }

    final selectedRoom = _selectedRoom ?? _rooms.first;
    final caption = _generatePromoCaption(selectedRoom);
    final roomPhotoUrl = selectedRoom['foto_url']?.toString();
    final remainingQuota = (_aiQuota['remaining'] as num?)?.toInt() ?? 30;
    final totalQuota = (_aiQuota['quota'] as num?)?.toInt() ?? 30;
    final isJuragan = _kosProfile?['tier']?.toString().toLowerCase() == 'juragan';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bar Informasi Kuota AI & Deskripsi Realistis
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFFFBBF24), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Studio Foto & Poster AI Natural',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isJuragan ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isJuragan ? 'JURAGAN' : 'STARTER',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pencahayaan natural foto asli kamar • Sisa kuota: $remainingQuota/$totalQuota bln ini',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Langkah 1: Pilih Kamar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.door_front_door_rounded, size: 18, color: Color(0xFF1E40AF)),
                    SizedBox(width: 8),
                    Text(
                      '1. Pilih Kamar Yang Ingin Dipromosikan:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedRoom['id'].toString(),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _rooms.map((r) {
                    final status = r['status']?.toString() ?? 'kosong';
                    final tag = status == 'kosong'
                        ? '[KOSONG]'
                        : (status == 'akan_kosong' ? '[AKAN KOSONG H-30]' : '[TERISI]');
                    return DropdownMenuItem<String>(
                      value: r['id'].toString(),
                      child: Text('Kamar ${r['nomor_kamar']} (${r['tipe']}) $tag'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedRoom = _rooms.firstWhere((r) => r['id'].toString() == val);
                        final p = _selectedRoom?['foto_url']?.toString();
                        if (p != null && p.isNotEmpty) {
                          _activePosterPhotoUrl = p;
                        }
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Langkah 2: Foto Kamar Riil (Wajib Asli)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.photo_camera_rounded, size: 18, color: Color(0xFF1E40AF)),
                    SizedBox(width: 8),
                    Text(
                      '2. Foto Asli Kamar Kos Anda:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '100% foto asli kamar Anda akan dipertahankan agar calon anak kos melihat kondisi sebenarnya.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),
                if (roomPhotoUrl != null && roomPhotoUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Image.network(
                          roomPhotoUrl,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 160,
                            color: const Color(0xFFF1F5F9),
                            child: const Center(child: Text('Gagal memuat foto')),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.verified_rounded, color: Color(0xFF34D399), size: 12),
                                SizedBox(width: 4),
                                Text('Foto Kamar Asli Terpasang', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_rounded, size: 28, color: Color(0xFF94A3B8)),
                          SizedBox(height: 4),
                          Text('Belum ada foto asli. Unggah foto kamar asli Anda!', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUploadingPhoto ? null : () => _pickAndUploadRoomPhoto(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded, size: 16),
                        label: const Text('Foto Pakai Kamera'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E40AF),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUploadingPhoto ? null : () => _pickAndUploadRoomPhoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded, size: 16),
                        label: const Text('Pilih dari Galeri'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E40AF),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isUploadingPhoto) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(color: Color(0xFF1E40AF)),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Langkah 3: Pilih Vibe Pencahayaan AI Natural
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 18, color: Color(0xFF1E40AF)),
                    SizedBox(width: 8),
                    Text(
                      '3. Pilih Sentuhan Pencahayaan AI (Realistis):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Menyesuaikan pencahayaan & ketajaman foto kamar asli tanpa melebih-lebihkan atau mengubah bentuk ruangan.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _stylePresets.map((preset) {
                      final isSelected = _selectedStylePreset == preset['id'];
                      final color = preset['color'] as Color;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedStylePreset = preset['id'] as String;
                          _useAiPhoto = true;
                        }),
                        child: Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? color : const Color(0xFFE2E8F0),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(preset['icon'] as IconData, color: color, size: 22),
                                  if (isSelected)
                                    Icon(Icons.check_circle_rounded, color: color, size: 16),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                preset['name'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isSelected ? color : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                preset['desc'] as String,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.2),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Tombol Terapkan Sentuhan AI
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _selectedStylePreset == 'raw_natural'
                        ? () {
                            setState(() => _useAiPhoto = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Foto asli kamar tanpa filter aktif! 100% murni seperti aslinya.'),
                                backgroundColor: Color(0xFF475569),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        : ((_isGeneratingAi || remainingQuota <= 0) ? null : _handleGenerateAiVariation),
                    icon: _isGeneratingAi
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Icon(
                            _selectedStylePreset == 'raw_natural' ? Icons.camera_alt_rounded : Icons.auto_awesome,
                            size: 18,
                          ),
                    label: Text(
                      _selectedStylePreset == 'raw_natural'
                          ? 'Gunakan Foto Asli Mentah (Tanpa Filter)'
                          : (_isGeneratingAi
                              ? 'AI Sedang Menyempurnakan Pencahayaan...'
                              : 'Terapkan Sentuhan Pencahayaan Alami'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedStylePreset == 'raw_natural'
                          ? const Color(0xFF475569)
                          : const Color(0xFF1E40AF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Langkah 4: Format Ukuran Poster
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '4. Format Ukuran Poster:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Persegi 1:1 (Instagram Feed)'),
                      selected: _aspectRatio == '1:1',
                      onSelected: (val) {
                        if (val) setState(() => _aspectRatio = '1:1');
                      },
                      selectedColor: const Color(0xFFDBEAFE),
                      labelStyle: TextStyle(
                        color: _aspectRatio == '1:1' ? const Color(0xFF1E40AF) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Vertikal 9:16 (WhatsApp Story)'),
                      selected: _aspectRatio == '9:16',
                      onSelected: (val) {
                        if (val) setState(() => _aspectRatio = '9:16');
                      },
                      selectedColor: const Color(0xFFDBEAFE),
                      labelStyle: TextStyle(
                        color: _aspectRatio == '9:16' ? const Color(0xFF1E40AF) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Pratinjau Grafis Poster Promosi (Visual Canvas Card dengan RepaintBoundary)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pratinjau Desain Poster Promosi:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
              ),
              InkWell(
                onTap: () => setState(() => _useAiPhoto = !_useAiPhoto),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _useAiPhoto ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _useAiPhoto ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _useAiPhoto ? Icons.auto_awesome : Icons.image_rounded,
                        size: 14,
                        color: _useAiPhoto ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _useAiPhoto ? 'AI Lighting Aktif' : 'Foto Asli Mentah',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _useAiPhoto ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Center(
            child: RepaintBoundary(
              key: _posterKey,
              child: _buildVisualPoster(selectedRoom, _aspectRatio == '1:1'),
            ),
          ),

          const SizedBox(height: 24),

          // Tombol Aksi Ekspor Poster & Copy Teks Promosi
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exportPosterImage,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Simpan / Bagikan Gambar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _copyCaption(caption),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Salin Teks'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Kotak Teks Caption Promosi
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Teks Promosi Otomatis (Caption)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                    ),
                    InkWell(
                      onTap: () => _copyCaption(caption),
                      child: const Row(
                        children: [
                          Icon(Icons.copy_rounded, size: 14, color: Color(0xFF2563EB)),
                          SizedBox(width: 4),
                          Text('Salin', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  caption,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Desain visual poster promosi kos yang elegan dan mempertahankan keaslian foto kamar
  Widget _buildVisualPoster(Map<String, dynamic> room, bool isSquare) {
    final roomNumber = room['nomor_kamar']?.toString() ?? '01';
    final type = room['tipe']?.toString() ?? 'Standard';
    final price = (room['harga_bulanan'] as num?)?.toDouble() ?? 1200000.0;
    final facilities = (room['fasilitas'] as List?)?.map((e) => e.toString()).toList() ??
        ['AC Dingin', 'Kamar Mandi Dalam', 'Kasur Springbed', 'WiFi Super Cepat'];

    final width = isSquare ? 340.0 : 320.0;
    final height = isSquare ? 340.0 : 490.0;
    final hasPhoto = _activePosterPhotoUrl != null && _activePosterPhotoUrl!.isNotEmpty;
    final colorFilter = _getColorFilterForPreset(_selectedStylePreset);

    Widget photoWidget = hasPhoto
        ? Image.network(
            _activePosterPhotoUrl!,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFF0F172A),
              child: const Center(
                child: Icon(Icons.broken_image_rounded, color: Colors.white24, size: 40),
              ),
            ),
          )
        : Container(color: const Color(0xFF0F172A));

    // Jika mode AI aktif dan ada filter warna yang dipilih, terapkan sentuhan pencahayaan ke foto kamar asli
    if (hasPhoto && _useAiPhoto && colorFilter != null) {
      photoWidget = ColorFiltered(
        colorFilter: colorFilter,
        child: photoWidget,
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Gambar Kamar Asli (dengan sentuhan pencahayaan AI natural)
          if (hasPhoto) ...[
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: photoWidget,
              ),
            ),
            // Gradasi atas halus untuk keterbacaan judul kos
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 110,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Gradasi bawah untuk keterbacaan harga dan fasilitas kamar
            // (Bagian tengah foto kamar tetap 100% jernih, terang, dan tampak jelas asli)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: isSquare ? 170 : 220,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.88),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ] else ...[
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                ),
              ),
            ),
          ],

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header Poster
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'DISEWAKAN',
                            style: TextStyle(
                              color: Color(0xFF78350F),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _useAiPhoto && hasPhoto && _selectedStylePreset != 'raw_natural'
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _useAiPhoto && hasPhoto && _selectedStylePreset != 'raw_natural'
                                  ? const Color(0xFFFBBF24)
                                  : Colors.white54,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _useAiPhoto && hasPhoto && _selectedStylePreset != 'raw_natural'
                                    ? Icons.auto_awesome
                                    : Icons.verified_rounded,
                                color: _useAiPhoto && hasPhoto && _selectedStylePreset != 'raw_natural'
                                    ? const Color(0xFFFBBF24)
                                    : const Color(0xFF34D399),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _useAiPhoto && hasPhoto && _selectedStylePreset != 'raw_natural'
                                    ? 'Sentuhan AI Natural'
                                    : '100% Foto Asli',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.kosName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Kamar $roomNumber • Tipe $type',
                      style: const TextStyle(
                        color: Color(0xFF93C5FD),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                // Area Fasilitas
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FASILITAS LENGKAP:',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: facilities.take(isSquare ? 4 : 6).map((f) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 12),
                              const SizedBox(width: 6),
                              Text(
                                f,
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // Footer: Harga & Kontak
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Harga Sewa:',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                          ),
                          Text(
                            FormatUtils.rupiah(price),
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            '/ bulan',
                            style: TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.chat_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Hubungi Pemilik',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _rooms.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final room = _rooms[i];
        final roomNumber = room['nomor_kamar']?.toString() ?? '-';
        final type = room['tipe']?.toString() ?? 'Standard';
        final status = room['status']?.toString() ?? 'kosong';
        final price = (room['harga_bulanan'] as num?)?.toDouble() ?? 0.0;
        final isVacant = status == 'kosong';
        final isLeaving = status == 'akan_kosong';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isVacant
                  ? const Color(0xFFBBF7D0)
                  : (isLeaving ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isVacant
                      ? const Color(0xFFDCFCE7)
                      : (isLeaving ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isVacant
                      ? Icons.door_front_door_rounded
                      : (isLeaving ? Icons.hourglass_bottom_rounded : Icons.person_rounded),
                  color: isVacant
                      ? const Color(0xFF16A34A)
                      : (isLeaving ? const Color(0xFFD97706) : const Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Kamar $roomNumber',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isVacant
                                ? const Color(0xFFDCFCE7)
                                : (isLeaving ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isVacant
                                ? 'Kosong'
                                : (isLeaving ? 'Akan Kosong H-30' : 'Terisi'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isVacant
                                  ? const Color(0xFF15803D)
                                  : (isLeaving ? const Color(0xFFB45309) : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$type • ${FormatUtils.rupiah(price)} / bln',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedRoom = room;
                    final photo = room['foto_url']?.toString();
                    if (photo != null && photo.isNotEmpty) {
                      _activePosterPhotoUrl = photo;
                      _useAiPhoto = true;
                    }
                    _tabController.animateTo(0);
                  });
                },
                icon: const Icon(Icons.campaign_rounded, size: 16),
                label: const Text('Buat Poster'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E40AF),
                  side: const BorderSide(color: Color(0xFF1E40AF)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
