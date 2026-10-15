import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:atur_kos/models/user_profile.dart';
import 'package:atur_kos/services/auth_service.dart';
import 'package:atur_kos/services/kos_service.dart';
import 'package:atur_kos/screens/owner/kos_settings_screen.dart';
import 'package:atur_kos/screens/owner/room_management_screen.dart';
import 'package:atur_kos/screens/owner/invoice_management_screen.dart';
import 'package:atur_kos/screens/owner/tenant_allocation_screen.dart';
import 'package:atur_kos/screens/owner/complaint_management_screen.dart';
import 'package:atur_kos/screens/owner/room_poster_generator_screen.dart';
import 'package:atur_kos/screens/owner/financial_report_screen.dart';
import 'package:atur_kos/screens/payment/midtrans_snap_payment_dialog.dart';
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
  bool _hasCheckedVerificationOnboarding = false;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  /// Mengambil data properti, ringkasan operasional real-time, dan tagihan pending
  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    String? kostId = widget.profile.kostId;

    if (user != null && widget.profile.role == UserRole.owner) {
      final syncedKostId = await KosService.ensureOwnerKosProfile(
        userId: user.id,
        userMetadata: user.userMetadata,
        currentKostId: kostId,
      );
      if (syncedKostId != null && syncedKostId.isNotEmpty) {
        kostId = syncedKostId;
      }
    }

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
      _checkAndPromptVerificationOnboarding();
    }
  }

  /// Membuka form Pengaturan & Pengajuan Verifikasi Kos
  Future<void> _openKosSettings() async {
    final metaKosName = Supabase.instance.client.auth.currentUser?.userMetadata?['nama_kost']?.toString();
    final kosName = _kosProfile?['nama_kost']?.toString() ??
        metaKosName ??
        'Properti Kos';
    final resolvedKostId = _kosProfile?['id']?.toString() ?? widget.profile.kostId;

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
  }

  /// Memeriksa apakah kos pemilik baru ini perlu langsung dimintai pengajuan verifikasi
  void _checkAndPromptVerificationOnboarding() {
    if (_hasCheckedVerificationOnboarding) return;
    _hasCheckedVerificationOnboarding = true;

    final status = _kosProfile?['status_verifikasi']?.toString() ?? 'pending_verification';
    final ktpUrl = _kosProfile?['dokumen_ktp_url']?.toString();
    final fotoUrl = _kosProfile?['foto_bangunan_url']?.toString();
    final isDokumenLengkap = (ktpUrl != null && ktpUrl.isNotEmpty) && (fotoUrl != null && fotoUrl.isNotEmpty);

    // Jika properti belum berstatus active, dorong pemilik baru untuk melengkapi dokumen
    if (status != 'active') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showVerificationOnboardingDialog(
          status: status,
          isDokumenLengkap: isDokumenLengkap,
        );
      });
    }
  }

  /// Dialog onboarding pengajuan verifikasi kos ke Super Admin
  void _showVerificationOnboardingDialog({
    required String status,
    required bool isDokumenLengkap,
  }) {
    final hasMaps = _kosProfile?['google_maps_url'] != null && _kosProfile!['google_maps_url'].toString().isNotEmpty;
    final hasFoto = _kosProfile?['foto_bangunan_url'] != null && _kosProfile!['foto_bangunan_url'].toString().isNotEmpty;
    final hasKtp = _kosProfile?['dokumen_ktp_url'] != null && _kosProfile!['dokumen_ktp_url'].toString().isNotEmpty;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E40AF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.verified_user_rounded, color: Color(0xFF1E40AF), size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pendaftaran Kos Baru',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  Text(
                    'Verifikasi Super Admin',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status == 'rejected'
                  ? 'Pengajuan verifikasi kos sebelumnya memerlukan revisi. Harap perbaiki dokumen Anda untuk ditinjau ulang oleh Super Admin.'
                  : 'Selamat datang di Atur Kos! Untuk menjamin legalitas properti dan keamanan calon penghuni, kos Anda wajib diajukan ke Super Admin untuk diverifikasi resmi.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.45),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildRequirementItem(
                    icon: Icons.map_rounded,
                    title: 'Tautan Google Maps',
                    desc: hasMaps ? 'Sudah terpasang' : 'Wajib diisi untuk lokasi',
                    isReady: hasMaps,
                  ),
                  const Divider(height: 14),
                  _buildRequirementItem(
                    icon: Icons.apartment_rounded,
                    title: 'Foto Fisik Bangunan',
                    desc: hasFoto ? 'Foto sudah diunggah' : 'Ambil dari kamera / galeri',
                    isReady: hasFoto,
                  ),
                  const Divider(height: 14),
                  _buildRequirementItem(
                    icon: Icons.badge_outlined,
                    title: 'Foto KTP Pemilik / Pengelola',
                    desc: hasKtp ? 'Foto KTP sudah diunggah' : 'Bukti identitas pengelola',
                    isReady: hasKtp,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nanti Dulu', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _openKosSettings();
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: Text(isDokumenLengkap ? 'Periksa Dokumen' : 'Lengkapi & Ajukan Sekarang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E40AF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem({
    required IconData icon,
    required String title,
    required String desc,
    required bool isReady,
  }) {
    return Row(
      children: [
        Icon(icon, color: isReady ? const Color(0xFF059669) : const Color(0xFF64748B), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
              ),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 11,
                  color: isReady ? const Color(0xFF059669) : const Color(0xFF64748B),
                  fontWeight: isReady ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        Icon(
          isReady ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: isReady ? const Color(0xFF059669) : const Color(0xFF94A3B8),
          size: 16,
        ),
      ],
    );
  }

  /// Memeriksa hak akses fitur: fitur dikunci jika kos belum berstatus active (disetujui Super Admin)
  void _guardedFeatureAction(String featureName, VoidCallback onGranted) {
    final isVerified = _kosProfile?['status_verifikasi'] == 'active';
    if (isVerified) {
      onGranted();
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.lock_rounded, color: Color(0xFFD97706), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Fitur Terkunci',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fitur "$featureName" belum dapat diakses. Kos Anda wajib diajukan dan disetujui verifikasinya oleh Super Admin terlebih dahulu sebelum operasional kamar dan transaksi dapat digunakan.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.45),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lengkapi lokasi Maps, foto bangunan, dan foto KTP Anda.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openKosSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Ajukan Verifikasi'),
            ),
          ],
        ),
      );
    }
  }

  /// Hubungi WhatsApp resmi Super Admin Atur Kos untuk pembayaran atau aktivasi
  Future<void> _contactSuperAdminWA({String? customMessage}) async {
    final kosName = _kosProfile?['nama_kost']?.toString() ?? 'Kos Saya';
    final kodeKost = _kosProfile?['kode_kost']?.toString() ?? '-';
    final message = customMessage ??
        'Halo Super Admin Atur Kos, saya pemilik kos "$kosName" (Kode: $kodeKost). Saya ingin berlangganan Paket Juragan ⭐. Mohon informasi rekening/QRIS untuk pembayaran dan aktivasinya.';
    final encodedMsg = Uri.encodeComponent(message);
    final waUrl = Uri.parse('https://wa.me/6281234567890?text=$encodedMsg');
    try {
      if (await canLaunchUrl(waUrl)) {
        await launchUrl(waUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(waUrl);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Silakan hubungi WhatsApp Super Admin: 0812-3456-7890\nPesan: $message'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Dialog Paywall Berlangganan Paket Juragan untuk Pemilik Kos Starter
  void _showPremiumUpgradeDialog({required String featureName}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF1D4ED8), size: 26),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fitur Eksklusif Juragan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Upgrade ke Paket Juragan ⭐', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fitur "$featureName" merupakan fitur premium yang hanya terbuka untuk pemilik kos yang telah berlangganan Paket Juragan.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.45),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Keuntungan Paket Juragan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                        SizedBox(width: 8),
                        Expanded(child: Text('Kapasitas Kamar Tanpa Batas / Unlimited (Starter maks 5)', style: TextStyle(fontSize: 11, color: Color(0xFF334155)))),
                      ],
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                        SizedBox(width: 8),
                        Expanded(child: Text('AI Generator Poster Promosi (Format IG & WA)', style: TextStyle(fontSize: 11, color: Color(0xFF334155)))),
                      ],
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                        SizedBox(width: 8),
                        Expanded(child: Text('Radar Mitigasi Kamar Kosong H-30 Otomatis', style: TextStyle(fontSize: 11, color: Color(0xFF334155)))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilihan Biaya Langganan:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                    ),
                    SizedBox(height: 4),
                    Text('• 1 Bulan: Rp 50.000 / kos\n• 1 Tahun: Rp 500.000 / kos (Hemat 2 Bulan)', style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A))),
                    Divider(height: 14, color: Color(0xFFBFDBFE)),
                    Row(
                      children: [
                        Icon(Icons.verified_user_rounded, size: 16, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pembayaran Otomatis & Terverifikasi Real-Time via Midtrans Payment Gateway (QRIS & Virtual Account Semua Bank).',
                            style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nanti Saja', style: TextStyle(color: Color(0xFF64748B))),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _contactSuperAdminWA();
            },
            icon: const Icon(Icons.chat_rounded, size: 16, color: Color(0xFF16A34A)),
            label: const Text('Bantuan Admin', style: TextStyle(color: Color(0xFF16A34A))),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              final resolvedKostId = widget.profile.kostId ?? _kosProfile?['id']?.toString() ?? '';
              final kosName = _kosProfile?['nama_kost']?.toString() ?? 'Kos Saya';
              MidtransSnapPaymentDialog.show(
                context,
                kostId: resolvedKostId,
                kosName: kosName,
                onPaymentSuccess: _fetchDashboardData,
              );
            },
            icon: const Icon(Icons.payment_rounded, size: 16),
            label: const Text('Bayar via Midtrans Snap (Sandbox)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F2648),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            ),
          ),
        ],
      ),
    );
  }

  /// Verifikasi cepat pembayaran dari dasbor (PRD US-3.3 & US-6.1)
  Future<void> _verifyInvoiceQuick(Map<String, dynamic> invoice) async {
    final isVerified = _kosProfile?['status_verifikasi'] == 'active';
    if (!isVerified) {
      _guardedFeatureAction('Verifikasi Pembayaran', () {});
      return;
    }

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

  Color _getVerificationStatusColor(String? status) {
    switch (status) {
      case 'active':
        return const Color(0xFF10B981);
      case 'rejected':
        return Colors.red.shade700;
      case 'suspended':
        return Colors.orange.shade800;
      case 'pending_verification':
      default:
        return const Color(0xFFD97706);
    }
  }

  String _getVerificationStatusLabel(String? status) {
    switch (status) {
      case 'active':
        return 'Terverifikasi';
      case 'rejected':
        return 'Ditolak';
      case 'suspended':
        return 'Menunggu Verifikasi';
      case 'pending_verification':
      default:
        return 'Menunggu Verifikasi';
    }
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
    final metaKosName = Supabase.instance.client.auth.currentUser?.userMetadata?['nama_kost']?.toString();
    final kosName = _kosProfile?['nama_kost']?.toString() ?? metaKosName ?? 'Properti Kos';
    final resolvedKostId = widget.profile.kostId ?? _kosProfile?['id']?.toString();
    final isVerified = _kosProfile?['status_verifikasi'] == 'active';
    final isJuragan = _kosProfile?['tier']?.toString().toLowerCase() == 'juragan';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 12,
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
            onPressed: _openKosSettings,
          ),
          IconButton(
            tooltip: 'Keluar Akun',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Keluar Akun', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: const Text('Apakah Anda yakin ingin keluar dari akun Atur Kos?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                      ),
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
          const SizedBox(width: 4),
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: isJuragan
                                    ? null
                                    : () => _showPremiumUpgradeDialog(featureName: 'Paket Juragan'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isJuragan ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(10),
                                    border: isJuragan ? null : Border.all(color: const Color(0xFFFCD34D)),
                                  ),
                                  child: Text(
                                    isJuragan
                                        ? '⭐ Paket Juragan'
                                        : 'Paket Starter (Maks 5) • Upgrade ⭐',
                                    style: TextStyle(
                                      color: isJuragan ? Colors.white : const Color(0xFF92400E),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getVerificationStatusColor(_kosProfile?['status_verifikasi']?.toString()),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _getVerificationStatusLabel(_kosProfile?['status_verifikasi']?.toString()),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
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

                // Banner Interaktif Pengajuan Verifikasi Super Admin
                if (_kosProfile != null && _kosProfile?['status_verifikasi'] != 'active') ...[
                  () {
                    final statusVerifikasi = _kosProfile?['status_verifikasi']?.toString() ?? 'pending_verification';
                    final hasFotoBangunan = _kosProfile?['foto_bangunan_url'] != null && _kosProfile!['foto_bangunan_url'].toString().isNotEmpty;
                    final hasDokumenKtp = _kosProfile?['dokumen_ktp_url'] != null && _kosProfile!['dokumen_ktp_url'].toString().isNotEmpty;
                    final isDokumenLengkap = hasFotoBangunan && hasDokumenKtp;

                    if (statusVerifikasi == 'rejected') {
                      return Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Pengajuan Verifikasi Kos Ditolak',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF991B1B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Catatan Admin: ${_kosProfile?['catatan_verifikasi_admin'] ?? "Data fisik / KTP belum valid"}. Silakan perbaiki data properti Anda.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red.shade900,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _openKosSettings,
                                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                                  label: const Text('Perbaiki Dokumen & Ajukan Ulang'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (!isDokumenLengkap) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.assignment_late_rounded, color: Color(0xFFB45309), size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Pengajuan Verifikasi Kos Diperlukan',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF92400E),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Sebagai pemilik kos baru, Anda wajib mengajukan dokumen verifikasi (Foto KTP dan Foto Bangunan) ke Super Admin agar properti resmi diaktifkan.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.amber.shade900,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: hasFotoBangunan ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      hasFotoBangunan ? '✓ Foto Bangunan Ada' : '✗ Foto Bangunan Kosong',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: hasFotoBangunan ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: hasDokumenKtp ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      hasDokumenKtp ? '✓ KTP Ada' : '✗ KTP Kosong',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: hasDokumenKtp ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _openKosSettings,
                                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                                  label: const Text('Lengkapi Dokumen & Ajukan Sekarang'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD97706),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Dokumen Lengkap tapi masih Menunggu Peninjauan Admin
                    return Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.hourglass_top_rounded, color: Color(0xFF1E40AF), size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Pengajuan Sedang Ditinjau Super Admin',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E3A8A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Dokumen KTP dan foto fisik bangunan kos Anda telah lengkap dan sedang diverifikasi oleh Super Admin Atur Kos.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF1E40AF),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _openKosSettings,
                                icon: const Icon(Icons.visibility_rounded, size: 18),
                                label: const Text('Periksa Dokumen Pengajuan'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1E40AF),
                                  side: const BorderSide(color: Color(0xFF93C5FD)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }(),
                ],

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
                                  _kosProfile?['kode_kost']?.toString() ?? '-',
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
                                    color: isVerified ? Colors.green.shade50 : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isVerified ? Colors.green.shade200 : const Color(0xFFFCD34D)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isVerified) ...[
                                        const Icon(Icons.lock_rounded, size: 10, color: Color(0xFFB45309)),
                                        const SizedBox(width: 3),
                                      ],
                                      Text(
                                        isVerified ? 'Aktif' : 'Menunggu Verifikasi',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isVerified ? Colors.green.shade700 : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
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
                              _kosProfile?['kode_kost']?.toString() ?? '';
                          _guardedFeatureAction('Bagikan Kode Undangan', () {
                            _shareInvitationCode(context, code, kosName);
                          });
                        },
                        icon: Icon(isVerified ? Icons.copy_rounded : Icons.lock_outline_rounded, size: 16),
                        label: Text(isVerified ? 'Bagikan' : 'Terkunci'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isVerified ? const Color(0xFF1E40AF) : const Color(0xFF64748B),
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
                          isLocked: !isVerified,
                          onTap: () {
                            _guardedFeatureAction('Tingkat Okupansi & Kamar', () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RoomManagementScreen(
                                    kostId: resolvedKostId,
                                    kosName: kosName,
                                  ),
                                ),
                              ).then((_) => _fetchDashboardData());
                            });
                          },
                        ),
                        _buildMetricCard(
                          title: 'Kas Masuk Riil',
                          value: FormatUtils.compactRupiah(_summary.pemasukanKasRiil),
                          subtext: 'Buku kas & laba bersih',
                          icon: Icons.account_balance_wallet_rounded,
                          color: const Color(0xFF059669),
                          isLocked: !isVerified,
                          onTap: () {
                            _guardedFeatureAction('Buku Kas & Arus Kas', () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FinancialReportScreen(
                                    kostId: resolvedKostId,
                                    kosName: kosName,
                                    isJuragan: isJuragan,
                                  ),
                                ),
                              ).then((_) => _fetchDashboardData());
                            });
                          },
                        ),
                        _buildMetricCard(
                          title: 'Tunggakan Sewa',
                          value: FormatUtils.compactRupiah(_summary.totalTunggakan),
                          subtext:
                              '${_summary.tunggakanCount} tagihan belum bayar',
                          icon: Icons.warning_amber_rounded,
                          color: const Color(0xFFDC2626),
                          isLocked: !isVerified,
                          onTap: () {
                            _guardedFeatureAction('Tunggakan Sewa & Tagihan', () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => InvoiceManagementScreen(
                                    kostId: resolvedKostId,
                                    kosName: kosName,
                                  ),
                                ),
                              ).then((_) => _fetchDashboardData());
                            });
                          },
                        ),
                        _buildMetricCard(
                          title: 'Verifikasi Bayar',
                          value: '${_summary.pendingVerificationCount} Menunggu',
                          subtext: 'Perlu konfirmasi Anda',
                          icon: Icons.pending_actions_rounded,
                          color: const Color(0xFFD97706),
                          isLocked: !isVerified,
                          onTap: () {
                            _guardedFeatureAction('Verifikasi Pembayaran', () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => InvoiceManagementScreen(
                                    kostId: resolvedKostId,
                                    kosName: kosName,
                                  ),
                                ),
                              ).then((_) => _fetchDashboardData());
                            });
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
                        isLocked: !isVerified,
                        onTap: () {
                          _guardedFeatureAction('Kelola Kamar', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RoomManagementScreen(
                                  kostId: resolvedKostId,
                                  kosName: kosName,
                                ),
                              ),
                            ).then((_) => _fetchDashboardData());
                          });
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
                        isLocked: !isVerified,
                        onTap: () {
                          _guardedFeatureAction('Alokasi Penghuni', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TenantAllocationScreen(
                                  kostId: resolvedKostId,
                                  kosName: kosName,
                                ),
                              ),
                            ).then((_) => _fetchDashboardData());
                          });
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
                        color: const Color(0xFF0284C7),
                        title: 'Smart Billing',
                        subtitle: 'Tagihan & Pengingat WA',
                        isLocked: !isVerified,
                        onTap: () {
                          _guardedFeatureAction('Smart Billing', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InvoiceManagementScreen(
                                  kostId: resolvedKostId,
                                  kosName: kosName,
                                ),
                              ),
                            ).then((_) => _fetchDashboardData());
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.analytics_rounded,
                        color: const Color(0xFF059669),
                        title: 'Buku Kas & Arus Kas',
                        subtitle: 'Visualisasi Laba & Biaya',
                        isLocked: !isVerified,
                        onTap: () {
                          _guardedFeatureAction('Buku Kas & Arus Kas', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FinancialReportScreen(
                                  kostId: resolvedKostId,
                                  kosName: kosName,
                                  isJuragan: isJuragan,
                                ),
                              ),
                            ).then((_) => _fetchDashboardData());
                          });
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
                        icon: Icons.build_circle_rounded,
                        color: const Color(0xFFDC2626),
                        title: 'Helpdesk Keluhan',
                        subtitle: '${_summary.activeComplaintsCount} tiket aktif',
                        isLocked: !isVerified,
                        onTap: () {
                          _guardedFeatureAction('Helpdesk Keluhan', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ComplaintManagementScreen(
                                  kostId: resolvedKostId,
                                  kosName: kosName,
                                ),
                              ),
                            ).then((_) => _fetchDashboardData());
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.campaign_rounded,
                        color: const Color(0xFFD97706),
                        title: 'Poster Promosi AI',
                        subtitle: isJuragan ? 'Pemasaran & Radar H-30' : '⭐ Fitur Paket Juragan',
                        isLocked: !isVerified,
                        isPremium: true,
                        isJuragan: isJuragan,
                        onTap: () {
                          if (!isVerified) {
                            _guardedFeatureAction('Poster Promosi AI & Radar H-30', () {});
                          } else if (!isJuragan) {
                            _showPremiumUpgradeDialog(featureName: 'Poster Promosi AI & Radar H-30');
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RoomPosterGeneratorScreen(
                                  kostId: resolvedKostId,
                                  kosName: kosName,
                                ),
                              ),
                            ).then((_) => _fetchDashboardData());
                          }
                        },
                      ),
                    ),
                  ],
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
                            _guardedFeatureAction('Kelola Tagihan & Kas', () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => InvoiceManagementScreen(
                                    kostId: resolvedKostId,
                                    kosName: kosName,
                                  ),
                                ),
                              ).then((_) => _fetchDashboardData());
                            });
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
    bool isLocked = false,
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
            border: Border.all(color: isLocked ? const Color(0xFFFDE68A) : const Color(0xFFF1F5F9)),
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
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isLocked ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        if (isLocked) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.lock_rounded, size: 12, color: Color(0xFFD97706)),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isLocked
                          ? Colors.grey.shade100
                          : color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isLocked ? Icons.lock_outline_rounded : icon,
                      color: isLocked ? const Color(0xFF94A3B8) : color,
                      size: 16,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLocked ? 'Terkunci' : value,
                    style: TextStyle(
                      fontSize: isLocked ? 15 : 18,
                      fontWeight: FontWeight.bold,
                      color: isLocked ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLocked ? 'Perlu verifikasi kos' : subtext,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isLocked ? const Color(0xFFB45309) : color,
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
    bool isLocked = false,
    bool isPremium = false,
    bool isJuragan = false,
  }) {
    final showPremiumLock = isPremium && !isJuragan;

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
            border: Border.all(
              color: isLocked
                  ? const Color(0xFFFDE68A)
                  : (showPremiumLock ? const Color(0xFFBFDBFE) : const Color(0xFFF1F5F9)),
              width: showPremiumLock ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isLocked
                      ? const Color(0xFFFEF3C7)
                      : (showPremiumLock ? const Color(0xFFEFF6FF) : color.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isLocked
                      ? Icons.lock_rounded
                      : (showPremiumLock ? Icons.workspace_premium_rounded : icon),
                  color: isLocked
                      ? const Color(0xFFD97706)
                      : (showPremiumLock ? const Color(0xFF1D4ED8) : color),
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
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isLocked ? const Color(0xFF475569) : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (isLocked)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Terkunci',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          )
                        else if (showPremiumLock)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: const Text(
                              '⭐ Juragan',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLocked ? 'Verifikasi kos terlebih dahulu untuk akses' : subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isLocked
                            ? const Color(0xFFB45309)
                            : (showPremiumLock ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                        fontWeight: (isLocked || showPremiumLock) ? FontWeight.w500 : FontWeight.normal,
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
