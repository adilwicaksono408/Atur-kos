import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:atur_kos/services/kos_service.dart';
import 'package:atur_kos/utils/format_utils.dart';

/// Halaman Mitigasi Kamar Kosong H-30 & Generator Poster Promosi Pemasaran (PRD Modul 5)
/// Memungkinkan pemilik memantau kamar yang akan habis sewa dan menghasilkan poster grafis siap sebar
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
  late TabController _tabController;
  List<Map<String, dynamic>> _rooms = [];
  Map<String, dynamic>? _selectedRoom;
  Map<String, dynamic>? _kosProfile;
  bool _isLoading = true;
  String _aspectRatio = '1:1'; // '1:1' untuk Feed IG atau '9:16' untuk Story WA/IG

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
    ]);
    if (mounted) {
      setState(() {
        _rooms = results[0] as List<Map<String, dynamic>>;
        _kosProfile = results[1] as Map<String, dynamic>?;
        // Pilih default kamar kosong atau akan kosong pertama jika ada
        if (_rooms.isNotEmpty) {
          _selectedRoom = _rooms.firstWhere(
            (r) => r['status'] == 'kosong' || r['status'] == 'akan_kosong',
            orElse: () => _rooms.first,
          );
        }
        _isLoading = false;
      });
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
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPosterGeneratorTab(),
                _buildRadarTab(),
              ],
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pilihan Kamar & Aspek Rasio
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
                  '1. Pilih Kamar Yang Ingin Dipromosikan:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
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
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),
                const Text(
                  '2. Format Ukuran Poster:',
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

          // Pratinjau Grafis Poster Promosi (Visual Canvas Card)
          const Text(
            'Pratinjau Desain Poster Promosi:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),

          Center(
            child: _buildVisualPoster(selectedRoom, _aspectRatio == '1:1'),
          ),

          const SizedBox(height: 24),

          // Tombol Aksi Poster & Copy Teks Promosi
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _copyCaption(caption),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Salin Teks Promosi WhatsApp & IG'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Poster siap dipublikasikan ke Story WhatsApp & Media Sosial!'),
                      backgroundColor: Color(0xFF1E40AF),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Bagikan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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

  /// Desain visual poster promosi kos yang elegan dan modern
  Widget _buildVisualPoster(Map<String, dynamic> room, bool isSquare) {
    final roomNumber = room['nomor_kamar']?.toString() ?? '01';
    final type = room['tipe']?.toString() ?? 'Standard';
    final price = (room['harga_bulanan'] as num?)?.toDouble() ?? 1200000.0;
    final facilities = (room['fasilitas'] as List?)?.map((e) => e.toString()).toList() ??
        ['AC Dingin', 'Kamar Mandi Dalam', 'Kasur Springbed', 'WiFi Super Cepat'];

    final width = isSquare ? 340.0 : 320.0;
    final height = isSquare ? 340.0 : 480.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Glow Ornaments
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
                            'SIAP HUNI SEKARANG',
                            style: TextStyle(
                              color: Color(0xFF78350F),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Row(
                          children: [
                            Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Kos Eksklusif',
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
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
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
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
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
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
