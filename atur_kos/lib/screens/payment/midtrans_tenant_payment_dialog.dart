import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:atur_kos/screens/payment/public_receipt_verification_screen.dart';
import 'package:atur_kos/services/kos_service.dart';
import 'package:atur_kos/utils/format_utils.dart';

/// Modal Midtrans Snap Payment Gateway untuk Penghuni Kos (PRD v2.0.0 Modul 4)
/// Mensimulasikan pembayaran sewa kamar bulanan dengan alur sandbox resmi Midtrans:
/// - Real-time live ticking countdown timer (ticking tiap detik)
/// - QRIS (Semua E-Wallet & Bank) + Virtual Account Semua Bank
/// - Pembatalan transaksi aman dengan konfirmasi dialog
/// - Simulasi pelunasan langsung bermutasi ke Supabase:
///   1. Invoice status -> 'lunas'
///   2. settlement_time & qr_verification_code tersimpan
///   3. Otomatis masuk ke buku kas cash_ledgers (tipe: masuk, kategori: sewa_kamar)
/// - Menghasilkan Kuitansi Sah Digital Ber-QR Code Anti-Manipulasi (US-4.4)
class MidtransTenantPaymentDialog extends StatefulWidget {
  final String invoiceId;
  final String kostId;
  final String tenantId;
  final String kosName;
  final String roomNumber;
  final String roomType;
  final String tenantName;
  final String periode;
  final double nominal;
  final String? existingOrderId;
  final String? dueDate;
  final VoidCallback? onPaymentSuccess;

