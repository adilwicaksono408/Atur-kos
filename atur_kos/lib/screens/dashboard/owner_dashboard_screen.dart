import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:atur_kos/models/user_profile.dart';
import 'package:atur_kos/services/auth_service.dart';
import 'package:atur_kos/services/kos_service.dart';
import 'package:atur_kos/screens/owner/kos_settings_screen.dart';
import 'package:atur_kos/screens/owner/room_management_screen.dart';
import 'package:atur_kos/screens/owner/invoice_management_screen.dart';
import 'package:atur_kos/screens/owner/tenant_allocation_screen.dart';
import 'package:atur_kos/screens/owner/complaint_management_screen.dart';
import 'package:atur_kos/screens/owner/room_poster_generator_screen.dart';
import 'package:atur_kos/utils/format_utils.dart';

/// Halaman Dasbor Utama untuk Peran Pemilik Kos (Owner)
/// Menghubungkan metrik operasional secara real-time dari database Supabase
class OwnerDashboardScreen extends StatefulWidget {
  final UserProfile profile;

  const OwnerDashboardScreen({
    super.key,
    required this.profile,
  });

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  Map<String, dynamic>? _kosProfile;
  OperationalSummary _summary = const OperationalSummary();
  List<Map<String, dynamic>> _pendingInvoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  /// Mengambil data properti, ringkasan operasional real-time, dan tagihan pending
  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    final kostId = widget.profile.kostId;

    final results = await Future.wait([
      KosService.getKosProfile(kostId),
      KosService.getOperationalSummary(kostId),
      KosService.getInvoices(kostId, statusFilter: 'menunggu_verifikasi'),
    ]);

