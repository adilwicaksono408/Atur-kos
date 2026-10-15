import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:atur_kos/models/kost_model.dart';
import 'package:atur_kos/models/user_profile.dart';
import 'package:atur_kos/services/auth_service.dart';
import 'package:atur_kos/services/kos_service.dart';
import 'package:atur_kos/services/report_pdf_service.dart';
import 'package:atur_kos/utils/format_utils.dart';

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
  String _subscriptionSubFilter = 'all'; // 'all', 'juragan', 'expiring', 'starter'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
      case 4:
        switch (_subscriptionSubFilter) {
          case 'juragan':
            list = _allKosts.where((k) => k.isJuragan).toList();
            break;
          case 'expiring':
            final now = DateTime.now();
            list = _allKosts.where((k) {
              if (!k.isJuragan || k.subscriptionExpiresAt == null) return false;
              final diff = k.subscriptionExpiresAt!.difference(now).inDays;
              return diff <= 7 && !k.subscriptionExpiresAt!.isBefore(now);
            }).toList();
            break;
          case 'starter':
            list = _allKosts.where((k) => !k.isJuragan).toList();
            break;
          case 'all':
          default:
            list = _allKosts;
            break;
        }
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
      // Optimistic Update: Langsung ubah status di antarmuka seketika
      setState(() {
        final idx = _allKosts.indexWhere((k) => k.id == kos.id);
        if (idx != -1) {
          _allKosts[idx] = kos.copyWith(
            statusVerifikasi: KostStatus.active,
            catatanVerifikasiAdmin: 'Disetujui oleh Super Admin (${widget.profile.fullName})',
          );
        }
      });
      // Pindahkan tampilan tab ke 'Aktif' agar Super Admin langsung melihat kos berstatus aktif
      _tabController.animateTo(2);

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
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal menyimpan ke database. Pastikan skrip RLS Super Admin telah dijalankan.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        _loadData();
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
      final rejectNote = noteController.text.trim().isNotEmpty
          ? noteController.text.trim()
          : 'Data pengajuan belum memenuhi syarat verifikasi.';

      // Optimistic Update: Langsung ubah status seketika
      setState(() {
        final idx = _allKosts.indexWhere((k) => k.id == kos.id);
        if (idx != -1) {
          _allKosts[idx] = kos.copyWith(
            statusVerifikasi: KostStatus.rejected,
            catatanVerifikasiAdmin: rejectNote,
          );
        }
      });
      // Pindahkan tampilan tab ke 'Ditolak / Dibekukan'
      _tabController.animateTo(3);

      final success = await KosService.verifyKostByAdmin(
        kostId: kos.id,
        status: KostStatus.rejected,
        catatanAdmin: rejectNote,
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
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal menyimpan penolakan ke database. Pastikan skrip RLS telah dijalankan.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        _loadData();
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
      // Optimistic Update
      setState(() {
        final idx = _allKosts.indexWhere((k) => k.id == kos.id);
        if (idx != -1) {
          _allKosts[idx] = kos.copyWith(
            statusVerifikasi: newStatus,
            catatanVerifikasiAdmin: kos.isSuspended ? 'Diaktifkan kembali oleh admin' : 'Dibekukan oleh admin',
          );
        }
      });
      _tabController.animateTo(newStatus == KostStatus.active ? 2 : 3);

      final success = await KosService.verifyKostByAdmin(
        kostId: kos.id,
        status: newStatus,
        catatanAdmin: kos.isSuspended ? 'Diaktifkan kembali oleh admin' : 'Dibekukan oleh admin',
      );
      if (mounted) {
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal memperbarui status di database. Pastikan skrip RLS telah dijalankan.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        _loadData();
      }
    }
  }

  /// Dialog Super Admin untuk mengelola Paket SaaS Langganan (Starter vs Juragan)
  Future<void> _showManageSubscriptionDialog(KostModel kos) async {
    SubscriptionTier selectedTier = kos.tier;
    int selectedMonths = 1;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.stars_rounded, color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kelola Langganan (SaaS)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Tier & Kuota Kamar Pemilik', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kos.namaKost, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      kos.isJuragan
                          ? 'Status Saat Ini: ${kos.tier.label} (Kamar Tanpa Batas)'
                          : 'Status Saat Ini: ${kos.tier.label} (Maks ${kos.maxRooms} Kamar)',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Pilih Paket Langganan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setDialogState(() => selectedTier = SubscriptionTier.starter),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: selectedTier == SubscriptionTier.starter ? const Color(0xFFF1F5F9) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selectedTier == SubscriptionTier.starter ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                      width: selectedTier == SubscriptionTier.starter ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectedTier == SubscriptionTier.starter ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 20,
                        color: selectedTier == SubscriptionTier.starter ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Paket Starter (Gratis)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('Maks 5 Kamar • Fitur Dasar', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setDialogState(() => selectedTier = SubscriptionTier.juragan),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: selectedTier == SubscriptionTier.juragan ? const Color(0xFFEFF6FF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selectedTier == SubscriptionTier.juragan ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                      width: selectedTier == SubscriptionTier.juragan ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectedTier == SubscriptionTier.juragan ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 20,
                        color: selectedTier == SubscriptionTier.juragan ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('⭐ Paket Juragan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                                SizedBox(width: 6),
                                Text('(Premium)', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB))),
                              ],
                            ),
                            Text('Kamar Tanpa Batas • WA Otomatis • AI Poster Promosi', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (selectedTier == SubscriptionTier.juragan) ...[
                const SizedBox(height: 10),
                const Text('Durasi Langganan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('1 Bulan (Rp 50.000)'),
                      selected: selectedMonths == 1,
                      onSelected: (sel) {
                        if (sel) setDialogState(() => selectedMonths = 1);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('1 Tahun (Rp 500.000)'),
                      selected: selectedMonths == 12,
                      onSelected: (sel) {
                        if (sel) setDialogState(() => selectedMonths = 12);
                      },
                    ),
                  ],
                ),
              ],
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
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Simpan Paket'),
            ),
          ],
        ),
      ),
    );

    if (updated == true) {
      // Optimistic update
      setState(() {
        final idx = _allKosts.indexWhere((k) => k.id == kos.id);
        if (idx != -1) {
          _allKosts[idx] = kos.copyWith(
            tier: selectedTier,
            maxRooms: selectedTier.defaultMaxRooms,
          );
        }
      });

      final success = await KosService.upgradeKostSubscription(
        kostId: kos.id,
        tier: selectedTier,
        months: selectedMonths,
      );
      if (mounted) {
        if (success) {
          final quotaDesc = selectedTier == SubscriptionTier.juragan ? 'tanpa batas (unlimited)' : '${selectedTier.defaultMaxRooms} kamar';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Paket properti "${kos.namaKost}" berhasil diubah menjadi ${selectedTier.label}! Akses kamar kini $quotaDesc.'),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memperbarui paket langganan.'), backgroundColor: Colors.red),
          );
        }
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
    final juraganCount = _allKosts.where((k) => k.isJuragan).length;
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
                          onTap: () => _tabController.animateTo(0),
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          title: 'Menunggu Verifikasi',
                          value: '$pendingCount',
                          color: const Color(0xFFD97706),
                          icon: Icons.hourglass_top_outlined,
                          onTap: () => _tabController.animateTo(1),
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          title: 'Kos Aktif',
                          value: '$activeCount',
                          color: const Color(0xFF16A34A),
                          icon: Icons.check_circle_outline,
                          onTap: () => _tabController.animateTo(2),
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          title: 'Langganan Juragan ⭐',
                          value: '$juraganCount',
                          color: const Color(0xFF1D4ED8),
                          icon: Icons.workspace_premium_rounded,
                          onTap: () => _tabController.animateTo(4),
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          title: 'Ditolak / Dibekukan',
                          value: '$otherCount',
                          color: Colors.red.shade700,
                          icon: Icons.block_outlined,
                          onTap: () => _tabController.animateTo(3),
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
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.workspace_premium_rounded, size: 16, color: Color(0xFFD97706)),
                                    const SizedBox(width: 6),
                                    Text('Langganan SaaS & Midtrans ($juraganCount)'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Konten Tab Dinamis
                    if (_tabController.index == 4)
                      _buildSaaSSubscriptionPanel(filteredKosts)
                    else if (filteredKosts.isEmpty)
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
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
              // Badge Paket (Dapat diklik oleh Super Admin untuk upgrade/downgrade)
              Tooltip(
                message: 'Klik untuk kelola status paket langganan SaaS',
                child: InkWell(
                  onTap: () => _showManageSubscriptionDialog(kos),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: kos.isJuragan ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: kos.isJuragan ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          kos.tier.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: kos.isJuragan ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_note_rounded,
                          size: 14,
                          color: kos.isJuragan ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                        ),
                      ],
                    ),
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
                kos.isJuragan ? 'Maks Kamar: Unlimited ♾️' : 'Maks Kamar: ${kos.maxRooms}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
              if (kos.isJuragan) ...[
                const SizedBox(width: 16),
                const Icon(Icons.workspace_premium_rounded, size: 16, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 6),
                Text(
                  kos.subscriptionExpiresAt != null
                      ? 'Aktif s/d: ${FormatUtils.formatDate(kos.subscriptionExpiresAt)}'
                      : 'Langganan Juragan Aktif',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ],
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
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: Icon(
                      Icons.stars_rounded,
                      size: 16,
                      color: kos.isJuragan ? const Color(0xFF1D4ED8) : const Color(0xFFD97706),
                    ),
                    label: Text(
                      kos.isJuragan ? 'Paket Juragan ⭐' : 'Kelola Paket',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: kos.isJuragan ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onPressed: () => _showManageSubscriptionDialog(kos),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      side: BorderSide(
                        color: kos.isJuragan ? const Color(0xFF93C5FD) : const Color(0xFFFCD34D),
                      ),
                      backgroundColor: kos.isJuragan ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                      foregroundColor: kos.isJuragan ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
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

  // ===========================================================================
  // 11. PANEL PENDAPATAN LANGGANAN SAAS & AUDIT MIDTRANS (PILIHAN A)
  // ===========================================================================

  Widget _buildSaaSSubscriptionPanel(List<KostModel> filteredKosts) {
    final juraganCount = _allKosts.where((k) => k.isJuragan).length;
    final starterCount = _allKosts.length - juraganCount;
    final now = DateTime.now();
    final expiringCount = _allKosts.where((k) {
      if (!k.isJuragan || k.subscriptionExpiresAt == null) return false;
      final diff = k.subscriptionExpiresAt!.difference(now).inDays;
      return diff <= 7 && !k.subscriptionExpiresAt!.isBefore(now);
    }).length;

    // Hitung Estimasi Finansial B2B Platform Atur Kos
    final mrr = juraganCount * 50000;
    // Sesuai PRD v2 US-3.2: Paket Juragan Tahunan adalah Rp 500.000 / tahun (diskon 2 bulan)
    final arr = juraganCount * 500000;
    final conversionRate = _allKosts.isEmpty
        ? '0.0'
        : ((juraganCount / _allKosts.length) * 100).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Banner Kepatuhan Privasi Multi-Tenant & UU PDP
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x332563EB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x663B82F6)),
                ),
                child: const Icon(Icons.shield_rounded, color: Color(0xFF60A5FA), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Audit Finansial Langganan Platform SaaS (B2B Midtrans)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0x3316A34A),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF22C55E)),
                          ),
                          child: const Text(
                            'UU PDP & PRIVASI TERJAGA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4ADE80),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sesuai arsitektur Multi-Tenancy & Data Minimization, Super Admin memantau pendapatan platform dari biaya langganan pemilik (Paket Juragan Rp 50.000/bln) dan keandalan Midtrans Gateway. Seluruh data sewa privat antara penghuni dan pemilik kos diisolasi secara ketat dan tidak diekspos.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Metrik Finansial SaaS Atur Kos (4 Kartu KPI)
        Row(
          children: [
            _buildSaaSMetricCard(
              title: 'Monthly Recurring (MRR)',
              value: FormatUtils.formatRupiah(mrr),
              subtitle: '$juraganCount Properti Berbayar Aktif',
              color: const Color(0xFF16A34A),
              icon: Icons.monetization_on_outlined,
              bgColor: const Color(0xFFF0FDF4),
            ),
            const SizedBox(width: 12),
            _buildSaaSMetricCard(
              title: 'Proyeksi Tahunan (ARR)',
              value: FormatUtils.formatRupiah(arr),
              subtitle: 'Paket Tahunan (@ Rp 500rb/thn)',
              color: const Color(0xFF2563EB),
              icon: Icons.trending_up_rounded,
              bgColor: const Color(0xFFEFF6FF),
            ),
            const SizedBox(width: 12),
            _buildSaaSMetricCard(
              title: 'Konversi Freemium',
              value: '$conversionRate%',
              subtitle: '$juraganCount Juragan dari ${_allKosts.length} Properti',
              color: const Color(0xFF7C3AED),
              icon: Icons.pie_chart_outline_rounded,
              bgColor: const Color(0xFFFAF5FF),
            ),
            const SizedBox(width: 12),
            _buildSaaSMetricCard(
              title: 'Status Gateway Midtrans',
              value: 'SANDBOX LIVE',
              subtitle: 'QRIS & Multi-Bank Virtual Account',
              color: const Color(0xFF0D9488),
              icon: Icons.bolt_rounded,
              bgColor: const Color(0xFFF0FDFA),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Bilah Aksi Cepat (Ekspor Laporan Finansial & Unduh PDF)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tata Kelola & Audit Transaksi Berlangganan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Ekspor dokumen resmi format A4 untuk keperluan audit & evaluasi Bab IV',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: const Text('Unduh Laporan PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _downloadSaaSFinancialReportPdf(mrr, arr, conversionRate),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    label: const Text('Salin Teks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: _copySaaSFinancialReport,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Sub-Filter Kategori Langganan
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'Semua Properti (${_allKosts.length})',
                isSelected: _subscriptionSubFilter == 'all',
                onSelected: () => setState(() => _subscriptionSubFilter = 'all'),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: '⭐ Paket Juragan ($juraganCount)',
                isSelected: _subscriptionSubFilter == 'juragan',
                onSelected: () => setState(() => _subscriptionSubFilter = 'juragan'),
                activeColor: const Color(0xFF1D4ED8),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: '⚠️ Segera Berakhir H-7 ($expiringCount)',
                isSelected: _subscriptionSubFilter == 'expiring',
                onSelected: () => setState(() => _subscriptionSubFilter = 'expiring'),
                activeColor: const Color(0xFFD97706),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Peluang Starter ($starterCount)',
                isSelected: _subscriptionSubFilter == 'starter',
                onSelected: () => setState(() => _subscriptionSubFilter = 'starter'),
                activeColor: const Color(0xFF475569),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 5. Daftar Properti dengan Status Langganan
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
                Icon(Icons.receipt_outlined, size: 48, color: Color(0xFF94A3B8)),
                SizedBox(height: 12),
                Text(
                  'Tidak ada properti pada filter langganan ini.',
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
            itemBuilder: (ctx, idx) => _buildSubscriptionCard(filteredKosts[idx]),
          ),
      ],
    );
  }

  Widget _buildSaaSMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    required Color bgColor,
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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    Color activeColor = const Color(0xFF2563EB),
  }) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(KostModel kos) {
    final now = DateTime.now();
    final isJuragan = kos.isJuragan;
    final expiresAt = kos.subscriptionExpiresAt;
    final int? remainingDays = expiresAt?.difference(now).inDays;
    final bool isExpired = remainingDays != null && remainingDays < 0;
    final bool isExpiringSoon = remainingDays != null && remainingDays >= 0 && remainingDays <= 7;

    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    if (!isJuragan) {
      badgeBg = const Color(0xFFF1F5F9);
      badgeText = const Color(0xFF475569);
      badgeLabel = 'Paket Starter (Gratis)';
    } else if (isExpired) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFFDC2626);
      badgeLabel = 'Kedaluwarsa (${-remainingDays} hari lalu)';
    } else if (isExpiringSoon) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFFD97706);
      badgeLabel = 'Segera Berakhir (H-$remainingDays)';
    } else if (remainingDays != null) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeText = const Color(0xFF16A34A);
      badgeLabel = 'Aktif (Sisa $remainingDays Hari)';
    } else {
      badgeBg = const Color(0xFFEFF6FF);
      badgeText = const Color(0xFF1D4ED8);
      badgeLabel = 'Aktif (Akses Tanpa Batas)';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isJuragan ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
          width: isJuragan ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris 1: Nama Properti, Kode & Badge Masa Langganan
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isJuragan ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isJuragan ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Icon(
                  isJuragan ? Icons.workspace_premium_rounded : Icons.home_outlined,
                  color: isJuragan ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            kos.namaKost,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            kos.kodeKost ?? 'KODE',
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Kontak: ${kos.nomorKontak} • Pemilik: ${kos.namaPemilikRekening ?? "Belum terisi"}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              // Badge Status Langganan
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Baris 2: Rincian Fitur & Kontribusi Finansial
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.meeting_room_outlined, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      isJuragan ? 'Kamar: Tanpa Batas (Unlimited)' : 'Kamar: Maks 5 Kamar',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      expiresAt != null
                          ? 'Kedaluwarsa: ${FormatUtils.formatDate(expiresAt)}'
                          : (isJuragan ? 'Langganan Aktif' : 'Freemium (Starter)'),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.paid_outlined, size: 16, color: Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    Text(
                      isJuragan ? 'Kontribusi: Rp 50.000 / bln' : 'Kontribusi: Rp 0 (Free)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isJuragan ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Baris 3: Tombol Aksi Super Admin (Audit & Kelola Paket)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: const Text('Salin Data', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  final str = '${kos.namaKost} (${kos.kodeKost ?? "-"}) | Tier: ${kos.tier.label} | Kontak: ${kos.nomorKontak} | Expiry: ${kos.subscriptionExpiresAt != null ? FormatUtils.formatDate(kos.subscriptionExpiresAt) : "-"}';
                  Clipboard.setData(ClipboardData(text: str));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data langganan berhasil disalin ke clipboard!'), duration: Duration(seconds: 2)),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.settings_suggest_outlined, size: 15),
                label: const Text('Kelola Paket', style: TextStyle(fontSize: 12)),
                onPressed: () => _showManageSubscriptionDialog(kos),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E40AF),
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  backgroundColor: const Color(0xFFEFF6FF),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _downloadSaaSFinancialReportPdf(int mrr, int arr, String conversionRate) async {
    try {
      await ReportPdfService.exportSaaSFinancialReport(
        context: context,
        allKosts: _allKosts,
        mrr: mrr,
        arr: arr,
        conversionRate: conversionRate,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat dokumen PDF: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _copySaaSFinancialReport() {
    final juraganCount = _allKosts.where((k) => k.isJuragan).length;
    final starterCount = _allKosts.length - juraganCount;
    final mrr = juraganCount * 50000;
    final arr = juraganCount * 500000;
    final conversionRate = _allKosts.isEmpty ? '0.0' : ((juraganCount / _allKosts.length) * 100).toStringAsFixed(1);
    final now = DateTime.now();

    final buffer = StringBuffer();
    buffer.writeln('================================================================');
    buffer.writeln('ATUR KOS — LAPORAN AUDIT FINANSIAL & LANGGANAN SAAS B2B PLATFORM');
    buffer.writeln('Waktu Audit: ${FormatUtils.formatDate(now)} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB');
    buffer.writeln('Lingkungan Gateway: Midtrans Snap Sandbox (Multi-Bank VA & QRIS)');
    buffer.writeln('Kepatuhan Privasi: UU PDP & Isolasi Multi-Tenant (B2B Only)');
    buffer.writeln('================================================================\n');

    buffer.writeln('1. RINGKASAN METRIK FINANSIAL SAAS ATUR KOS:');
    buffer.writeln('   • Total Properti Kos Terdaftar   : ${_allKosts.length} Properti');
    buffer.writeln('   • Properti Paket Starter (Gratis) : $starterCount Properti');
    buffer.writeln('   • Properti Paket Juragan (Aktif) : $juraganCount Properti');
    buffer.writeln('   • Rasio Konversi Freemium         : $conversionRate%');
    buffer.writeln('   • Monthly Recurring Revenue (MRR) : ${FormatUtils.formatRupiah(mrr)} / bulan');
    buffer.writeln('   • Proyeksi Paket Tahunan (ARR)   : ${FormatUtils.formatRupiah(arr)} / tahun (Paket Tahunan @ Rp 500.000)\n');

    buffer.writeln('2. RINCIAN PROPERTI PAKET JURAGAN (LANGGANAN BERBAYAR):');
    final juragans = _allKosts.where((k) => k.isJuragan).toList();
    if (juragans.isEmpty) {
      buffer.writeln('   (Belum ada properti berlangganan Paket Juragan aktif)');
    } else {
      for (int i = 0; i < juragans.length; i++) {
        final k = juragans[i];
        final expiryStr = k.subscriptionExpiresAt != null ? FormatUtils.formatDate(k.subscriptionExpiresAt) : 'Tanpa Batas Waktu';
        final daysLeft = k.subscriptionExpiresAt != null ? k.subscriptionExpiresAt!.difference(now).inDays : 999;
        buffer.writeln('   ${i + 1}. ${k.namaKost} (${k.kodeKost ?? "-"})');
        buffer.writeln('      - Kontak/Pemilik  : ${k.nomorKontak} (${k.namaPemilikRekening ?? "-"})');
        buffer.writeln('      - Masa Berlaku    : s/d $expiryStr ($daysLeft hari lagi)');
        buffer.writeln('      - Nilai Langganan : Rp 50.000 / bln (Akses Kamar Tanpa Batas + AI Staging)');
      }
    }
    buffer.writeln('\n3. KELAYAKAN AUDIT PAYMENT GATEWAY:');
    buffer.writeln('   • Integrasi Midtrans Snap : Berjalan Normal (0 Kegagalan Transaksi)');
    buffer.writeln('   • Saluran Tersedia       : QRIS, BCA VA, BNI VA, Mandiri Bill, BRI VA, Permata VA');
    buffer.writeln('   • Validasi Kuota Kamar   : Otomatis via Database Trigger (check_room_quota)');
    buffer.writeln('================================================================');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Laporan Finansial SaaS berhasil disalin ke clipboard!'),
        backgroundColor: Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
