import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:atur_kos/models/announcement_model.dart';
import 'package:atur_kos/services/kos_service.dart';

/// Halaman Manajemen Papan Pengumuman Digital & Notifikasi Paket Kurir (PRD Modul 9)
/// Fitur Eksklusif Pemilik Kos Paket Juragan ⭐
class AnnouncementManagementScreen extends StatefulWidget {
  final String? kostId;
  final String kosName;

  const AnnouncementManagementScreen({
    super.key,
    required this.kostId,
    required this.kosName,
  });

  @override
  State<AnnouncementManagementScreen> createState() =>
      _AnnouncementManagementScreenState();
}

class _AnnouncementManagementScreenState
    extends State<AnnouncementManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  List<AnnouncementModel> _announcements = [];
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchAnnouncements(),
      _fetchRooms(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAnnouncements() async {
    if (widget.kostId == null || widget.kostId!.isEmpty) return;
    final list = await KosService.getAnnouncements(kostId: widget.kostId!);
    if (mounted) {
      setState(() {
        _announcements = list;
      });
    }
  }

  Future<void> _fetchRooms() async {
    if (widget.kostId == null || widget.kostId!.isEmpty) return;
    final roomsData = await KosService.getRooms(widget.kostId);
    if (mounted) {
      setState(() {
        _rooms = roomsData;
      });
    }
  }

  List<AnnouncementModel> _getFilteredList(int tabIndex) {
    List<AnnouncementModel> list;
    switch (tabIndex) {
      case 0: // Paket Aktif
        list = _announcements.where((a) => a.isPaket && !a.isResolved).toList();
        break;
      case 1: // Semua Pengumuman Aktif
        list = _announcements.where((a) => !a.isResolved).toList();
        break;
      case 2: // Info Operasional & Barang Hilang
        list = _announcements
            .where((a) => !a.isResolved && (a.isInfoOperasional || a.isBarangHilang || a.isPinned))
            .toList();
        break;
      case 3: // Riwayat Arsip / Selesai
        list = _announcements.where((a) => a.isResolved).toList();
        break;
      default:
        list = _announcements;
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) {
        final title = a.judul.toLowerCase();
        final desc = a.deskripsi.toLowerCase();
        final room = (a.targetRoomNumber ?? '').toLowerCase();
        return title.contains(q) || desc.contains(q) || room.contains(q);
      }).toList();
    }

    return list;
  }

  // ===========================================================================
  // AKSI INTERAKTIF PENGUMUMAN
  // ===========================================================================

  /// Menandai paket sudah diambil oleh penghuni / diserahkan
  Future<void> _markAsResolved(AnnouncementModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 26),
            SizedBox(width: 10),
            Text('Tandai Sudah Diambil?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Paket untuk ${item.targetRoomNumber != null ? "Kamar ${item.targetRoomNumber}" : "penghuni"} akan dipindahkan dari beranda aktif ke tab Riwayat Arsip.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Ya, Sudah Diambil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await KosService.updateAnnouncementResolvedStatus(
        announcementId: item.id,
        isResolved: true,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Status diperbarui: Paket ditandai sudah diambil.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        _fetchAnnouncements();
      }
    }
  }

  /// Mengubah status sematan (Pin/Unpin)
  Future<void> _togglePin(AnnouncementModel item) async {
    final newPinnedStatus = !item.isPinned;
    final success = await KosService.togglePinAnnouncement(
      announcementId: item.id,
      isPinned: newPinnedStatus,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newPinnedStatus
              ? '📌 Pengumuman disematkan di bagian teratas.'
              : 'Pin pengumuman telah dilepas.'),
          duration: const Duration(seconds: 2),
        ),
      );
      _fetchAnnouncements();
    }
  }

  /// Menghapus pengumuman
  Future<void> _deleteAnnouncement(AnnouncementModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 26),
            SizedBox(width: 10),
            Text('Hapus Pengumuman?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Pengumuman "${item.judul}" akan dihapus permanen dari papan pengumuman kos.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await KosService.deleteAnnouncement(item.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengumuman berhasil dihapus.')),
        );
        _fetchAnnouncements();
      }
    }
  }

  // ===========================================================================
  // MODAL FORM: CATAT PAKET KURIR TIBA (EXPRESS ACTION 5 DETIK)
  // ===========================================================================
  Future<void> _showExpressPackageDialog() async {
    String? selectedRoomId;
    String selectedCourier = 'Shopee Xpress';
    String selectedLocation = 'Di Rak Lobi';
    final notesController = TextEditingController();
    Uint8List? photoBytes;
    String? photoExt;
    bool isSubmitting = false;

    final couriers = [
      'Shopee Xpress',
      'J&T Express',
      'SiCepat',
      'JNE',
      'GoSend / Grab',
      'Anteraja',
      'Lainnya',
    ];

    final locations = [
      'Di Rak Lobi',
      'Di Meja Resepsionis',
      'Di Teras Depan',
      'Di Kotak Paket Kamar',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: Color(0xFF2563EB),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Catat Paket Kurir Tiba',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Kirim notifikasi langsung ke kamar penghuni penerima',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 1. Unggah Foto Paket (Kamera / Galeri)
                  const Text(
                    'Foto Paket Kurir (Opsional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 8),
                  if (photoBytes != null) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            photoBytes!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: InkWell(
                            onTap: () => setModalState(() {
                              photoBytes = null;
                              photoExt = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await _picker.pickImage(
                                source: ImageSource.camera,
                                maxWidth: 1280,
                                maxHeight: 1280,
                                imageQuality: 80,
                              );
                              if (picked != null) {
                                final bytes = await picked.readAsBytes();
                                setModalState(() {
                                  photoBytes = bytes;
                                  photoExt = picked.name.split('.').last.toLowerCase();
                                });
                              }
                            },
                            icon: const Icon(Icons.camera_alt_rounded, size: 18),
                            label: const Text('Buka Kamera'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await _picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1280,
                                maxHeight: 1280,
                                imageQuality: 80,
                              );
                              if (picked != null) {
                                final bytes = await picked.readAsBytes();
                                setModalState(() {
                                  photoBytes = bytes;
                                  photoExt = picked.name.split('.').last.toLowerCase();
                                });
                              }
                            },
                            icon: const Icon(Icons.photo_library_rounded, size: 18),
                            label: const Text('Pilih Galeri'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 2. Pilih Nomor Kamar Tujuan
                  const Text(
                    'Nomor Kamar Penerima *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedRoomId,
                        hint: const Text('Pilih Nomor Kamar Penghuni...'),
                        items: _rooms.map((r) {
                          final rId = r['id']?.toString() ?? '';
                          final rNum = r['nomor_kamar']?.toString() ?? '-';
                          final rType = r['tipe']?.toString() ?? '';
                          return DropdownMenuItem<String>(
                            value: rId,
                            child: Text('Kamar $rNum ($rType)'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setModalState(() => selectedRoomId = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Ekspedisi / Kurir
                  const Text(
                    'Ekspedisi / Kurir',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: couriers.map((c) {
                      final isSelected = selectedCourier == c;
                      return ChoiceChip(
                        label: Text(c, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : const Color(0xFF334155))),
                        selected: isSelected,
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedCourier = c);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 4. Lokasi Penempatan
                  const Text(
                    'Lokasi Penempatan Paket',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: locations.map((loc) {
                      final isSelected = selectedLocation == loc;
                      return ChoiceChip(
                        label: Text(loc, style: TextStyle(fontSize: 12, color: isSelected ? const Color(0xFF1E40AF) : const Color(0xFF475569))),
                        selected: isSelected,
                        selectedColor: const Color(0xFFDBEAFE),
                        backgroundColor: const Color(0xFFF8FAFC),
                        side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedLocation = loc);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 5. Catatan Tambahan (Opsional)
                  const Text(
                    'Catatan / Ciri Paket (Opsional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Kardus cokelat ukuran sedang berlabel nama Budi.',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tombol Publikasikan
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(ctx);

                              if (selectedRoomId == null || selectedRoomId!.isEmpty) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Silakan pilih nomor kamar penerima terlebih dahulu!'),
                                    backgroundColor: Color(0xFFDC2626),
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);

                              // 1. Upload foto jika ada
                              List<String> uploadedUrls = [];
                              if (photoBytes != null) {
                                final photoUrl = await KosService.uploadAnnouncementPhoto(
                                  bytes: photoBytes!,
                                  extension: photoExt ?? 'jpg',
                                  kostId: widget.kostId,
                                );
                                if (photoUrl != null && photoUrl.isNotEmpty) {
                                  uploadedUrls.add(photoUrl);
                                }
                              }

                              // 2. Ambil label kamar
                              final roomObj = _rooms.firstWhere(
                                (r) => r['id']?.toString() == selectedRoomId,
                                orElse: () => {'nomor_kamar': '-'},
                              );
                              final roomNum = roomObj['nomor_kamar']?.toString() ?? '-';

                              final judul = 'Paket $selectedCourier Tiba ($selectedLocation)';
                              final catatan = notesController.text.trim();
                              final deskripsi = catatan.isNotEmpty
                                  ? 'Paket $selectedCourier untuk Kamar $roomNum telah tiba dan ditaruh $selectedLocation.\nCatatan: $catatan'
                                  : 'Paket $selectedCourier untuk Kamar $roomNum telah tiba di area kos dan ditaruh $selectedLocation. Mohon segera diambil.';

                              final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

                              final result = await KosService.createAnnouncement(
                                kostId: widget.kostId!,
                                authorId: currentUserId,
                                targetRoomId: selectedRoomId,
                                kategori: 'paket',
                                judul: judul,
                                deskripsi: deskripsi,
                                fotoUrls: uploadedUrls,
                                isPinned: false,
                              );

                              if (result != null) {
                                navigator.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('✓ Paket untuk Kamar $roomNum berhasil diterbitkan!'),
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                );
                                _fetchAnnouncements();
                              } else {
                                setModalState(() => isSubmitting = false);
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Gagal mencatat paket. Cek koneksi Supabase Anda.'),
                                    backgroundColor: Color(0xFFDC2626),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              '📦 Terbitkan & Beri Tahu Penghuni',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // MODAL FORM: BUAT PENGUMUMAN UMUM / OPERASIONAL / BARANG HILANG
  // ===========================================================================
  Future<void> _showGeneralAnnouncementDialog() async {
    String selectedCategory = 'info_operasional';
    bool isBroadcast = true;
    String? selectedRoomId;
    bool isPinned = false;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    Uint8List? photoBytes;
    String? photoExt;
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.campaign_rounded,
                          color: Color(0xFFDC2626),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buat Pengumuman Kos',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Siarkan informasi penting ke papan pengumuman digital',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 1. Pilih Kategori
                  const Text(
                    'Kategori Pengumuman *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('⚠️ Info Operasional (Air/Listrik)'),
                        selected: selectedCategory == 'info_operasional',
                        selectedColor: const Color(0xFFFEE2E2),
                        labelStyle: TextStyle(
                          color: selectedCategory == 'info_operasional' ? const Color(0xFFDC2626) : const Color(0xFF334155),
                          fontWeight: selectedCategory == 'info_operasional' ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedCategory = 'info_operasional');
                        },
                      ),
                      ChoiceChip(
                        label: const Text('🔍 Barang Tercecer / Hilang'),
                        selected: selectedCategory == 'barang_hilang',
                        selectedColor: const Color(0xFFFFEDD5),
                        labelStyle: TextStyle(
                          color: selectedCategory == 'barang_hilang' ? const Color(0xFFEA580C) : const Color(0xFF334155),
                          fontWeight: selectedCategory == 'barang_hilang' ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedCategory = 'barang_hilang');
                        },
                      ),
                      ChoiceChip(
                        label: const Text('📢 Pengumuman Umum'),
                        selected: selectedCategory == 'umum',
                        selectedColor: const Color(0xFFD1FAE5),
                        labelStyle: TextStyle(
                          color: selectedCategory == 'umum' ? const Color(0xFF059669) : const Color(0xFF334155),
                          fontWeight: selectedCategory == 'umum' ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedCategory = 'umum');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Target Audiens
                  const Text(
                    'Target Penerima Pengumuman *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('📢 Seluruh Penghuni (Broadcast)')),
                          selected: isBroadcast,
                          selectedColor: const Color(0xFFEFF6FF),
                          labelStyle: TextStyle(
                            color: isBroadcast ? const Color(0xFF2563EB) : const Color(0xFF475569),
                            fontWeight: isBroadcast ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => isBroadcast = true);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('🚪 Kamar Spesifik')),
                          selected: !isBroadcast,
                          selectedColor: const Color(0xFFEFF6FF),
                          labelStyle: TextStyle(
                            color: !isBroadcast ? const Color(0xFF2563EB) : const Color(0xFF475569),
                            fontWeight: !isBroadcast ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => isBroadcast = false);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (!isBroadcast) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedRoomId,
                          hint: const Text('Pilih Nomor Kamar Spesifik...'),
                          items: _rooms.map((r) {
                            final rId = r['id']?.toString() ?? '';
                            final rNum = r['nomor_kamar']?.toString() ?? '-';
                            return DropdownMenuItem<String>(
                              value: rId,
                              child: Text('Kamar $rNum'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setModalState(() => selectedRoomId = val);
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // 3. Judul Pengumuman
                  const Text(
                    'Judul Pengumuman *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Kuras Toren Air Bersih / Ditemukan Kunci Motor',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Deskripsi
                  const Text(
                    'Isi Lengkap Pengumuman *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Tuliskan detail jadwal, lokasi, atau instruksi bagi penghuni...',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Opsi Sematkan (Pin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.push_pin_rounded, color: Color(0xFFD97706), size: 20),
                            SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sematkan di Paling Atas (Pin)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                Text('Tetap muncul di posisi teratas beranda', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: isPinned,
                          activeThumbColor: const Color(0xFFD97706),
                          activeTrackColor: const Color(0xFFFDE68A),
                          onChanged: (val) => setModalState(() => isPinned = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 6. Foto Lampiran (Opsional)
                  const Text(
                    'Foto Pendukung / Lampiran (Opsional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  if (photoBytes != null) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(photoBytes!, height: 140, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: InkWell(
                            onTap: () => setModalState(() {
                              photoBytes = null;
                              photoExt = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await _picker.pickImage(
                                source: ImageSource.camera,
                                maxWidth: 1280,
                                maxHeight: 1280,
                                imageQuality: 80,
                              );
                              if (picked != null) {
                                final bytes = await picked.readAsBytes();
                                setModalState(() {
                                  photoBytes = bytes;
                                  photoExt = picked.name.split('.').last.toLowerCase();
                                });
                              }
                            },
                            icon: const Icon(Icons.camera_alt_rounded, size: 18),
                            label: const Text('Buka Kamera'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFFECACA)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await _picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1280,
                                maxHeight: 1280,
                                imageQuality: 80,
                              );
                              if (picked != null) {
                                final bytes = await picked.readAsBytes();
                                setModalState(() {
                                  photoBytes = bytes;
                                  photoExt = picked.name.split('.').last.toLowerCase();
                                });
                              }
                            },
                            icon: const Icon(Icons.photo_library_rounded, size: 18),
                            label: const Text('Pilih Galeri'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Tombol Publikasikan
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(ctx);
                              final title = titleController.text.trim();
                              final desc = descController.text.trim();

                              if (title.isEmpty || desc.isEmpty) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Judul dan isi pengumuman wajib diisi!'),
                                    backgroundColor: Color(0xFFDC2626),
                                  ),
                                );
                                return;
                              }

                              if (!isBroadcast && (selectedRoomId == null || selectedRoomId!.isEmpty)) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Silakan tentukan nomor kamar target!'),
                                    backgroundColor: Color(0xFFDC2626),
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);

                              List<String> uploadedUrls = [];
                              if (photoBytes != null) {
                                final photoUrl = await KosService.uploadAnnouncementPhoto(
                                  bytes: photoBytes!,
                                  extension: photoExt ?? 'jpg',
                                  kostId: widget.kostId,
                                );
                                if (photoUrl != null && photoUrl.isNotEmpty) {
                                  uploadedUrls.add(photoUrl);
                                }
                              }

                              final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

                              final result = await KosService.createAnnouncement(
                                kostId: widget.kostId!,
                                authorId: currentUserId,
                                targetRoomId: isBroadcast ? null : selectedRoomId,
                                kategori: selectedCategory,
                                judul: title,
                                deskripsi: desc,
                                fotoUrls: uploadedUrls,
                                isPinned: isPinned,
                              );

                              if (result != null) {
                                navigator.pop();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('✓ Pengumuman berhasil diterbitkan!'),
                                    backgroundColor: Color(0xFF059669),
                                  ),
                                );
                                _fetchAnnouncements();
                              } else {
                                setModalState(() => isSubmitting = false);
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Gagal menerbitkan pengumuman. Coba lagi.'),
                                    backgroundColor: Color(0xFFDC2626),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              '📢 Publikasikan Sekarang',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // PHOTO VIEWER MODAL
  // ===========================================================================
  void _openPhotoViewer(String url, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.white,
                    child: const Text('Gagal memuat foto.'),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // BUILD UI
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final activePackages = _announcements.where((a) => a.isPaket && !a.isResolved).length;
    final totalActive = _announcements.where((a) => !a.isResolved).length;
    final totalHistory = _announcements.where((a) => a.isResolved).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Papan Pengumuman & Paket',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
            ),
            Text(
              '${widget.kosName} • Paket Juragan ⭐',
              style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            tooltip: 'Segarkan Data',
            onPressed: _loadInitialData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(text: 'Paket Tiba ($activePackages)'),
                Tab(text: 'Semua Aktif ($totalActive)'),
                Tab(text: 'Operasional & Info'),
                Tab(text: 'Riwayat Arsip ($totalHistory)'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. Hero Action Banner: Express Action 5 Detik
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      // Tombol Express Paket
                      Expanded(
                        flex: 6,
                        child: ElevatedButton.icon(
                          onPressed: _showExpressPackageDialog,
                          icon: const Icon(Icons.inventory_2_rounded, size: 18),
                          label: const Text(
                            'Catat Paket Kurir',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Tombol Pengumuman Umum
                      Expanded(
                        flex: 5,
                        child: OutlinedButton.icon(
                          onPressed: _showGeneralAnnouncementDialog,
                          icon: const Icon(Icons.campaign_rounded, size: 18),
                          label: const Text(
                            'Buat Info',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Bar Pencarian
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.white,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Cari judul, paket, atau nomor kamar...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // 3. Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAnnouncementListView(0),
                      _buildAnnouncementListView(1),
                      _buildAnnouncementListView(2),
                      _buildAnnouncementListView(3),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAnnouncementListView(int tabIndex) {
    final list = _getFilteredList(tabIndex);

    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchAnnouncements,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.5,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    tabIndex == 0 ? Icons.inventory_2_outlined : Icons.campaign_outlined,
                    size: 48,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tabIndex == 0
                      ? 'Tidak Ada Paket yang Menunggu'
                      : (tabIndex == 3 ? 'Belum Ada Riwayat Arsip' : 'Belum Ada Pengumuman Aktif'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                Text(
                  tabIndex == 0
                      ? 'Semua paket kurir telah diambil oleh penghuni kamar masing-masing.'
                      : 'Gunakan tombol di atas untuk mencatat paket kurir atau menerbitkan pengumuman.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAnnouncements,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final item = list[index];
          return _buildAnnouncementCard(item);
        },
      ),
    );
  }

  Widget _buildAnnouncementCard(AnnouncementModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.isPinned
              ? const Color(0xFFFDE68A)
              : (item.isResolved ? const Color(0xFFE2E8F0) : const Color(0xFFE2E8F0)),
          width: item.isPinned ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Atas: Kategori, Target Kamar, Pin, & Waktu
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 8),
            child: Row(
              children: [
                // Chip Kategori
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.kategoriBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(item.kategoriIcon, size: 14, color: item.kategoriColor),
                      const SizedBox(width: 6),
                      Text(
                        item.kategoriLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: item.kategoriColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Chip Target: Kamar atau Broadcast
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.isBroadcast ? const Color(0xFFF1F5F9) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.isBroadcast ? Icons.public_rounded : Icons.door_front_door_rounded,
                        size: 13,
                        color: item.isBroadcast ? const Color(0xFF475569) : const Color(0xFFB45309),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.isBroadcast ? 'Semua Kamar' : 'Kamar ${item.targetRoomNumber ?? "-"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: item.isBroadcast ? const Color(0xFF475569) : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Pin Indikator
                if (item.isPinned) ...[
                  const Icon(Icons.push_pin_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                ],

                // Waktu Relatif
                Text(
                  item.timeAgo,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),

          // Judul & Deskripsi
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.judul,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: item.isResolved ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                    decoration: item.isResolved ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.deskripsi,
                  style: TextStyle(
                    fontSize: 13,
                    color: item.isResolved ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Foto Lampiran / Paket jika ada
          if (item.hasPhoto) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                onTap: () => _openPhotoViewer(item.primaryPhotoUrl!, item.judul),
                borderRadius: BorderRadius.circular(14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Image.network(
                        item.primaryPhotoUrl!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 100,
                          color: const Color(0xFFF1F5F9),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8)),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('Perbesar Foto', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Footer Aksi: Selesai / Pin / Hapus
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Tombol "Tandai Sudah Diambil" jika paket masih aktif
                if (item.isPaket && !item.isResolved)
                  ElevatedButton.icon(
                    onPressed: () => _markAsResolved(item),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text('Tandai Sudah Diambil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  )
                else if (item.isResolved)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.done_all_rounded, color: Color(0xFF059669), size: 14),
                        SizedBox(width: 6),
                        Text('Selesai / Sudah Diambil', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                      ],
                    ),
                  ),

                const Spacer(),

                // Tombol Pin
                IconButton(
                  icon: Icon(
                    item.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    color: item.isPinned ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  tooltip: item.isPinned ? 'Lepas Sematan' : 'Sematkan di Atas',
                  onPressed: () => _togglePin(item),
                ),

                // Tombol Hapus
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                  tooltip: 'Hapus Pengumuman',
                  onPressed: () => _deleteAnnouncement(item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
