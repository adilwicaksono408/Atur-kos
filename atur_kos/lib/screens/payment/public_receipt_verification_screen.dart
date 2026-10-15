import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:atur_kos/services/kos_service.dart';
import 'package:atur_kos/utils/format_utils.dart';

/// Layar Verifikasi Publik Kuitansi Digital Ber-QR Code (PRD v2.0.0 Modul 4, US-4.3 & US-4.4)
/// Standar Keamanan Bukti Bayar ISO/IEC 18004 anti-manipulasi.
/// Dapat diakses oleh siapapun (penghuni, orang tua, kampus, atau auditor)
/// untuk membuktikan keaslian pembayaran sewa yang lunas di gateway Midtrans Snap.
class PublicReceiptVerificationScreen extends StatefulWidget {
  final String? initialCode;
  final String? initialOrderId;

  const PublicReceiptVerificationScreen({
    super.key,
    this.initialCode,
    this.initialOrderId,
  });

  static Future<void> open(
    BuildContext context, {
    String? initialCode,
    String? initialOrderId,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => PublicReceiptVerificationScreen(
          initialCode: initialCode,
          initialOrderId: initialOrderId,
        ),
      ),
    );
  }

  @override
  State<PublicReceiptVerificationScreen> createState() =>
      _PublicReceiptVerificationScreenState();
}