  const MidtransTenantPaymentDialog({
    super.key,
    required this.invoiceId,
    required this.kostId,
    required this.tenantId,
    required this.kosName,
    required this.roomNumber,
    required this.roomType,
    required this.tenantName,
    required this.periode,
    required this.nominal,
    this.existingOrderId,
    this.dueDate,
    this.onPaymentSuccess,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String invoiceId,
    required String kostId,
    required String tenantId,
    required String kosName,
    required String roomNumber,
    required String roomType,
    required String tenantName,
    required String periode,
    required double nominal,
    String? existingOrderId,
    String? dueDate,
    VoidCallback? onPaymentSuccess,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MidtransTenantPaymentDialog(
        invoiceId: invoiceId,
        kostId: kostId,
        tenantId: tenantId,
        kosName: kosName,
        roomNumber: roomNumber,
        roomType: roomType,
        tenantName: tenantName,
        periode: periode,
        nominal: nominal,
        existingOrderId: existingOrderId,
        dueDate: dueDate,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  /// Tampilkan Kuitansi Digital untuk tagihan yang sudah lunas sebelumnya
  static Future<void> showReceiptModal(
    BuildContext context, {
    required String orderId,
    required String midtransTrxId,
    required String kosName,
    required String roomNumber,
    required String roomType,
    required String tenantName,
    required String periode,
    required double nominal,
    required String paymentType,
    required String settlementTime,
    required String qrVerificationCode,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF16A34A),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'KUITANSI SAH PEMBAYARAN SEWA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Terverifikasi Otomatis via Midtrans Snap Webhook (US-4.4)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                _buildReceiptCardStatic(
                  orderId: orderId,
                  midtransTrxId: midtransTrxId,
                  kosName: kosName,
                  roomNumber: roomNumber,
                  roomType: roomType,
                  tenantName: tenantName,
                  periode: periode,
                  nominal: nominal,
                  paymentType: paymentType,
                  settlementTime: settlementTime,
                  qrVerificationCode: qrVerificationCode,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      PublicReceiptVerificationScreen.open(
                        context,
                        initialOrderId: orderId,
                        initialCode: qrVerificationCode,
                      );
                    },
                    icon: const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF0D9488)),
                    label: const Text(
                      'Buka di Layar Verifikasi Publik (Anti-Fraud)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF99F6E4)),
                      backgroundColor: const Color(0xFFF0FDFA),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final receiptText = '''
=== KUITANSI SAH PEMBAYARAN ATUR KOS ===
Status: LUNAS (TERVERIFIKASI OTOMATIS)
Nomor Order: $orderId
ID Transaksi Midtrans: $midtransTrxId
Properti Kos: $kosName
Kamar: Kamar $roomNumber ($roomType)
Nama Penghuni: $tenantName
Periode Sewa: $periode
Metode Pembayaran: $paymentType
Total Nominal: ${FormatUtils.formatRupiah(nominal.toInt())}
Waktu Pelunasan: $settlementTime
Kode Segel Digital: $qrVerificationCode
Verifikasi: https://aturkos.app/verify/invoice?id=$orderId&seal=$qrVerificationCode
========================================
Dokumen digital ini sah & anti-manipulasi (PRD US-4.4).
'''.trim();
                          Clipboard.setData(ClipboardData(text: receiptText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Teks kuitansi sah berhasil disalin ke clipboard!'),
                              backgroundColor: Color(0xFF059669),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Salin Teks Kuitansi', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D9488),
                          side: const BorderSide(color: Color(0xFF0D9488)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Tutup Kuitansi', style: TextStyle(fontWeight: FontWeight.bold)),
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

  static Widget _buildReceiptCardStatic({
    required String orderId,
    required String midtransTrxId,
    required String kosName,
    required String roomNumber,
    required String roomType,
    required String tenantName,
    required String periode,
    required double nominal,
    required String paymentType,
    required String settlementTime,
    required String qrVerificationCode,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildRow('Nomor Order / Invoice', orderId),
          const Divider(height: 14),
          _buildRow('ID Transaksi Midtrans', midtransTrxId),
          const Divider(height: 14),
          _buildRow('Properti Kos', kosName),
          const Divider(height: 14),
          _buildRow('Alokasi Kamar', 'Kamar $roomNumber ($roomType)'),
          const Divider(height: 14),
          _buildRow('Nama Penghuni', tenantName),
          const Divider(height: 14),
          _buildRow('Periode Sewa', periode),
          const Divider(height: 14),
          _buildRow('Metode Pembayaran', paymentType),
          const Divider(height: 14),
          _buildRow('Total Nominal Dibayar', FormatUtils.formatRupiah(nominal.toInt())),
          const Divider(height: 14),
          _buildRow('Waktu Pelunasan', settlementTime),
          const Divider(height: 14),
          _buildRow('Status', 'LUNAS (AUTO-SETTLEMENT)', isHighlight: true),
          const SizedBox(height: 14),
          // QR Code Verifikasi Anti-Manipulasi (Scannable Real QR Code)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user_rounded, color: Color(0xFF0D9488), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Segel Keaslian Digital (Scan QR)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Real QR Code Generator using qr_flutter
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: QrImageView(
                      data: '''
=== BUKTI PEMBAYARAN SAH ATUR KOS ===
Status: LUNAS (TERVERIFIKASI OTOMATIS)
Nomor Order: $orderId
ID Midtrans: $midtransTrxId
Properti: $kosName
Kamar: $roomNumber ($roomType)
Penghuni: $tenantName
Periode: $periode
Nominal: ${FormatUtils.formatRupiah(nominal.toInt())}
Metode: $paymentType
Waktu: $settlementTime
Segel Anti-Manipulasi: $qrVerificationCode
https://aturkos.app/verify/invoice?id=$orderId&seal=$qrVerificationCode
=====================================
'''.trim(),
                      version: QrVersions.auto,
                      size: 140.0,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      padding: const EdgeInsets.all(4),
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF0F172A),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                const Text(
                  'Arahkan kamera smartphone atau Google Lens ke QR code di atas untuk memverifikasi keaslian bukti pembayaran ini secara instan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tag_rounded, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          qrVerificationCode,
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
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

  static Widget _buildRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isHighlight ? const Color(0xFF059669) : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  @override
  State<MidtransTenantPaymentDialog> createState() => _MidtransTenantPaymentDialogState();
}

class _MidtransTenantPaymentDialogState extends State<MidtransTenantPaymentDialog> {
  late String _orderId;
  late String _midtransTrxId;
  String _selectedPaymentMethod = 'qris'; // 'qris', 'bca_va', 'mandiri_va', 'bni_va', 'bri_va', 'permata_va', 'cimb_va', 'other_va'
  bool _isProcessingSettlement = false;
  bool _isPaymentSettled = false;
  DateTime? _settlementTime;
  String? _qrVerificationCode;

  // Real-time live ticking countdown timer (23 jam 59 menit 59 detik)
  Timer? _countdownTimer;
  int _remainingSeconds = 86399; // 23:59:59

  @override
  void initState() {
    super.initState();
    if (widget.existingOrderId != null && widget.existingOrderId!.isNotEmpty) {
      _orderId = widget.existingOrderId!;
    } else {
      final randomSuffix = (1000 + Random().nextInt(9000)).toString();
      final dateStr = DateTime.now().toString().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 8);
      _orderId = 'ORDER-RENT-$dateStr-$randomSuffix';
    }
    _midtransTrxId = 'MTR-RENT-${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}';

    // Timer mundur real-time tiap detik
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String get _formattedCountdown {
    final hours = (_remainingSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((_remainingSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String get _vaNumber {
    switch (_selectedPaymentMethod) {
      case 'bca_va':
        return '7001281234567890';
      case 'mandiri_va':
        return '89382 10982341234';
      case 'bni_va':
        return '8808812345678901';
      case 'bri_va':
        return '7001281234567892';
      case 'permata_va':
        return '8528012345678903';
      case 'cimb_va':
        return '8059012345678904';
      case 'other_va':
        return '8528012345678903';
      default:
        return '7001281234567890';
    }
  }

  String get _paymentChannelDisplayName {
    switch (_selectedPaymentMethod) {
      case 'bca_va':
        return 'BCA Virtual Account';
      case 'mandiri_va':
        return 'Mandiri Bill Payment (E-Channel)';
      case 'bni_va':
        return 'BNI Virtual Account';
      case 'bri_va':
        return 'BRI Virtual Account (BRIVA)';
      case 'permata_va':
        return 'Permata Bank Virtual Account';
      case 'cimb_va':
        return 'CIMB Niaga Virtual Account';
      case 'other_va':
        return 'Bank Lainnya (ATM Bersama / Prima / Alto)';
      case 'qris':
      default:
        return 'QRIS (Semua E-Wallet & Mobile Banking)';
    }
  }

  /// Dialog konfirmasi pembatalan transaksi
  Future<void> _confirmCancelTransaction() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
            SizedBox(width: 10),
            Text('Batalkan Transaksi?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yakin ingin membatalkan transaksi pembayaran sewa kamar ${widget.roomNumber} di "${widget.kosName}"?',
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order ID: $_orderId', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    'Total Tagihan: ${FormatUtils.formatRupiah(widget.nominal.toInt())}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0F766E), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tagihan ini belum dibayarkan. Anda dapat memulai pembayaran kembali kapan saja sebelum tanggal jatuh tempo.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Lanjut Bayar', style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Ya, Batalkan Transaksi'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Navigator.pop(context, false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaksi $_orderId berhasil dibatalkan.'),
          backgroundColor: const Color(0xFF475569),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Simulasi pelunasan otomatis Midtrans Snap Sandbox
  Future<void> _simulateSettlementPayment() async {
    setState(() => _isProcessingSettlement = true);

    // Simulasi latensi jaringan Webhook Midtrans Snap Sandbox
    await Future.delayed(const Duration(milliseconds: 1400));

    final success = await KosService.settleTenantInvoicePayment(
      invoiceId: widget.invoiceId,
      kostId: widget.kostId,
      nominal: widget.nominal,
      orderId: _orderId,
      paymentType: _selectedPaymentMethod == 'qris' ? 'midtrans_qris' : 'midtrans_va',
      midtransTrxId: _midtransTrxId,
      nomorKamar: widget.roomNumber,
      periode: widget.periode,
    );

    if (!mounted) return;

    if (success) {
      final now = DateTime.now();
      final cleanOrder = _orderId.replaceAll('/', '-');
      final qrCode = 'ATURKOS-$cleanOrder-${now.millisecondsSinceEpoch.toString().substring(7)}';

      setState(() {
        _isProcessingSettlement = false;
        _isPaymentSettled = true;
        _settlementTime = now;
        _qrVerificationCode = qrCode;
      });

      widget.onPaymentSuccess?.call();
    } else {
      setState(() => _isProcessingSettlement = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memproses pelunasan di database Supabase. Coba lagi.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: _isPaymentSettled ? _buildReceiptView() : _buildSnapCheckoutView(),
      ),
    );
  }

  // ===========================================================================
  // 1. TAMPILAN CHECKOUT MIDTRANS SNAP
  // ===========================================================================
  Widget _buildSnapCheckoutView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Dialog: Logo & Branding Midtrans Snap
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_rounded, color: Color(0xFF38BDF8), size: 14),
                      SizedBox(width: 6),
                      Text(
                        'MIDTRANS SNAP',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text(
                    'Sandbox Simulator',
                    style: TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _confirmCancelTransaction,
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  tooltip: 'Tutup / Batalkan Transaksi',
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Live Countdown Timer Ticking Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Batas Waktu Bayar:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF78350F), fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formattedCountdown,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Ringkasan Tagihan Sewa
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCCFBF1)),
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
                          Text(
                            widget.kosName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kamar ${widget.roomNumber} (${widget.roomType}) • ${widget.tenantName}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF0F766E), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFBF1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.periode,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFCCFBF1)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Tagihan Sewa', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(
                            FormatUtils.formatRupiah(widget.nominal.toInt()),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Order ID', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(
                            _orderId,
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Pilihan Metode Pembayaran
            const Text(
              'Pilih Metode Pembayaran',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),

            // Tab / Pilihan: QRIS vs Virtual Account
            _buildPaymentMethodTile(
              id: 'qris',
              icon: Icons.qr_code_2_rounded,
              title: 'QRIS (Semua E-Wallet & Bank)',
              subtitle: 'GoPay, OVO, Dana, ShopeePay, BCA, Mandiri, BRI, BNI dll',
              badge: 'Populer & Instan',
              badgeColor: const Color(0xFF059669),
            ),
            const SizedBox(height: 8),

            _buildPaymentMethodTile(
              id: 'bca_va',
              icon: Icons.account_balance_rounded,
              title: 'BCA Virtual Account',
              subtitle: 'Verifikasi instan otomatis 24 jam',
            ),
            const SizedBox(height: 8),

            _buildPaymentMethodTile(
              id: 'mandiri_va',
              icon: Icons.account_balance_rounded,
              title: 'Mandiri Bill Payment (E-Channel)',
              subtitle: 'Livin by Mandiri & ATM Mandiri',
            ),
            const SizedBox(height: 8),

            _buildPaymentMethodTile(
              id: 'bni_va',
              icon: Icons.account_balance_rounded,
              title: 'BNI Virtual Account',
              subtitle: 'BNI Mobile Banking & ATM BNI',
            ),
            const SizedBox(height: 8),

            _buildPaymentMethodTile(
              id: 'bri_va',
              icon: Icons.account_balance_rounded,
              title: 'BRI Virtual Account (BRIVA)',
              subtitle: 'BRImo & ATM BRI',
            ),
            const SizedBox(height: 8),

            _buildPaymentMethodTile(
              id: 'permata_va',
              icon: Icons.account_balance_rounded,
              title: 'Permata Bank Virtual Account',
              subtitle: 'PermataMobile X & ATM Permata',
            ),
            const SizedBox(height: 8),

            _buildPaymentMethodTile(
              id: 'cimb_va',
              icon: Icons.account_balance_rounded,
              title: 'CIMB Niaga Virtual Account',
              subtitle: 'OCTO Mobile & OCTO Clicks',
            ),
            const SizedBox(height: 8),

            _buildPaymentMethodTile(
              id: 'other_va',
              icon: Icons.credit_card_rounded,
              title: 'Bank Lainnya (ATM Bersama / Prima)',
              subtitle: 'Transfer antar bank via jaringan ATM Bersama / Prima / Alto',
            ),

            const SizedBox(height: 16),

            // Detail Cara Bayar Sesuai Metode yang Dipilih
            if (_selectedPaymentMethod == 'qris')
              _buildQrisDetail()
            else
              _buildVirtualAccountDetail(),

            const SizedBox(height: 22),

            // Tombol Simulasi Pelunasan Midtrans Sandbox
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessingSettlement ? null : _simulateSettlementPayment,
                icon: _isProcessingSettlement
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.flash_on_rounded),
                label: Text(
                  _isProcessingSettlement
                      ? 'Menghubungi Simulator Midtrans...'
                      : 'Simulasikan Pembayaran Berhasil (Midtrans Sandbox)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Tombol Batalkan Transaksi
            Center(
              child: TextButton.icon(
                onPressed: _isProcessingSettlement ? null : _confirmCancelTransaction,
                icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFEF4444)),
                label: const Text(
                  'Batalkan Transaksi Ini',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // KOMPONEN METODE BAYAR TILE
  // ===========================================================================
  Widget _buildPaymentMethodTile({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
  }) {
    final isSelected = _selectedPaymentMethod == id;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDFA) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFCCFBF1) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF1E293B),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? const Color(0xFF059669)).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: badgeColor ?? const Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFCBD5E1),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DETAIL TAMPILAN QRIS
  // ===========================================================================
  Widget _buildQrisDetail() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pindai Kode QRIS',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'NMID: ID1020039281923',
                  style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF0369A1), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Simulasi QR Code QRIS Standar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 170,
                  height: 170,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFF0F172A), width: 2.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: QrImageView(
                      data: 'https://simulator.sandbox.midtrans.com/qris/pay?order_id=$_orderId&gross_amount=${widget.nominal.toInt()}',
                      version: QrVersions.auto,
                      size: 150.0,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      padding: EdgeInsets.zero,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF0F172A),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Merchant: ${widget.kosName}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nominal: ${FormatUtils.formatRupiah(widget.nominal.toInt())}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF0F766E), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 13, color: Color(0xFF64748B)),
              SizedBox(width: 4),
              Text(
                'Buka m-Banking atau E-Wallet apa saja > scan QR di atas',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DETAIL TAMPILAN VIRTUAL ACCOUNT
  // ===========================================================================
  Widget _buildVirtualAccountDetail() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nomor ${_paymentChannelDisplayName.split('(').first.trim()}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Auto-Detect',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Baris Nomor VA & Tombol Salin
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _vaNumber,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _vaNumber.replaceAll(' ', '')));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Nomor Virtual Account $_vaNumber disalin!'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF0D9488),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Salin', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Text(
            'Panduan Pembayaran:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          _buildInstructionStep('1', 'Buka aplikasi Mobile Banking atau kunjungi ATM terdekat.'),
          _buildInstructionStep('2', 'Pilih menu Transfer > Virtual Account / Pembayaran.'),
          _buildInstructionStep('3', 'Masukkan nomor Virtual Account di atas dan pastikan nominal tepat.'),
          _buildInstructionStep('4', 'Konfirmasi nama merchant "$widget.kosName" dan selesaikan transaksi.'),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(num, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. TAMPILAN KUITANSI SAH DIGITAL BER-QR CODE (SETTLEMENT RECEIPT)
  // ===========================================================================
  Widget _buildReceiptView() {
    final settlementStr = _settlementTime != null
        ? '${_settlementTime!.day} ${_getIndonesianMonth(_settlementTime!.month)} ${_settlementTime!.year}, ${_settlementTime!.hour.toString().padLeft(2, '0')}:${_settlementTime!.minute.toString().padLeft(2, '0')} WIB'
        : '-';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF16A34A),
                size: 40,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Pembayaran Berhasil Dikonfirmasi! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Midtrans Snap Webhook: status: "settlement" verified',
              style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),

            // Kartu Kuitansi Digital
            MidtransTenantPaymentDialog._buildReceiptCardStatic(
              orderId: _orderId,
              midtransTrxId: _midtransTrxId,
              kosName: widget.kosName,
              roomNumber: widget.roomNumber,
              roomType: widget.roomType,
              tenantName: widget.tenantName,
              periode: widget.periode,
              nominal: widget.nominal,
              paymentType: _paymentChannelDisplayName,
              settlementTime: settlementStr,
              qrVerificationCode: _qrVerificationCode ?? 'ATURKOS-$_orderId',
            ),

            const SizedBox(height: 14),

            // Notifikasi Otomasi Buku Kas
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF059669), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sesuai PRD US-6.1: Pembayaran ini telah otomatis dicatat sebagai kas masuk riil di buku kas pemilik kos.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF065F46)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Tutup & Kembali ke Dasbor', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context, true);
                  PublicReceiptVerificationScreen.open(
                    context,
                    initialOrderId: _orderId,
                    initialCode: _qrVerificationCode ?? 'ATURKOS-$_orderId',
                  );
                },
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Color(0xFF0D9488)),
                label: const Text(
                  'Uji Keabsahan di Layar Verifikasi Publik',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D9488),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF99F6E4)),
                  backgroundColor: const Color(0xFFF0FDFA),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getIndonesianMonth(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }
}
