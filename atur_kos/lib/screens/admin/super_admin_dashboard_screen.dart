import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:atur_kos/models/kost_model.dart';
import 'package:atur_kos/models/user_profile.dart';
import 'package:atur_kos/services/auth_service.dart';
import 'package:atur_kos/services/kos_service.dart';

/// Dasbor Portal Super Admin Platform Atur Kos (PRD v2.0.0 Modul 1 & 2)
/// Digunakan oleh tim pengembang/pengelola platform untuk:
/// 1. Memvalidasi keabsahan properti kos baru (KTP, Foto Fisik Bangunan, Peta)
/// 2. Menyetujui (Approve), Menolak (Reject), atau Membekukan (Suspend) properti
/// 3. Memantau kuota dan status paket (Starter vs Juragan)
class SuperAdminDashboardScreen extends StatefulWidget {
  final UserProfile profile;

  const SuperAdminDashboardScreen({
    super.key,
    required this.profile,
  });

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<KostModel> _allKosts = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await KosService.getAllKostsForAdmin();
    if (mounted) {
      setState(() {
        _allKosts = data;
        _isLoading = false;
      });
    }
  }

  List<KostModel> _getFilteredKosts() {
    List<KostModel> list;
    switch (_tabController.index) {
      case 1:
        list = _allKosts.where((k) => k.isPending).toList();
        break;
      case 2:
        list = _allKosts.where((k) => k.isActive).toList();
        break;
      case 3:
        list = _allKosts.where((k) => k.isRejected || k.isSuspended).toList();
        break;
      case 0:
      default:
        list = _allKosts;
        break;
    }

    if (_searchQuery.trim().isEmpty) return list;

    final q = _searchQuery.toLowerCase().trim();
    return list.where((k) {
      return k.namaKost.toLowerCase().contains(q) ||
          k.alamat.toLowerCase().contains(q) ||
          k.nomorKontak.toLowerCase().contains(q) ||
          (k.kodeKost?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _showApprovalDialog(KostModel kos) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified, color: Color(0xFF16A34A), size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Setujui Properti Kos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin data fisik dan identitas pemilik "${kos.namaKost}" sudah valid? Status properti akan diubah menjadi Aktif.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Ya, Setujui'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await KosService.verifyKostByAdmin(
        kostId: kos.id,
        status: KostStatus.active,
        catatanAdmin: 'Disetujui oleh Super Admin (${widget.profile.fullName})',
      );
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Properti "${kos.namaKost}" berhasil disetujui & aktif!'),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal memperbarui status kos. Periksa koneksi.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showRejectionDialog(KostModel kos) async {
    final noteController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_outlined, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Tolak Pengajuan Kos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Berikan alasan penolakan untuk "${kos.namaKost}". Pemilik akan melihat alasan ini untuk melakukan perbaikan data.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Misal: Foto KTP buram, titik maps tidak sesuai foto tampak depan...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Tolak Pengajuan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await KosService.verifyKostByAdmin(
        kostId: kos.id,
        status: KostStatus.rejected,
        catatanAdmin: noteController.text.trim().isNotEmpty
            ? noteController.text.trim()
            : 'Data pengajuan belum memenuhi syarat verifikasi.',
      );
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pengajuan "${kos.namaKost}" telah ditolak.'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal menolak pengajuan kos. Coba lagi nanti.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showSuspendDialog(KostModel kos) async {
    final newStatus = kos.isSuspended ? KostStatus.active : KostStatus.suspended;
    final actionName = kos.isSuspended ? 'Aktifkan Kembali' : 'Bekukan Akun Kos';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(actionName, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          kos.isSuspended
              ? 'Properti "${kos.namaKost}" akan diaktifkan kembali dan dapat beroperasi normal.'
              : 'Akun "${kos.namaKost}" akan dibekukan sementara karena terindikasi kendala operasional.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kos.isSuspended ? const Color(0xFF16A34A) : Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
            child: Text(actionName),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await KosService.verifyKostByAdmin(
        kostId: kos.id,
        status: newStatus,
        catatanAdmin: kos.isSuspended ? 'Diaktifkan kembali oleh admin' : 'Dibekukan oleh admin',
      );
      if (mounted && success) {
        _loadData();
      }
    }
  }

  void _showDocumentViewer({required String title, required String? url}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              if (url == null || url.trim().isEmpty)
                Container(
                  height: 200,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Dokumen belum diunggah oleh pemilik.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: url.startsWith('data:image')
                      ? Image.memory(
                          base64Decode(url.split(',').last),
                          height: 320,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        )
                      : Image.network(
                          url,
                          height: 320,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 200,
                            color: Colors.grey.shade100,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                const SizedBox(height: 6),
                                Text('Tautan dokumen: $url',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11, color: Colors.blue)),
                              ],
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _allKosts.where((k) => k.isPending).length;
    final activeCount = _allKosts.where((k) => k.isActive).length;
    final otherCount = _allKosts.where((k) => k.isRejected || k.isSuspended).length;
    final filteredKosts = _getFilteredKosts();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Atur Kos — Super Admin',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Portal Verifikasi Properti & Tata Kelola Platform (PRD v2)',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Segarkan Data',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Keluar Akun'),
                  content: const Text('Yakin ingin keluar dari Portal Super Admin?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Keluar'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await AuthService.signOut();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2563EB)),
                  SizedBox(height: 12),
                  Text('Memuat data properti kos...', style: TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Selamat Datang
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFEFF6FF),
                            child: Text(
                              widget.profile.fullName.isNotEmpty
                                  ? widget.profile.fullName[0].toUpperCase()
                                  : 'A',
                              style: const TextStyle(
                                  color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Halo, ${widget.profile.fullName}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Peran: ${widget.profile.role.label} • Email: ${widget.profile.email ?? "-"}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ringkasan Statistik Properti
                    Row(
                      children: [
                        _buildStatCard(
                          title: 'Total Terdaftar',
                          value: '${_allKosts.length}',
                          color: const Color(0xFF2563EB),
                          icon: Icons.home_work_outlined,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          title: 'Menunggu Verifikasi',
                          value: '$pendingCount',
                          color: const Color(0xFFD97706),
                          icon: Icons.hourglass_top_outlined,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          title: 'Kos Aktif',
                          value: '$activeCount',
                          color: const Color(0xFF16A34A),
                          icon: Icons.check_circle_outline,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          title: 'Ditolak / Dibekukan',
                          value: '$otherCount',
                          color: Colors.red.shade700,
                          icon: Icons.block_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Kolom Pencarian & Tab Kontrol
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'Cari kos berdasarkan nama, alamat, kontak, kode...',
                              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            labelColor: const Color(0xFF2563EB),
                            unselectedLabelColor: const Color(0xFF64748B),
                            indicatorColor: const Color(0xFF2563EB),
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            tabs: [
                              Tab(text: 'Semua Kos (${_allKosts.length})'),
                              Tab(text: 'Menunggu Verifikasi ($pendingCount)'),
                              Tab(text: 'Aktif ($activeCount)'),
                              Tab(text: 'Ditolak / Dibekukan ($otherCount)'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Daftar Kartu Properti Kos
                    if (filteredKosts.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF94A3B8)),
                            SizedBox(height: 12),
                            Text(
                              'Tidak ada data properti kos pada kategori ini.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredKosts.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (ctx, idx) => _buildKostCard(filteredKosts[idx]),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKostCard(KostModel kos) {
    Color statusBgColor;
    Color statusTextColor;
    switch (kos.statusVerifikasi) {
      case KostStatus.active:
        statusBgColor = const Color(0xFFDCFCE7);
        statusTextColor = const Color(0xFF166534);
        break;
      case KostStatus.rejected:
        statusBgColor = const Color(0xFFFEE2E2);
        statusTextColor = const Color(0xFF991B1B);
        break;
      case KostStatus.suspended:
        statusBgColor = const Color(0xFFFEF3C7);
        statusTextColor = const Color(0xFF92400E);
        break;
      case KostStatus.pendingVerification:
        statusBgColor = const Color(0xFFFEF3C7);
        statusTextColor = const Color(0xFFB45309);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris 1: Nama Kos & Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kos.namaKost,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kode Undangan: ${kos.kodeKost ?? "Belum ada"}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              // Badge Paket
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: kos.isJuragan ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: kos.isJuragan ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Text(
                  kos.tier.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kos.isJuragan ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                  ),
                ),
              ),
              // Badge Status Verifikasi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  kos.statusVerifikasi.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Detail Alamat & Kontak
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  kos.alamat.isNotEmpty ? kos.alamat : 'Alamat belum diisi lengkap.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                'Kontak: ${kos.nomorKontak}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.meeting_room_outlined, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                'Maks Kamar: ${kos.maxRooms}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
            ],
          ),

          // Info Koordinat & Google Maps
          if (kos.latitude != null && kos.longitude != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.map_outlined, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                Text(
                  'Koordinat: ${kos.latitude}, ${kos.longitude}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    final url = kos.googleMapsUrl ??
                        'https://maps.google.com/?q=${kos.latitude},${kos.longitude}';
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tautan peta berhasil disalin ke clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text(
                    '(Salin Peta)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2563EB),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Catatan verifikasi admin jika ada
          if (kos.catatanVerifikasiAdmin != null &&
              kos.catatanVerifikasiAdmin!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Catatan Admin: ${kos.catatanVerifikasiAdmin}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Tombol Aksi & Dokumen Verifikasi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Tombol Lihat Dokumen KTP & Fisik
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.badge_outlined, size: 16),
                    label: const Text('Cek KTP', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showDocumentViewer(
                      title: 'Dokumen KTP Pemilik: ${kos.namaKost}',
                      url: kos.dokumenKtpUrl,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.apartment_outlined, size: 16),
                    label: const Text('Foto Bangunan', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showDocumentViewer(
                      title: 'Foto Fisik Bangunan: ${kos.namaKost}',
                      url: kos.fotoBangunanUrl,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ],
              ),

              // Tombol Verifikasi
              Row(
                children: [
                  if (kos.isPending || kos.isRejected) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Setujui', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showApprovalDialog(kos),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                  if (kos.isPending) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Tolak', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showRejectionDialog(kos),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                  if (kos.isActive || kos.isSuspended) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
                      onSelected: (val) {
                        if (val == 'suspend') {
                          _showSuspendDialog(kos);
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'suspend',
                          child: Text(
                            kos.isSuspended ? 'Aktifkan Kembali' : 'Bekukan Akun Kos',
                            style: TextStyle(
                              color: kos.isSuspended ? const Color(0xFF16A34A) : Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
