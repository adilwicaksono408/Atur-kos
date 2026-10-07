import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:atur_kos/models/user_profile.dart';
import 'package:atur_kos/services/auth_service.dart';
import 'package:atur_kos/services/kos_service.dart';
import 'package:atur_kos/utils/format_utils.dart';

/// Halaman Dasbor Utama untuk Peran Penghuni Kos (Tenant)
/// Sesuai PRD: Menangani status teralokasi (Active) & status belum ada kamar (Unallocated)
/// Dilengkapi Helpdesk Keluhan Kerusakan (Modul 4) & Konfirmasi H-30 (Modul 5)
class TenantDashboardScreen extends StatefulWidget {
  final UserProfile profile;

  const TenantDashboardScreen({
    super.key,
    required this.profile,
  });

  @override
  State<TenantDashboardScreen> createState() => _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends State<TenantDashboardScreen> {
  Map<String, dynamic>? _assignmentData;
  Map<String, dynamic>? _linkedKosData;
  List<Map<String, dynamic>> _complaints = [];
  bool _isLoading = true;
  bool _isProofUploaded = false;
  bool _isJoiningKos = false;
  String? _h30Status; // 'lanjut', 'selesai', 'menunggu'
  final _kodeUndanganController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTenantData();
  }

  @override
  void dispose() {
    _kodeUndanganController.dispose();
    super.dispose();
  }

