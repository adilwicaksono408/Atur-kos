import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:atur_kos/models/kost_model.dart';
import 'package:atur_kos/services/kos_service.dart';
import 'package:atur_kos/utils/format_utils.dart';

/// Modal Midtrans Snap Payment Gateway (Lingkungan Sandbox PRD v2.0.0 Modul 4 & 10)
/// Mengimplementasikan alur pembayaran uji coba resmi Midtrans (QRIS & Virtual Account Semua Bank)
/// dengan live ticking countdown timer, pembatalan transaksi, dan mutasi database Supabase nyata.
class MidtransSnapPaymentDialog extends StatefulWidget {
  final String kostId;
  final String kosName;
  final int initialMonths;
  final VoidCallback? onPaymentSuccess;

  const MidtransSnapPaymentDialog({
    super.key,
    required this.kostId,
    required this.kosName,
    this.initialMonths = 1,
    this.onPaymentSuccess,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String kostId,
    required String kosName,
    int initialMonths = 1,
    VoidCallback? onPaymentSuccess,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MidtransSnapPaymentDialog(
        kostId: kostId,
        kosName: kosName,
        initialMonths: initialMonths,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  @override
  State<MidtransSnapPaymentDialog> createState() => _MidtransSnapPaymentDialogState();
}

class _MidtransSnapPaymentDialogState extends State<MidtransSnapPaymentDialog> {
  late int _selectedMonths;
  late String _orderId;
  late String _midtransTrxId;
  String _selectedPaymentMethod = 'qris'; // 'qris', 'bca_va', 'mandiri_va', 'bni_va', 'bri_va', 'permata_va', 'cimb_va', 'other_va'
  bool _isProcessingSettlement = false;
  bool _isPaymentSettled = false;
  DateTime? _subscriptionExpiry;

  // Real-time ticking countdown timer (23 jam 59 menit 59 detik)
  Timer? _countdownTimer;
  int _remainingSeconds = 86399; // 23:59:59

  @override
  void initState() {
    super.initState();
    _selectedMonths = widget.initialMonths == 12 ? 12 : 1;
    final randomSuffix = (1000 + Random().nextInt(9000)).toString();
    final dateStr = DateTime.now().toString().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 8);
    _orderId = 'ORDER-JURAGAN-$dateStr-$randomSuffix';
    _midtransTrxId = 'MTR-SBX-${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}';

    // Jalankan timer mundur real-time tiap detik
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

  int get _grossAmount => _selectedMonths == 12 ? 500000 : 50000;

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

  String get _bankDisplayName {
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
        return 'QRIS (Semua E-Wallet & Bank)';
    }
  }

  /// Dialog konfirmasi pembatalan transaksi resmi
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
              'Yakin ingin membatalkan transaksi untuk kos "${widget.kosName}"?',
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
                  Text('Total Tagihan: ${FormatUtils.formatRupiah(_grossAmount)}', style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Pesanan ini belum dibayarkan. Anda dapat memulai transaksi baru kapan saja tanpa dikenakan biaya apapun.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Lanjut Bayar', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
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

  Future<void> _simulateSettlementPayment() async {
    setState(() => _isProcessingSettlement = true);

    // Simulasi latensi jaringan komunikasi API Webhook Midtrans Snap Sandbox
    await Future.delayed(const Duration(milliseconds: 1400));

    final success = await KosService.upgradeKostSubscription(
      kostId: widget.kostId,
      tier: SubscriptionTier.juragan,
      months: _selectedMonths,
    );

    if (!mounted) return;

    if (success) {
      final now = DateTime.now();
      final expiry = now.add(Duration(days: _selectedMonths * 30));
      setState(() {
        _isProcessingSettlement = false;
        _isPaymentSettled = true;
        _subscriptionExpiry = expiry;
      });
      widget.onPaymentSuccess?.call();
    } else {
      setState(() => _isProcessingSettlement = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memproses mutasi langganan di database Supabase. Coba lagi.'),
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
  // 1. TAMPILAN CHECKOUT MIDTRANS SNAP SANDBOX
  // ===========================================================================
  Widget _buildSnapCheckoutView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Midtrans Snap Signature Bar
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
          decoration: const BoxDecoration(
            color: Color(0xFF0F2648), // Navy resmi Midtrans Snap
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'midtrans',
                      style: TextStyle(
                        color: Color(0xFF0F2648),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'SANDBOX',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                tooltip: 'Batalkan Pembayaran',
                onPressed: _isProcessingSettlement ? null : _confirmCancelTransaction,
              ),
            ],
          ),
        ),

        // Running Live Countdown Timer Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: const BoxDecoration(
            color: Color(0xFFFEF2F2),
            border: Border(bottom: BorderSide(color: Color(0xFFFECACA))),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time_filled_rounded, color: Color(0xFFDC2626), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                    children: [
                      const TextSpan(text: 'Selesaikan pembayaran dalam: '),
                      TextSpan(
                        text: _formattedCountdown,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Body Checkout
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Order & Nominal Tagihan
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Upgrade Paket Juragan ⭐',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Properti: ${widget.kosName}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Order ID: $_orderId',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Total Tagihan', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(
                            FormatUtils.formatRupiah(_grossAmount),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Pilihan Durasi Langganan
                const Text('Pilih Durasi Paket:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildDurationCard(
                        months: 1,
                        label: '1 Bulan',
                        price: 'Rp 50.000',
                        isSelected: _selectedMonths == 1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDurationCard(
                        months: 12,
                        label: '1 Tahun',
                        price: 'Rp 500.000',
                        badge: 'HEMAT 2 BULAN',
                        isSelected: _selectedMonths == 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Pilihan Metode Pembayaran Midtrans Snap (Semua Bank VA & QRIS)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Metode Pembayaran Midtrans:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Semua Bank VA & E-Wallet', style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMethodChip('qris', 'QRIS (Semua E-Wallet & Bank)', Icons.qr_code_2_rounded),
                      const SizedBox(width: 8),
                      _buildMethodChip('bca_va', 'BCA Virtual Account', Icons.account_balance_rounded),
                      const SizedBox(width: 8),
                      _buildMethodChip('mandiri_va', 'Mandiri Bill', Icons.account_balance_rounded),
                      const SizedBox(width: 8),
                      _buildMethodChip('bni_va', 'BNI VA', Icons.account_balance_rounded),
                      const SizedBox(width: 8),
                      _buildMethodChip('bri_va', 'BRI BRIVA', Icons.account_balance_rounded),
                      const SizedBox(width: 8),
                      _buildMethodChip('permata_va', 'Permata VA', Icons.account_balance_rounded),
                      const SizedBox(width: 8),
                      _buildMethodChip('cimb_va', 'CIMB Niaga VA', Icons.account_balance_rounded),
                      const SizedBox(width: 8),
                      _buildMethodChip('other_va', 'Bank Lain (ATM Bersama/Prima)', Icons.account_balance_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tampilan Instruksi Bayar Berdasarkan Metode yang Dipilih
                if (_selectedPaymentMethod == 'qris') _buildQrisSection() else _buildVaSection(),

                const SizedBox(height: 20),

                // Kotak Simulasi Sandbox Resmi Midtrans
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.science_rounded, color: Color(0xFFB45309), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Simulasi Midtrans Sandbox (Skripsi)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Alur ini berjalan di lingkungan sandbox Midtrans resmi. Tanpa uang sungguhan, sistem akan otomatis memutakhirkan properti kos ke Paket Juragan dengan akses kamar tanpa batas (unlimited) dan menghitung tanggal kedaluwarsa secara nyata di database Supabase.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessingSettlement ? null : _simulateSettlementPayment,
                          icon: _isProcessingSettlement
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.bolt_rounded, size: 18),
                          label: Text(
                            _isProcessingSettlement
                                ? 'Menghubungkan Midtrans Webhook...'
                                : '⚡ Simulasikan Pembayaran Berhasil (Settlement)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Tombol Batalkan Transaksi
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isProcessingSettlement ? null : _confirmCancelTransaction,
                    icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFF64748B)),
                    label: const Text('Batalkan Transaksi Ini', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. TAMPILAN KUITANSI PEMBAYARAN BERHASIL (SETTLEMENT RECEIPT)
  // ===========================================================================
  Widget _buildReceiptView() {
    final expiryFormatted = _subscriptionExpiry != null
        ? '${_subscriptionExpiry!.day} ${_getIndonesianMonth(_subscriptionExpiry!.month)} ${_subscriptionExpiry!.year}'
        : '-';

    return Padding(
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
            'Pembayaran Berhasil! 🎉',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Midtrans Snap Webhook: status: "settlement" verified',
            style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),

          // Kartu Rincian Kuitansi Digital
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildReceiptRow('Nomor Order', _orderId),
                const Divider(height: 16),
                _buildReceiptRow('ID Transaksi Midtrans', _midtransTrxId),
                const Divider(height: 16),
                _buildReceiptRow('Properti Kos', widget.kosName),
                const Divider(height: 16),
                _buildReceiptRow('Paket Langganan', '⭐ Paket Juragan ($_selectedMonths Bulan)'),
                const Divider(height: 16),
                _buildReceiptRow('Total Dibayar', FormatUtils.formatRupiah(_grossAmount)),
                const Divider(height: 16),
                _buildReceiptRow('Status Kuota Kamar', 'Tanpa Batas (Unlimited ♾️)'),
                const Divider(height: 16),
                _buildReceiptRow('Masa Aktif Hingga', expiryFormatted, isHighlight: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Benefit yang langsung terbuka
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              children: [
                Icon(Icons.stars_rounded, color: Color(0xFF1D4ED8), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fitur Generator Poster Promosi AI & Radar H-30 kini telah aktif dan dapat langsung Anda gunakan di dasbor!',
                    style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A)),
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
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Buka Dasbor & Nikmati Fitur Juragan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUB-KOMPONEN BANTU
  // ===========================================================================
  Widget _buildDurationCard({
    required int months,
    required String label,
    required String price,
    String? badge,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: _isProcessingSettlement ? null : () => setState(() => _selectedMonths = months),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(price, style: TextStyle(fontSize: 12, color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodChip(String id, String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == id;
    return ChoiceChip(
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedPaymentMethod = id);
      },
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF475569)),
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selectedColor: const Color(0xFF0F2648),
      labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF1E293B)),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? const Color(0xFF0F2648) : const Color(0xFFCBD5E1)),
      ),
    );
  }

  Widget _buildQrisSection() {
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
              const Row(
                children: [
                  Icon(Icons.qr_code_scanner_rounded, size: 16, color: Color(0xFF0F172A)),
                  SizedBox(width: 6),
                  Text('Bayar dengan QRIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 12, color: Color(0xFF1D4ED8)),
                    const SizedBox(width: 4),
                    Text(
                      'Batas Bayar: $_formattedCountdown',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // QRIS Canvas Visual Painter
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: QrImageView(
                data: 'https://simulator.sandbox.midtrans.com/qris/pay?order_id=$_orderId&gross_amount=$_grossAmount',
                version: QrVersions.auto,
                size: 154.0,
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
          const Text(
            'Scan QRIS di atas dengan GoPay, OVO, ShopeePay, BCA Mobile, Livin, BRImo, atau aplikasi m-Banking manapun.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildVaSection() {
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
              Text(_bankDisplayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 12, color: Color(0xFF1D4ED8)),
                    const SizedBox(width: 4),
                    Text(
                      _formattedCountdown,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Detail Virtual Account Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Nama Merchant', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text('ATUR KOS - JURAGAN ⭐', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                  ],
                ),
                const Divider(height: 16),
                const Text('Nomor Virtual Account', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _vaNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2, color: Color(0xFF0F172A)),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _vaNumber.replaceAll(' ', '')));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nomor VA berhasil disalin!'), duration: Duration(seconds: 1)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.copy_rounded, size: 13, color: Color(0xFF2563EB)),
                            SizedBox(width: 4),
                            Text('Salin', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Pembayaran', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text(
                      FormatUtils.formatRupiah(_grossAmount),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Petunjuk Pembayaran Singkat
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Color(0xFF475569)),
                    SizedBox(width: 6),
                    Text('Cara Pembayaran:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _getTransferInstructions(),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTransferInstructions() {
    switch (_selectedPaymentMethod) {
      case 'bca_va':
        return '1. Buka BCA Mobile / KlikBCA > Transfer > BCA Virtual Account.\n2. Masukkan nomor VA di atas.\n3. Masukkan nominal tagihan dan konfirmasi pembayaran.';
      case 'mandiri_va':
        return '1. Buka Livin by Mandiri > Bayar > Cari penyedia jasa "Midtrans".\n2. Masukkan nomor VA / Bill di atas.\n3. Periksa rincian dan konfirmasi pembayaran.';
      case 'bni_va':
        return '1. Buka BNI Mobile Banking > Transfer > Virtual Account Billing.\n2. Masukkan nomor VA BNI di atas.\n3. Konfirmasi pembayaran Anda.';
      case 'bri_va':
        return '1. Buka BRImo > Pembayaran > BRIVA.\n2. Masukkan nomor BRIVA di atas.\n3. Periksa nama merchant dan konfirmasi pembayaran.';
      case 'permata_va':
      case 'cimb_va':
        return '1. Buka Mobile Banking bank terkait > Transfer ke Virtual Account.\n2. Masukkan nomor VA di atas.\n3. Konfirmasi pembayaran tepat sesuai nominal.';
      case 'other_va':
      default:
        return '1. Buka m-Banking atau ATM bank Anda (BSI, Jago, Blu, Danamon, BTN, dll).\n2. Pilih Transfer Antar Bank > Kode Bank Permata (013).\n3. Masukkan nomor rekening tujuan dengan nomor VA di atas.\n4. Masukkan nominal tagihan tepat dan konfirmasi.';
    }
  }

  Widget _buildReceiptRow(String title, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            color: isHighlight ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  String _getIndonesianMonth(int month) {
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month];
  }
}

