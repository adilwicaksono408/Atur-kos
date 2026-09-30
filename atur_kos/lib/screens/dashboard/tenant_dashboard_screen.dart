import 'package:flutter/material.dart';
import 'package:atur_kos/models/user_profile.dart';
import 'package:atur_kos/services/auth_service.dart';

/// Halaman Dasbor Utama untuk Peran Penghuni Kos (Tenant)
/// Sesuai PRD: Menangani status teralokasi (Active) & status belum ada kamar (Unallocated)
class TenantDashboardScreen extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback? onSwitchRole;

  const TenantDashboardScreen({
    super.key,
    required this.profile,
    this.onSwitchRole,
  });

  @override
  State<TenantDashboardScreen> createState() => _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends State<TenantDashboardScreen> {
  // Simulasi status alokasi kamar (true = sudah dapat kamar, false = unallocated)
  bool _hasAssignedRoom = true;
  bool _isProofUploaded = false;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userName = widget.profile.fullName.isNotEmpty
        ? widget.profile.fullName
        : 'Dimas';

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
          // Tombol beralih peran untuk keperluan testing/demonstrasi PRD
          if (widget.onSwitchRole != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: widget.onSwitchRole,
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Mode Pemilik'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0D9488),
                  backgroundColor: const Color(0xFFF0FDFA),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Switcher simulasi kondisi Penghuni (Sudah ada kamar vs Menunggu alokasi)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _hasAssignedRoom ? Icons.check_circle_outline : Icons.schedule_rounded,
                          color: _hasAssignedRoom ? const Color(0xFF0D9488) : const Color(0xFFD97706),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _hasAssignedRoom ? 'Status: Aktif Menghuni' : 'Status: Belum Ada Kamar',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _hasAssignedRoom = !_hasAssignedRoom;
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        _hasAssignedRoom ? 'Uji Mode Belum Ada Kamar' : 'Uji Mode Ada Kamar',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),

              // Jika Penghuni belum dialokasikan kamar (Sesuai US-1.1 PRD)
              if (!_hasAssignedRoom)
                _buildUnallocatedState(userName)
              else
                _buildAllocatedState(userName),
            ],
          ),
        ),
      ),
    );
  }

  /// Tampilan saat penghuni baru mendaftar dan belum dialokasikan kamar oleh Pemilik
  Widget _buildUnallocatedState(String userName) {
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
              color: const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: Color(0xFFD97706),
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
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Text(
              'Menunggu Alokasi Kamar oleh Pemilik',
              style: TextStyle(
                color: Color(0xFFB45309),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Akun Anda telah terdaftar sebagai Penghuni di Kos Princess. Saat ini Ibu Rina (Pemilik Kos) belum memasukkan nomor kamar Anda ke sistem.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Membuka kontak WhatsApp Pemilik: 628123456789 (Ibu Rina)'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.chat_rounded, color: Color(0xFF059669)),
            label: const Text('Hubungi Ibu Rina via WhatsApp'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF059669),
              side: const BorderSide(color: Color(0xFF059669)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  /// Tampilan saat penghuni sudah memiliki kamar aktif di Kos Princess
  Widget _buildAllocatedState(String userName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kartu Identitas Kamar Penghuni
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.25),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Kamar Terdaftar Aktif',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Sewa Berjalan',
                      style: TextStyle(
                        color: Color(0xFF0D9488),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Kamar 05 (Lantai 2)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tipe: Deluxe AC • Kamar Mandi Dalam • WiFi • Kasur Queen',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_repeat_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Jatuh Tempo: Setiap tanggal 1 per bulan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
                        'Periode Oktober 2026',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Rp 1.500.000',
                        style: TextStyle(
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
              const Row(
                children: [
                  Icon(Icons.account_balance_rounded, size: 16, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Text(
                    'Rekening Tujuan: BCA 1234567890 a.n Ibu Rina',
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
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

        // Fitur Cepat Penghuni
        const Text(
          'Layanan & Bantuan Kos',
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
                onTap: () {
                  _showInfoDialog(
                    context,
                    'Helpdesk Keluhan Fasilitas',
                    'Laporkan kerusakan (misal: genteng bocor, WiFi mati, lampu putus) dengan melampirkan foto. Status perbaikan dapat dipantau langsung di sini.',
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildServiceTile(
                icon: Icons.inventory_2_rounded,
                color: const Color(0xFF3B82F6),
                title: 'Paket & Info Kos',
                subtitle: 'Papan pengumuman',
                onTap: () {
                  _showInfoDialog(
                    context,
                    'Papan Pengumuman & Paket Kurir',
                    'Cek paket kiriman kurir yang telah tiba di pos kos atau pengumuman resmi dari Ibu Rina.',
                  );
                },
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
                title: 'Perpanjangan Sewa',
                subtitle: 'Konfirmasi komitmen H-30',
                onTap: () {
                  _showInfoDialog(
                    context,
                    'Konfirmasi Perpanjangan Sewa (H-30)',
                    'Sesuai PRD Seksi 5.5: Fitur konfirmasi apakah Anda akan melanjutkan sewa untuk bulan berikutnya atau mengakhiri sewa secara tertib.',
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildServiceTile(
                icon: Icons.receipt_rounded,
                color: const Color(0xFF059669),
                title: 'Riwayat Kuitansi',
                subtitle: 'Bukti bayar sah',
                onTap: () {
                  _showInfoDialog(
                    context,
                    'Riwayat Kuitansi Digital',
                    'Lihat seluruh riwayat pembayaran sewa bulanan Anda yang telah divalidasi lunas oleh pemilik kos.',
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

  void _showInfoDialog(BuildContext context, String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(description, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