  Future<void> _fetchTenantData() async {
    setState(() => _isLoading = true);
    final assignment = await KosService.getTenantActiveAssignment(widget.profile.id);
    List<Map<String, dynamic>> complaints = [];
    Map<String, dynamic>? linkedKos;

    if (assignment != null) {
      final kostId = assignment['kost_id']?.toString();
      final tenantId = assignment['id']?.toString();
      complaints = await KosService.getComplaints(
        kostId: kostId,
        tenantId: tenantId,
      );
      _h30Status = assignment['h30_response']?.toString();
    } else {
      // Jika belum dialokasikan kamar, cek apakah profil sudah terhubung ke suatu kos
      try {
        final profileData = await Supabase.instance.client
            .from('profiles')
            .select('kost_id')
            .eq('id', widget.profile.id)
            .maybeSingle();
        final currentKostId = profileData?['kost_id']?.toString() ?? widget.profile.kostId;
        if (currentKostId != null && currentKostId.isNotEmpty) {
          linkedKos = await KosService.getKosProfile(currentKostId);
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _assignmentData = assignment;
        _linkedKosData = linkedKos;
        _complaints = complaints;
        _isLoading = false;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) {
      return 'Selamat Pagi';
    } else if (hour >= 11 && hour < 15) {
      return 'Selamat Siang';
    } else if (hour >= 15 && hour < 18) {
      return 'Selamat Sore';
    } else {
      return 'Selamat Malam';
    }
  }

  String _getDisplayName() {
    final name = widget.profile.fullName.trim();
    if (name.isEmpty || name == 'Pengguna') {
      return 'Kak Penghuni';
    }
    if (name.contains('@')) {
      final prefix = name.split('@').first;
      return prefix.isNotEmpty
          ? prefix[0].toUpperCase() + prefix.substring(1)
          : 'Kak Penghuni';
    }
    return name;
  }

  void _handleUploadProof() {
    setState(() {
      _isProofUploaded = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bukti transfer berhasil diunggah! Status: Menunggu Verifikasi Pemilik. Reminder WA otomatis dihentikan.',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Dialog pembuatan tiket keluhan kerusakan fasilitas (PRD Modul 4, US-4.1)
  Future<void> _showCreateComplaintDialog() async {
    if (_assignmentData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda belum memiliki alokasi kamar aktif untuk membuat laporan.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    String scope = 'kamar_pribadi';
    String category = 'Kran Air / Saluran Bocor';
    final descController = TextEditingController();
    final photoController = TextEditingController();

    final categories = [
      'Kran Air / Saluran Bocor',
      'AC Tidak Dingin / Bocor',
      'Lampu / Kelistrikan Mati',
      'WiFi Lemah / Tidak Konek',
      'Kunci Pintu / Jendela Rusak',
      'Fasilitas Bersama Rusak',
      'Lainnya',
    ];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.report_problem_rounded, color: Color(0xFFEF4444)),
              SizedBox(width: 10),
              Expanded(
                child: Text('Lapor Kerusakan Fasilitas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cakupan Masalah:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Kamar Pribadi'),
                        selected: scope == 'kamar_pribadi',
                        onSelected: (val) {
                          if (val) setDialogState(() => scope = 'kamar_pribadi');
                        },
                        selectedColor: const Color(0xFFCCFBF1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Fasilitas Umum'),
                        selected: scope == 'fasilitas_umum',
                        onSelected: (val) {
                          if (val) setDialogState(() => scope = 'fasilitas_umum');
                        },
                        selectedColor: const Color(0xFFEDE9FE),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Kategori Masalah:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
                const SizedBox(height: 14),
                const Text(
                  'Deskripsi Kerusakan:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Air kran kamar mandi menetes terus sejak kemarin pagi.',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Tautan / Catatan Foto Bukti (Opsional):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: photoController,
                  decoration: InputDecoration(
                    hintText: 'Masukkan link Google Drive / foto jika ada',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (descController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Harap isi deskripsi kerusakan.')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
              ),
              child: const Text('Kirim Laporan'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final kostId = _assignmentData!['kost_id'].toString();
      final tenantId = _assignmentData!['id'].toString();
      final photoUrl = photoController.text.trim();

      final success = await KosService.createComplaint(
        kostId: kostId,
        tenantId: tenantId,
        tipeFasilitas: scope,
        judul: category,
        deskripsi: descController.text.trim(),
        fotoUrls: photoUrl.isNotEmpty ? [photoUrl] : [],
      );

      if (mounted) {
        final kost = _assignmentData?['kosts'] as Map<String, dynamic>?;
        final ownerName = kost?['nama_pemilik_rekening']?.toString() ?? 'Pengelola Kos';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Tiket keluhan berhasil dikirim ke $ownerName! Status awal: Diajukan.'
                  : 'Gagal mengirim keluhan. Coba lagi nanti.',
            ),
            backgroundColor: success ? const Color(0xFF059669) : Colors.red,
          ),
        );
        _fetchTenantData();
      }
    }
  }

  /// Dialog riwayat & pelacakan status penanganan keluhan penghuni (PRD US-4.2)
  void _showComplaintsTrackingDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riwayat Keluhan Fasilitas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_complaints.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF10B981)),
                        const SizedBox(height: 12),
                        const Text(
                          'Belum Ada Keluhan Aktif',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Semua fasilitas kamar Anda terpantau aman dan nyaman.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: _complaints.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final c = _complaints[i];
                      final status = c['status']?.toString() ?? 'diajukan';
                      final title = c['judul']?.toString() ?? 'Keluhan';
                      final desc = c['deskripsi']?.toString() ?? '';
                      final notes = c['catatan_penanganan']?.toString();
                      final isGeneral = c['tipe_fasilitas'] == 'fasilitas_umum';

                      Color statusColor = const Color(0xFFDC2626);
                      String statusText = 'Diajukan';
                      if (status == 'sedang_dikerjakan') {
                        statusColor = const Color(0xFF2563EB);
                        statusText = 'Sedang Dikerjakan';
                      } else if (status == 'selesai') {
                        statusColor = const Color(0xFF059669);
                        statusText = 'Selesai';
                      }

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isGeneral ? const Color(0xFFEDE9FE) : const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isGeneral ? 'Fasilitas Umum' : 'Kamar Pribadi',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isGeneral ? const Color(0xFF7C3AED) : const Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                            if (notes != null && notes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.handyman_rounded, size: 14, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Catatan Teknisi: $notes',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dialog konfirmasi komitmen perpanjangan sewa H-30 (PRD Modul 5, US-5.1)
  Future<void> _showH30ConfirmationDialog() async {
    if (_assignmentData == null) return;

    final tenantId = _assignmentData!['id'].toString();
    final roomId = _assignmentData!['room_id'].toString();

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.event_available_rounded, color: Color(0xFF8B5CF6)),
            SizedBox(width: 10),
            Expanded(
              child: Text('Konfirmasi Sewa H-30', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: const Text(
          'Masa sewa Anda mendekati periode akhir. Untuk kenyamanan bersama dan perencanaan operasional kamar, apakah Anda akan melanjutkan sewa di Kos Princess untuk bulan berikutnya?',
          style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF475569)),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'selesai'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFDC2626)),
            ),
            child: const Text('Selesai Sewa (Tidak Lanjut)'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'lanjut'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Lanjut Sewa'),
          ),
        ],
      ),
    );

    if (choice != null) {
      final success = await KosService.updateH30Commitment(
        tenantId: tenantId,
        roomId: roomId,
        response: choice,
      );

      if (mounted) {
        setState(() => _h30Status = choice);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (choice == 'lanjut'
                      ? 'Terima kasih! Komitmen perpanjangan sewa Anda telah tercatat.'
                      : 'Komitmen selesai sewa dicatat. Kamar Anda ditandai akan kosong pada akhir periode sewa.')
                  : 'Gagal memperbarui komitmen sewa.',
            ),
            backgroundColor: choice == 'lanjut' ? const Color(0xFF059669) : const Color(0xFFD97706),
          ),
        );
        _fetchTenantData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRoom = _assignmentData != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_pin_rounded,
                color: Color(0xFF0D9488),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Portal Penghuni',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  'Kos Princess',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0D9488)),
            onPressed: _fetchTenantData,
          ),
          IconButton(
            tooltip: 'Keluar Akun',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
            onPressed: () async {
              await AuthService.signOut();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D9488)))
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _fetchTenantData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner Sapaan Ramah & Personal
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getGreeting()}, ${_getDisplayName()}! 👋',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasRoom
                                  ? 'Selamat beraktivitas di Kos Princess. Seluruh layanan kenyamanan kamar siap diakses.'
                                  : 'Akun Anda aktif. Saat ini menunggu pemilik kos menghubungkan nomor kamar Anda.',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                      // Banner Notifikasi Mitigasi H-30 jika sudah aktif
                      if (hasRoom && _h30Status == null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.event_available_rounded, color: Color(0xFFD97706), size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Pengingat Komitmen H-30',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Masa sewa mendekati 30 hari. Mohon konfirmasi rencana Anda.',
                                      style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _showH30ConfirmationDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD97706),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                child: const Text('Isi Sekarang', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),

                      // Jika Penghuni belum dialokasikan kamar
                      if (!hasRoom)
                        _buildUnallocatedState(_getDisplayName())
                      else
                        _buildAllocatedState(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _handleJoinKos() async {
    final code = _kodeUndanganController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masukkan kode undangan kos terlebih dahulu.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isJoiningKos = true);
    final kos = await KosService.joinKosByInvitationCode(
      userId: widget.profile.id,
      invitationCode: code,
      userName: widget.profile.fullName,
    );
    setState(() => _isJoiningKos = false);

    if (!mounted) return;

    if (kos != null) {
      final kosName = kos['nama_kost']?.toString() ?? 'Kos';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Berhasil terhubung ke $kosName! Pemilik kos sekarang dapat mengalokasikan kamar untuk Anda.'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _kodeUndanganController.clear();
      _fetchTenantData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Kode undangan "$code" tidak ditemukan. Periksa kembali kode dari pemilik kos Anda.'),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Tampilan saat penghuni baru mendaftar dan belum dialokasikan kamar oleh Pemilik
  Widget _buildUnallocatedState(String userName) {
    final hasLinkedKos = _linkedKosData != null;
    final kosName = _linkedKosData?['nama_kost']?.toString() ?? 'Kos';
    final ownerName = _linkedKosData?['nama_pemilik_rekening']?.toString() ?? 'Pemilik / Pengelola Kos';
    final contactNumber = _linkedKosData?['nomor_kontak']?.toString() ?? '628123456789';
    final kodeKost = _linkedKosData?['kode_kost']?.toString() ?? '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: hasLinkedKos ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasLinkedKos ? Icons.hourglass_top_rounded : Icons.link_rounded,
              color: hasLinkedKos ? const Color(0xFFD97706) : const Color(0xFF2563EB),
              size: 38,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Halo, $userName!',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: hasLinkedKos ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasLinkedKos ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE),
              ),
            ),
            child: Text(
              hasLinkedKos
                  ? 'Menunggu Alokasi Kamar oleh Pemilik'
                  : 'Belum Terhubung ke Properti Kos',
              style: TextStyle(
                color: hasLinkedKos ? const Color(0xFFB45309) : const Color(0xFF1D4ED8),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasLinkedKos
                ? 'Akun Anda telah terhubung ke $kosName (Kode: $kodeKost). Saat ini $ownerName belum mengalokasikan nomor kamar Anda ke sistem.'
                : 'Akun Anda aktif sebagai Penghuni. Masukkan kode undangan dari pemilik kos Anda di bawah ini agar akun Anda terdaftar di daftar alokasi kamar pemilik kos.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Kartu Form Masukkan Kode Undangan Kos
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.vpn_key_rounded,
                        color: Color(0xFF0D9488),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasLinkedKos ? 'Ganti / Masukkan Kode Undangan Kos' : 'Masukkan Kode Undangan Kos',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Dapatkan kode ini dari pemilik kos Anda (Contoh: PRINCESS)',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _kodeUndanganController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: hasLinkedKos ? kodeKost : 'Contoh: PRINCESS',
                    prefixIcon: const Icon(Icons.key_rounded, size: 20, color: Color(0xFF0D9488)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _isJoiningKos ? null : _handleJoinKos,
                    icon: _isJoiningKos
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      _isJoiningKos
                          ? 'Menghubungkan...'
                          : (hasLinkedKos ? 'Perbarui Hubungan Kos' : 'Hubungkan ke Kos'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Tombol Cek Status & WhatsApp
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  _fetchTenantData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Memeriksa status alokasi kamar terbaru...'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF0D9488)),
                label: const Text('Cek Status Kamar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D9488),
                  side: const BorderSide(color: Color(0xFF0D9488)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Nomor kontak WhatsApp Pengelola: $contactNumber ($ownerName)'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.chat_rounded, size: 18, color: Color(0xFF059669)),
                label: const Text('Kontak WhatsApp Pengelola'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF059669),
                  side: const BorderSide(color: Color(0xFF059669)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tampilan saat penghuni sudah memiliki kamar aktif di Kos Princess
  Widget _buildAllocatedState() {
    final room = _assignmentData?['rooms'] as Map<String, dynamic>?;
    final kost = _assignmentData?['kosts'] as Map<String, dynamic>?;
    final roomNumber = room?['nomor_kamar']?.toString() ?? '01';
    final roomType = room?['tipe']?.toString() ?? 'Standard';
    final price = (room?['harga_bulanan'] as num?)?.toDouble() ?? 1200000.0;
    final dueDay = _assignmentData?['tanggal_jatuh_tempo_bulanan']?.toString() ?? '1';
    final bankAccount = kost?['rekening_bank']?.toString() ?? 'BCA 1234567890';
    final bankOwner = kost?['nama_pemilik_rekening']?.toString() ?? 'Pengelola Kos';
    final bankInfo = '$bankAccount a.n $bankOwner';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kartu Identitas Kamar Penghuni
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Kamar Aktif Anda',
                      style: TextStyle(
                        color: Color(0xFF0F766E),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Sewa Berjalan',
                      style: TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Kamar $roomNumber',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tipe: $roomType • ${FormatUtils.rupiah(price)} / bulan',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_repeat_rounded, color: Color(0xFF475569), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Jatuh Tempo: Setiap tanggal $dueDay per bulan',
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Kartu Tagihan Bulan Berjalan (Smart Billing PRD)
        const Text(
          'Tagihan Sewa Bulan Ini',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isProofUploaded ? const Color(0xFF0D9488) : const Color(0xFFF59E0B),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Periode Berjalan',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        FormatUtils.rupiah(price),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isProofUploaded ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _isProofUploaded ? 'Menunggu Verifikasi' : 'Belum Bayar',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isProofUploaded ? const Color(0xFFB45309) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.account_balance_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rekening Tujuan: $bankInfo',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isProofUploaded)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bukti transfer telah diterima. Pemilik kos akan memvalidasi pembayaran Anda.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _handleUploadProof,
                    icon: const Icon(Icons.cloud_upload_rounded),
                    label: const Text('Unggah Bukti Transfer Bank'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 26),

        // Fitur Cepat Layanan & Helpdesk Penghuni
        const Text(
          'Layanan & Bantuan Fasilitas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildServiceTile(
                icon: Icons.report_problem_rounded,
                color: const Color(0xFFEF4444),
                title: 'Lapor Kerusakan',
                subtitle: 'Kamar / Fasilitas Umum',
                onTap: _showCreateComplaintDialog,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildServiceTile(
                icon: Icons.track_changes_rounded,
                color: const Color(0xFF2563EB),
                title: 'Status Keluhan',
                subtitle: '${_complaints.length} riwayat tiket',
                onTap: _showComplaintsTrackingDialog,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildServiceTile(
                icon: Icons.event_available_rounded,
                color: const Color(0xFF8B5CF6),
                title: 'Konfirmasi Sewa',
                subtitle: _h30Status == null ? 'Isi komitmen H-30' : 'Status: $_h30Status',
                onTap: _showH30ConfirmationDialog,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildServiceTile(
                icon: Icons.chat_rounded,
                color: const Color(0xFF059669),
                title: 'Kontak Pemilik',
                subtitle: 'WhatsApp Pengelola',
                onTap: () {
                  final kost = _assignmentData?['kosts'] as Map<String, dynamic>?;
                  final contact = kost?['nomor_kontak']?.toString() ?? '628123456789';
                  final owner = kost?['nama_pemilik_rekening']?.toString() ?? 'Pengelola Kos';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Membuka kontak WhatsApp $owner: $contact'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