    if (mounted) {
      setState(() {
        _kosProfile = results[0] as Map<String, dynamic>?;
        _summary = results[1] as OperationalSummary;
        _pendingInvoices = results[2] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    }
  }

  /// Verifikasi cepat pembayaran dari dasbor (PRD US-3.3 & US-6.1)
  Future<void> _verifyInvoiceQuick(Map<String, dynamic> invoice) async {
    final invoiceId = invoice['id'].toString();
    final nomorInvoice = invoice['nomor_invoice']?.toString() ?? '-';
    final nominal = (invoice['nominal'] as num?)?.toDouble() ?? 0.0;
    final kostId = widget.profile.kostId ?? _kosProfile?['id']?.toString() ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Verifikasi Pembayaran'),
          ],
        ),
        content: Text(
          'Konfirmasi pelunasan tagihan $nomorInvoice sebesar ${FormatUtils.rupiah(nominal)}? Kas masuk akan otomatis dicatat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            child: const Text('Verifikasi Lunas'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await KosService.verifyInvoice(
      invoiceId: invoiceId,
      kostId: kostId,
      nominal: nominal,
      nomorInvoice: nomorInvoice,
      approve: true,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Tagihan $nomorInvoice berhasil diverifikasi Lunas! Arus kas masuk bertambah.'
                : 'Gagal memverifikasi tagihan.',
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      _fetchDashboardData();
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

  String _getFormattedOwnerName() {
    final name = widget.profile.fullName.trim();
    if (name.isEmpty || name == 'Pengguna') {
      return 'Pemilik Kos';
    }
    if (name.contains('@')) {
      final prefix = name.split('@').first;
      if (prefix.isNotEmpty) {
        return prefix[0].toUpperCase() + prefix.substring(1);
      }
      return 'Pemilik Kos';
    }
    return name;
  }

  void _shareInvitationCode(BuildContext context, String code, String kosName) {
    final invitationText =
        'Halo! Silakan unduh aplikasi Atur Kos dan masukkan Kode Undangan: $code saat mendaftar untuk terhubung langsung ke $kosName.';
    Clipboard.setData(ClipboardData(text: invitationText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Teks undangan WhatsApp berhasil disalin ke clipboard! Siap dibagikan ke calon penghuni.',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E40AF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kosName = _kosProfile?['nama_kost']?.toString() ?? 'Kos Princess';
    final resolvedKostId = widget.profile.kostId ?? _kosProfile?['id']?.toString();

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
                color: const Color(0xFF1E40AF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.apartment_rounded,
                color: Color(0xFF1E40AF),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Atur Kos • Pemilik',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    kosName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Segarkan Data',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E40AF)),
            onPressed: _fetchDashboardData,
          ),
          IconButton(
            tooltip: 'Pengaturan Properti Kos',
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF1E40AF)),
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => KosSettingsScreen(
                    kostId: resolvedKostId,
                    currentKosName: kosName,
                  ),
                ),
              );
              if (updated == true) {
                _fetchDashboardData();
              }
            },
          ),
          IconButton(
            tooltip: 'Keluar Akun',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
            onPressed: () async {
              await AuthService.signOut();
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner Selamat Datang Pemilik Kos
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E40AF).withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_user_rounded,
                                    color: Colors.white, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'Role: Pemilik / Pengelola Properti',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Sistem Aktif',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${_getGreeting()}, ${_getFormattedOwnerName()}! 👋',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Operasional terpantau rapi. ${_summary.pendingVerificationCount} tagihan menunggu verifikasi, ${_summary.activeComplaintsCount} keluhan aktif, dan ${_summary.emptyRooms} kamar siap dihuni.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // KARTU KODE UNDANGAN KOS (MULTI-TENANT & INVITATION LINK)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
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
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.share_rounded,
                            color: Color(0xFF1E40AF), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kode Undangan Kos Anda',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  _kosProfile?['kode_kost']?.toString() ?? 'PRINCESS',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: Color(0xFF1E40AF),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Text(
                                    'Aktif',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          final code =
                              _kosProfile?['kode_kost']?.toString() ?? 'PRINCESS';
                          _shareInvitationCode(context, code, kosName);
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Bagikan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // KPI Metrik Cepat Sesuai PRD (REAL-TIME DARI SUPABASE)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ringkasan Operasional Properti',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 500;
                    return GridView.count(
                      crossAxisCount: isWide ? 4 : 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: isWide ? 1.35 : 1.22,
                      children: [
                        _buildMetricCard(
                          title: 'Tingkat Okupansi',
                          value:
                              '${_summary.occupiedRooms} / ${_summary.totalRooms}',
                          subtext:
                              '${_summary.occupancyRate.toStringAsFixed(0)}% (${_summary.emptyRooms} Kamar Kosong)',
                          icon: Icons.meeting_room_rounded,
                          color: const Color(0xFF2563EB),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RoomManagementScreen(
                                  kostId: resolvedKostId,
                                  kosName: kosName,
                                ),
                              ),
                            ).then((_) => _fetchDashboardData());
                          },
                        ),
                        _buildMetricCard(
                          title: 'Kas Masuk Riil',
                          value: FormatUtils.compactRupiah(_summary.pemasukanKasRiil),
                          subtext: 'Kas masuk lunas bulan ini',
                          icon: Icons.account_balance_wallet_rounded,
                          color: const Color(0xFF059669),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InvoiceManagementScreen(
                                  kostId: resolvedKostId,
                                  kosName: kosName,
                                ),
                              ),
                            ).then((_) => _fetchDashboardData());
                          },
                        ),
                        _buildMetricCard(
                          title: 'Tunggakan Sewa',
                          value: FormatUtils.compactRupiah(_summary.totalTunggakan),
                          subtext:
                              '${_summary.tunggakanCount} tagihan belum bayar',
                          icon: Icons.warning_amber_rounded,
                          color: const Color(0xFFDC2626),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InvoiceManagementScreen(
                                  kostId: resolvedKostId,
                                  kosName: kosName,
                                ),
                              ),
                            ).then((_) => _fetchDashboardData());
                          },
                        ),
                        _buildMetricCard(
                          title: 'Verifikasi Bayar',
                          value: '${_summary.pendingVerificationCount} Menunggu',
                          subtext: 'Perlu konfirmasi Anda',
                          icon: Icons.pending_actions_rounded,
                          color: const Color(0xFFD97706),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InvoiceManagementScreen(
                                  kostId: resolvedKostId,
                                  kosName: kosName,
                                ),
                              ),
                            ).then((_) => _fetchDashboardData());
                          },
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 28),

                // Fitur Utama & Aksi Cepat (PRD Modul 2, 3, 4, 5)
                const Text(
                  'Menu Utama Pemilik',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.bed_rounded,
                        color: const Color(0xFF2563EB),
                        title: 'Kelola Kamar',
                        subtitle: 'Inventaris & Preset Kamar',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RoomManagementScreen(
                                kostId: resolvedKostId,
                                kosName: kosName,
                              ),
                            ),
                          ).then((_) => _fetchDashboardData());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.person_add_alt_1_rounded,
                        color: const Color(0xFF0284C7),
                        title: 'Alokasi Penghuni',
                        subtitle: 'Hubungkan Akun ke Kamar',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TenantAllocationScreen(
                                kostId: resolvedKostId,
                                kosName: kosName,
                              ),
                            ),
                          ).then((_) => _fetchDashboardData());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.receipt_long_rounded,
                        color: const Color(0xFF059669),
                        title: 'Smart Billing & Kas',
                        subtitle: 'Tagihan & Pengingat WA',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InvoiceManagementScreen(
                                kostId: resolvedKostId,
                                kosName: kosName,
                              ),
                            ),
                          ).then((_) => _fetchDashboardData());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.build_circle_rounded,
                        color: const Color(0xFFDC2626),
                        title: 'Helpdesk Keluhan',
                        subtitle: '${_summary.activeComplaintsCount} tiket aktif',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ComplaintManagementScreen(
                                kostId: resolvedKostId,
                                kosName: kosName,
                              ),
                            ),
                          ).then((_) => _fetchDashboardData());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: Icons.campaign_rounded,
                  color: const Color(0xFFD97706),
                  title: 'Poster Promosi AI & Radar H-30',
                  subtitle: 'Pemasaran kamar kosong & radar konfirmasi akhir sewa',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoomPosterGeneratorScreen(
                          kostId: resolvedKostId,
                          kosName: kosName,
                        ),
                      ),
                    ).then((_) => _fetchDashboardData());
                  },
                ),

                const SizedBox(height: 32),

                // Seksi Tindakan Segera: Verifikasi Bukti Transfer Real-Time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Verifikasi Pembayaran Sewa',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _pendingInvoices.isEmpty
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_pendingInvoices.length} Perlu Tindakan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _pendingInvoices.isEmpty
                              ? const Color(0xFF059669)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_pendingInvoices.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            color: Color(0xFF059669), size: 40),
                        const SizedBox(height: 10),
                        const Text(
                          'Semua Pembayaran Telah Terverifikasi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tidak ada tagihan yang menunggu verifikasi saat ini. Pemasukan kas tercatat rapi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InvoiceManagementScreen(
                                  kostId: resolvedKostId,
                                  kosName: kosName,
                                ),
                              ),
                            ).then((_) => _fetchDashboardData());
                          },
                          child: const Text('Buka Kelola Tagihan & Kas'),
                        ),
                      ],
                    ),
                  )
                else
                  ..._pendingInvoices.map((inv) {
                    final tenant = inv['tenants'] as Map<String, dynamic>?;
                    final profile = tenant?['profiles'] as Map<String, dynamic>?;
                    final room = tenant?['rooms'] as Map<String, dynamic>?;

                    final tenantName =
                        profile?['full_name']?.toString() ?? 'Penghuni';
                    final roomNum = room?['nomor_kamar']?.toString() ?? '-';
                    final nominal =
                        (inv['nominal'] as num?)?.toDouble() ?? 0.0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.receipt_rounded,
                              color: Color(0xFF1E40AF),
                              size: 26,
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
                                      tenantName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Kamar $roomNum',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${FormatUtils.rupiah(nominal)} • Menunggu konfirmasi',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _verifyInvoiceQuick(inv),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text('Verifikasi 1-Klik',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 24),

                // Kartu Status Keluhan Fasilitas (PRD Modul 4)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.plumbing_rounded,
                          color: Color(0xFF7C3AED),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Keluhan Terkini (Fasilitas Kos)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _summary.activeComplaintsCount > 0
                                  ? '${_summary.activeComplaintsCount} keluhan aktif sedang dalam penanganan teknisi.'
                                  : 'Seluruh fasilitas kamar & bersama dalam kondisi baik tanpa laporan kerusakan.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                height: 1.3,
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
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtext,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
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
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
            ],
          ),
        ),
      ),
    );
  }
}