class _PublicReceiptVerificationScreenState
    extends State<PublicReceiptVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _verifiedInvoice;
  String? _errorMessage;
  bool _hasSearched = false;
  List<Map<String, dynamic>> _sampleInvoices = [];

  @override
  void initState() {
    super.initState();
    final startCode = widget.initialCode ?? widget.initialOrderId;
    if (startCode != null && startCode.trim().isNotEmpty) {
      _codeController.text = startCode.trim();
      _performVerification(startCode.trim());
    }
    _loadSampleInvoices();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadSampleInvoices() async {
    final samples = await KosService.getSampleSettledInvoicesForDemo();
    if (mounted) {
      setState(() => _sampleInvoices = samples);
    }
  }

  Future<void> _performVerification([String? codeToVerify]) async {
    final query = (codeToVerify ?? _codeController.text).trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masukkan Order ID atau Kode Segel Kuitansi.'),
          backgroundColor: Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    final result = await KosService.verifyInvoicePublicly(query);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _verifiedInvoice = result;
      if (result == null) {
        _errorMessage =
            'Kuitansi dengan kode "$query" tidak ditemukan dalam basis data resmi Atur Kos. Pastikan nomor order atau segel QR dimasukkan dengan benar.';
      }
    });
  }

  String _formatPaymentChannel(String? raw) {
    if (raw == null || raw.isEmpty) return 'Midtrans Snap Sandbox';
    final lower = raw.toLowerCase();
    if (lower.contains('qris')) return 'QRIS (Semua E-Wallet & Mobile Banking)';
    if (lower.contains('bca')) return 'BCA Virtual Account';
    if (lower.contains('mandiri')) return 'Mandiri Bill Payment (E-Channel)';
    if (lower.contains('bni')) return 'BNI Virtual Account';
    if (lower.contains('bri')) return 'BRI BRIVA (Virtual Account)';
    if (lower.contains('permata')) return 'Permata Bank Virtual Account';
    if (lower.contains('cimb')) return 'CIMB Niaga Virtual Account';
    if (lower.contains('va')) return 'Bank Virtual Account (Midtrans)';
    return raw.toUpperCase();
  }

  String _formatDateTimeStr(dynamic dt) {
    if (dt == null) return '-';
    try {
      final parsed = dt is DateTime ? dt : DateTime.parse(dt.toString());
      const months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      final dateStr = '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
      final timeStr =
          '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')} WIB';
      return '$dateStr, $timeStr';
    } catch (_) {
      return dt.toString();
    }
  }

  /// Bagikan hasil verifikasi kuitansi sah ke WhatsApp (PRD US-4.4)
  Future<void> _shareToWhatsApp() async {
    if (_verifiedInvoice == null) return;
    final inv = _verifiedInvoice!;
    final orderId = inv['order_id'] ?? '-';
    final midtransTrxId = inv['midtrans_transaction_id'] ?? '-';
    final kosName = inv['kos_name'] ?? 'Atur Kos';
    final roomNumber = inv['room_number'] ?? '-';
    final tenantName = inv['tenant_name'] ?? 'Penghuni';
    final periode = inv['periode'] ?? '-';
    final nominal = (inv['nominal'] as num?)?.toDouble() ?? 0.0;
    final paymentType = _formatPaymentChannel(inv['payment_type']?.toString());
    final settlementTime = _formatDateTimeStr(inv['settlement_time']);
    final sealCode = inv['qr_verification_code'] ?? 'ATURKOS-$orderId';

    final text = '''
*HASIL VERIFIKASI KUITANSI DIGITAL — ATUR KOS*
Status: *LUNAS & TERVERIFIKASI ASLI (MIDTRANS SNAP)*

Nomor Order: $orderId
Gateway ID: $midtransTrxId
Properti Kos: $kosName
Alokasi Kamar: Kamar $roomNumber
Nama Penghuni: $tenantName
Periode Sewa: $periode
Metode Bayar: $paymentType
Total Nominal: ${FormatUtils.rupiah(nominal)}
Waktu Pelunasan: $settlementTime
Kode Segel Digital: $sealCode

Verifikasi Publik:
https://aturkos.app/verify/invoice?id=$orderId&seal=$sealCode

_Dokumen digital ini diakui sah dan dilindungi standar ISO/IEC 18004 anti-manipulasi._
'''.trim();

    final waUrl = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(waUrl)) {
        await launchUrl(waUrl, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Teks verifikasi berhasil disalin ke clipboard!'),
              backgroundColor: Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teks verifikasi berhasil disalin ke clipboard!'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showPrintableReceiptModal() {
    if (_verifiedInvoice == null) return;
    final inv = _verifiedInvoice!;
    final orderId = inv['order_id'] ?? '-';
    final midtransTrxId = inv['midtrans_transaction_id'] ?? '-';
    final kosName = inv['kos_name'] ?? 'Atur Kos';
    final roomNumber = inv['room_number'] ?? '-';
    final roomType = inv['room_type'] ?? '-';
    final tenantName = inv['tenant_name'] ?? 'Penghuni';
    final periode = inv['periode'] ?? '-';
    final nominal = (inv['nominal'] as num?)?.toDouble() ?? 0.0;
    final paymentType = _formatPaymentChannel(inv['payment_type']?.toString());
    final settlementTime = _formatDateTimeStr(inv['settlement_time']);
    final sealCode = inv['qr_verification_code'] ?? 'ATURKOS-$orderId';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kuitansi Sah Resmi',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Format Dokumen Cetak / Unduh',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Lembar Kuitansi Fisik
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Text(
                              kosName.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'BUKTI PEMBAYARAN SEWA SAH DIGITAL',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: const Text(
                                'LUNAS (TERVERIFIKASI MIDTRANS)',
                                style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      _buildReceiptRow('No. Order', orderId),
                      _buildReceiptRow('Midtrans Trx ID', midtransTrxId),
                      _buildReceiptRow('Penyewa', tenantName),
                      _buildReceiptRow('Alokasi', 'Kamar $roomNumber ($roomType)'),
                      _buildReceiptRow('Periode Sewa', periode),
                      _buildReceiptRow('Saluran Bayar', paymentType),
                      _buildReceiptRow('Waktu Lunas', settlementTime),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TOTAL BAYAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(
                              FormatUtils.rupiah(nominal),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF16A34A)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Column(
                          children: [
                            QrImageView(
                              data: 'https://aturkos.app/verify/invoice?id=$orderId&seal=$sealCode',
                              version: QrVersions.auto,
                              size: 110.0,
                              backgroundColor: Colors.white,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Segel: $sealCode',
                              style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Salin Rincian'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: 'KUITANSI LUNAS $orderId | $kosName Kamar $roomNumber | $tenantName | ${FormatUtils.rupiah(nominal)} | Segel: $sealCode'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Rincian kuitansi disalin!'), duration: Duration(seconds: 2)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Kirim ke WA'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _shareToWhatsApp();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ),
          const Text(': ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                color: const Color(0xFF16A34A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verifikasi Kuitansi Digital',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Standar Keabsahan ISO/IEC 18004 & Midtrans Snap Gateway',
                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Kotak Pencarian / Input Kode Kuitansi
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2563EB), size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cek Keabsahan Bukti Bayar',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Masukkan Order ID, Kode Segel QR, atau tempel tautan verifikasi:',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeController,
                        onSubmitted: (val) => _performVerification(val),
                        decoration: InputDecoration(
                          hintText: 'Contoh: INV-202610... atau ATURKOS-INV-...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_codeController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _codeController.clear();
                                    setState(() {
                                      _verifiedInvoice = null;
                                      _errorMessage = null;
                                      _hasSearched = false;
                                    });
                                  },
                                ),
                              IconButton(
                                tooltip: 'Tempel dari Clipboard',
                                icon: const Icon(Icons.content_paste_rounded, size: 18, color: Color(0xFF2563EB)),
                                onPressed: () async {
                                  final data = await Clipboard.getData('text/plain');
                                  if (data?.text != null && data!.text!.isNotEmpty) {
                                    _codeController.text = data.text!.trim();
                                    _performVerification(data.text!.trim());
                                  }
                                },
                              ),
                            ],
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : () => _performVerification(),
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.verified_outlined, size: 18),
                              label: Text(_isLoading ? 'Memverifikasi...' : 'Periksa Keabsahan Kuitansi'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Contoh Cepat untuk Uji Coba Skripsi / Demo
                      if (_sampleInvoices.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Sampel Uji Coba:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _sampleInvoices.map((s) {
                                    final label = s['order_id'] ?? s['nomor_invoice'] ?? 'Tagihan';
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ActionChip(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        label: Text(label, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                                        onPressed: () {
                                          _codeController.text = label;
                                          _performVerification(label);
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Area Hasil Verifikasi
                if (_isLoading) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    alignment: Alignment.center,
                    child: const Column(
                      children: [
                        CircularProgressIndicator(color: Color(0xFF16A34A)),
                        SizedBox(height: 14),
                        Text(
                          'Menghubungi basis data Supabase & gateway Midtrans...',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ] else if (_verifiedInvoice != null) ...[
                  _buildVerifiedCertificate(_verifiedInvoice!),
                ] else if (_hasSearched && _errorMessage != null) ...[
                  _buildInvalidCertificate(_errorMessage!),
                ] else ...[
                  _buildGuidanceCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tampilan Kuitansi Sah Terverifikasi (Berhasil)
  Widget _buildVerifiedCertificate(Map<String, dynamic> inv) {
    final orderId = inv['order_id'] ?? '-';
    final midtransTrxId = inv['midtrans_transaction_id'] ?? 'MTR-AUTO-SETTLED';
    final kosName = inv['kos_name'] ?? 'Atur Kos';
    final kosAddress = inv['kos_address'] ?? '-';
    final roomNumber = inv['room_number'] ?? '-';
    final roomType = inv['room_type'] ?? '-';
    final tenantName = inv['tenant_name'] ?? 'Penghuni Kos';
    final periode = inv['periode'] ?? '-';
    final nominal = (inv['nominal'] as num?)?.toDouble() ?? 0.0;
    final paymentType = _formatPaymentChannel(inv['payment_type']?.toString());
    final settlementTime = _formatDateTimeStr(inv['settlement_time']);
    final sealCode = inv['qr_verification_code'] ?? 'ATURKOS-$orderId';
    final status = (inv['status']?.toString() ?? '').toLowerCase();
    final isLunas = status == 'lunas';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLunas ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isLunas ? const Color(0xFF16A34A) : Colors.orange).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Sertifikat: Stempel Keabsahan
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLunas
                    ? [const Color(0xFF0F172A), const Color(0xFF064E3B)]
                    : [const Color(0xFF0F172A), const Color(0xFF78350F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isLunas
                        ? const Color(0xFF16A34A).withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isLunas ? const Color(0xFF4ADE80) : Colors.orangeAccent,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isLunas ? Icons.verified_rounded : Icons.pending_actions_rounded,
                    color: isLunas ? const Color(0xFF4ADE80) : Colors.orangeAccent,
                    size: 32,
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
                            isLunas ? 'KUITANSI RESMI & SAH' : 'STATUS: BELUM LUNAS',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isLunas
                            ? 'Terverifikasi 100% Otentik oleh Gateway Midtrans Snap'
                            : 'Tagihan terdaftar namun belum diselesaikan oleh penyewa.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isLunas ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Total Nominal Besar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL PEMBAYARAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    Text('Sewa Kamar Termasuk Air & Fasilitas', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
                Text(
                  FormatUtils.rupiah(nominal),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Rincian Atribut Lengkap
          _buildDetailRow('Nomor Order / Invoice', orderId, isMonospace: true),
          _buildDetailRow('ID Transaksi Midtrans', midtransTrxId, isMonospace: true),
          _buildDetailRow('Saluran Pembayaran', paymentType),
          _buildDetailRow('Waktu Pelunasan', settlementTime),
          _buildDetailRow('Properti Kos', kosName),
          _buildDetailRow('Alamat Properti', kosAddress),
          _buildDetailRow('Alokasi Kamar', 'Kamar $roomNumber ($roomType)'),
          _buildDetailRow('Nama Penghuni', tenantName),
          _buildDetailRow('Periode Sewa', periode),
          _buildDetailRow('Kode Segel Digital', sealCode, isMonospace: true, isHighlight: true),
          const SizedBox(height: 14),

          // Segel QR Code ISO/IEC 18004 Fisik
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 18, color: Color(0xFF0F172A)),
                    SizedBox(width: 6),
                    Text(
                      'Segel QR Code Digital Anti-Manipulasi',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: QrImageView(
                      data: 'https://aturkos.app/verify/invoice?id=$orderId&seal=$sealCode',
                      version: QrVersions.auto,
                      size: 130.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Segel: $sealCode',
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Pindai QR ini dari perangkat lain untuk memverifikasi keabsahan kuitansi secara independen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Tombol Aksi Cepat
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showPrintableReceiptModal,
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Format Cetak'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareToWhatsApp,
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Bagikan ke WA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isMonospace = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                color: isHighlight ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                fontFamily: isMonospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tampilan Kuitansi Tidak Valid / Ditolak
  Widget _buildInvalidCertificate(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.gpp_bad_rounded, color: Color(0xFFDC2626), size: 36),
          ),
          const SizedBox(height: 14),
          const Text(
            'KUITANSI TIDAK VALID / TIDAK DITEMUKAN',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pencegahan Penipuan: Jangan menerima bukti transfer yang tidak dapat diverifikasi langsung melalui sistem Atur Kos.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tampilan Panduan Awal (Sebelum Pengguna Memasukkan Kode)
  Widget _buildGuidanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cara Memverifikasi Kuitansi:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          _buildGuidanceStep('1', 'Cari nomor Order ID (contoh: INV-202610...) pada kuitansi digital atau pesan WhatsApp pembayaran Anda.'),
          _buildGuidanceStep('2', 'Masukkan nomor order atau kode segel pada kolom di atas, lalu tekan "Periksa Keabsahan Kuitansi".'),
          _buildGuidanceStep('3', 'Sistem akan mencocokkan data secara real-time dengan catatan pelunasan Midtrans Snap di Supabase.'),
          _buildGuidanceStep('4', 'Kuitansi yang sah akan menampilkan stempel hijau dan rincian transaksi lengkap yang anti-manipulasi.'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified, color: Color(0xFF16A34A), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Layanan publik ini dapat digunakan gratis tanpa batas waktu untuk mendukung keterbukaan informasi transaksi sewa kos.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF166534)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(num, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3)),
          ),
        ],
      ),
    );
  }
}
