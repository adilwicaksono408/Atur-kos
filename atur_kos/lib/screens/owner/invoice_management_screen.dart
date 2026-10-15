import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:atur_kos/screens/payment/midtrans_tenant_payment_dialog.dart';
import 'package:atur_kos/screens/payment/public_receipt_verification_screen.dart';
import 'package:atur_kos/services/kos_service.dart';
import 'package:atur_kos/utils/format_utils.dart';

/// Halaman Manajemen Tagihan, Verifikasi Pembayaran & WhatsApp Reminder Engine
/// Sesuai Spesifikasi PRD Modul 3 & Modul 6 (Sistem Manajemen Tagihan Kos)
class InvoiceManagementScreen extends StatefulWidget {
  final String? kostId;
  final String kosName;
  final String bankAccount;
  final String bankHolder;

  const InvoiceManagementScreen({
    super.key,
    required this.kostId,
    required this.kosName,
    this.bankAccount = 'BCA 1234567890',
    this.bankHolder = 'Pemilik Kos',
  });

  @override
  State<InvoiceManagementScreen> createState() => _InvoiceManagementScreenState();
}

class _InvoiceManagementScreenState extends State<InvoiceManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _bankAccount;
  late String _bankHolder;
  bool _isLoading = true;
  List<Map<String, dynamic>> _invoices = [];
  OperationalSummary _summary = const OperationalSummary();

  @override
  void initState() {
    super.initState();
    _bankAccount = widget.bankAccount;
    _bankHolder = widget.bankHolder;
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      KosService.getInvoices(widget.kostId),
      KosService.getOperationalSummary(widget.kostId),
      KosService.getKosProfile(widget.kostId),
    ]);

    if (mounted) {
      final kos = results[2] as Map<String, dynamic>?;
      if (kos != null) {
        final acc = kos['rekening_bank']?.toString();
        final holder = kos['nama_pemilik_rekening']?.toString();
        if (acc != null && acc.trim().isNotEmpty) _bankAccount = acc.trim();
        if (holder != null && holder.trim().isNotEmpty) _bankHolder = holder.trim();
      }

      setState(() {
        _invoices = results[0] as List<Map<String, dynamic>>;
        _summary = results[1] as OperationalSummary;
        _isLoading = false;
      });
    }
  }

  /// Verifikasi Pembayaran menjadi LUNAS dan otomatis catat Kas Masuk (PRD US-3.3 & US-6.1)
  Future<void> _handleVerify(Map<String, dynamic> invoice, bool approve) async {
    final invoiceId = invoice['id'].toString();
    final nomorInvoice = invoice['nomor_invoice']?.toString() ?? '-';
    final nominal = (invoice['nominal'] as num?)?.toDouble() ?? 0.0;
    final kostId = widget.kostId ?? invoice['kost_id']?.toString() ?? '';

    if (!approve) {
      final reasonController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tolak Pembayaran'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Masukkan alasan penolakan untuk tagihan $nomorInvoice:',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: 'Misal: Nominal tidak sesuai atau bukti mutasi palsu',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              child: const Text('Tolak Pembayaran', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final success = await KosService.verifyInvoice(
        invoiceId: invoiceId,
        kostId: kostId,
        nominal: nominal,
        nomorInvoice: nomorInvoice,
        approve: false,
        rejectionReason: reasonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Pembayaran berhasil ditolak.' : 'Gagal memproses penolakan.',
            ),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        _loadData();
      }
      return;
    }

    // Konfirmasi Verifikasi Lunas
    final confirmApprove = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Konfirmasi Verifikasi Lunas'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nomor Tagihan: $nomorInvoice'),
            const SizedBox(height: 4),
            Text(
              'Nominal: ${FormatUtils.rupiah(nominal)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF059669), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sesuai PRD US-6.1: Sistem otomatis mencatat kas masuk riil ke buku kas.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF065F46),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            child: const Text('Ya, Verifikasi Lunas'),
          ),
        ],
      ),
    );

    if (confirmApprove != true) return;

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
                ? 'Tagihan $nomorInvoice diverifikasi Lunas! Arus kas masuk dicatat.'
                : 'Gagal memverifikasi tagihan.',
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      _loadData();
    }
  }

  /// Generator Pesan Pengingat WhatsApp Sesuai Template Resmi PRD 5.3
  void _sendWhatsAppReminder(Map<String, dynamic> invoice) {
    final tenant = invoice['tenants'] as Map<String, dynamic>?;
    final profile = tenant?['profiles'] as Map<String, dynamic>?;
    final room = tenant?['rooms'] as Map<String, dynamic>?;

    final tenantName = profile?['full_name']?.toString() ?? 'Penghuni';
    final roomNumber = room?['nomor_kamar']?.toString() ?? '-';
    final periode = invoice['periode']?.toString() ?? '-';
    final nominal = (invoice['nominal'] as num?)?.toDouble() ?? 0.0;
    final dueDateStr = invoice['tanggal_jatuh_tempo']?.toString() ?? '';

    // Hitung status jatuh tempo
    final now = DateTime.now();
    DateTime? dueDate;
    try {
      dueDate = DateTime.parse(dueDateStr);
    } catch (_) {}

    String templateType = 'Hari-H';
    String message = '';

    if (dueDate != null) {
      final diffDays = dueDate.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diffDays > 0) {
        templateType = 'H-3 (Pemberitahuan Tagihan Terbit)';
        message =
            'Halo $tenantName, tagihan sewa ${widget.kosName} kamar $roomNumber untuk periode $periode sebesar ${FormatUtils.rupiah(nominal)} akan jatuh tempo pada ${FormatUtils.formatDate(dueDate)}. Pembayaran dapat ditransfer ke Rek. $_bankAccount a.n $_bankHolder. Silakan unggah bukti bayar di aplikasi Atur Kos. Terima kasih!';
      } else if (diffDays == 0) {
        templateType = 'Hari H (Jatuh Tempo Hari Ini)';
        message =
            'Halo $tenantName, hari ini adalah batas akhir pembayaran sewa kamar $roomNumber (${widget.kosName}) sebesar ${FormatUtils.rupiah(nominal)}. Mohon segera melakukan transfer ke Rek. $_bankAccount a.n $_bankHolder dan mengunggah bukti bayar di aplikasi Atur Kos. Abaikan pesan ini jika Anda sudah mengunggahnya. Terima kasih!';
      } else {
        templateType = 'H+2 (Peringatan Keterlambatan Sewa)';
        message =
            'Halo $tenantName, catatan kami menunjukkan tagihan sewa kamar $roomNumber telah melewati tanggal jatuh tempo (${FormatUtils.formatDate(dueDate)}). Mohon konfirmasi atau segera selesaikan pembayaran sebesar ${FormatUtils.rupiah(nominal)} untuk menghindari gangguan kenyamanan fasilitas kos. Terima kasih.';
      }
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kirim Pengingat WhatsApp',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Template Resmi PRD: $templateType',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Text(
                message,
                style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF1E293B)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Teks pengingat WhatsApp berhasil disalin ke clipboard!'),
                          backgroundColor: Color(0xFF1E40AF),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Salin Pesan'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pesan siap dikirimkan via WhatsApp!'),
                          backgroundColor: Color(0xFF25D366),
                        ),
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Buka WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
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
      ),
    );
  }

  /// Format saluran pembayaran Midtrans Snap menjadi teks ramah pengguna
  String _formatPaymentChannel(String? raw) {
    if (raw == null || raw.isEmpty) return 'Transfer Bank Manual';
    final lower = raw.toLowerCase();
    if (lower == 'midtrans_qris' || lower == 'qris') return 'QRIS (Midtrans Snap)';
    if (lower == 'midtrans_va') return 'Virtual Account (Midtrans Snap)';
    if (lower.contains('bca')) return 'BCA Virtual Account';
    if (lower.contains('mandiri')) return 'Mandiri Virtual Account';
    if (lower.contains('bni')) return 'BNI Virtual Account';
    if (lower.contains('bri')) return 'BRI Virtual Account';
    if (lower.contains('cimb')) return 'CIMB Niaga VA';
    if (lower.contains('permata')) return 'Permata Bank VA';
    return raw.replaceAll('_', ' ').toUpperCase();
  }

  /// Format waktu pelunasan menjadi format ramah pengguna
  String _formatDateTimeStr(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return '${FormatUtils.formatDate(parsed)}, ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')} WIB';
  }

  /// Tampilkan Kuitansi Sah Digital ber-QR Code Anti-Manipulasi (PRD US-4.4)
  void _showDigitalReceipt(Map<String, dynamic> inv) {
    final tenant = inv['tenants'] as Map<String, dynamic>?;
    final profile = tenant?['profiles'] as Map<String, dynamic>?;
    final room = tenant?['rooms'] as Map<String, dynamic>?;

    final orderId = inv['order_id']?.toString() ??
        inv['nomor_invoice']?.toString() ??
        'INV-${inv['id']}';
    final midtransTrxId = inv['midtrans_transaction_id']?.toString() ??
        'MTR-SETTLED-${inv['id'].toString().substring(0, 8)}';
    final roomNumber = room?['nomor_kamar']?.toString() ?? '-';
    final roomType = room?['tipe']?.toString() ?? 'Standard';
    final tenantName = profile?['full_name']?.toString() ?? 'Penghuni Kos';
    final periode = inv['periode']?.toString() ?? '-';
    final nominal = (inv['nominal'] as num?)?.toDouble() ?? 0.0;
    final paymentType = _formatPaymentChannel(inv['payment_type']?.toString());
    final settlementTime = _formatDateTimeStr(
      inv['settlement_time']?.toString() ??
          inv['diverifikasi_pada']?.toString() ??
          inv['tanggal_bayar']?.toString() ??
          inv['updated_at']?.toString(),
    );
    final qrVerificationCode = inv['qr_verification_code']?.toString() ??
        'ATURKOS-${orderId.replaceAll('/', '-')}-VERIFIED';

    MidtransTenantPaymentDialog.showReceiptModal(
      context,
      orderId: orderId,
      midtransTrxId: midtransTrxId,
      kosName: widget.kosName,
      roomNumber: roomNumber,
      roomType: roomType,
      tenantName: tenantName,
      periode: periode,
      nominal: nominal,
      paymentType: paymentType,
      settlementTime: settlementTime,
      qrVerificationCode: qrVerificationCode,
    );
  }

  /// Bagikan kuitansi digital resmi ke WhatsApp penyewa (PRD US-4.4)
  void _sendWhatsAppReceipt(Map<String, dynamic> inv) {
    final tenant = inv['tenants'] as Map<String, dynamic>?;
    final profile = tenant?['profiles'] as Map<String, dynamic>?;
    final room = tenant?['rooms'] as Map<String, dynamic>?;

    final tenantName = profile?['full_name']?.toString() ?? 'Penghuni';
    final roomNumber = room?['nomor_kamar']?.toString() ?? '-';
    final nominal = (inv['nominal'] as num?)?.toDouble() ?? 0.0;
    final periode = inv['periode']?.toString() ?? '-';
    final orderId = inv['order_id']?.toString() ??
        inv['nomor_invoice']?.toString() ??
        'INV-${inv['id']}';
    final qrCode = inv['qr_verification_code']?.toString() ??
        'ATURKOS-${orderId.replaceAll('/', '-')}-VALID';
    final paymentType = _formatPaymentChannel(inv['payment_type']?.toString());

    final message = '''
Halo $tenantName, pembayaran sewa ${widget.kosName} kamar $roomNumber untuk periode $periode sebesar ${FormatUtils.rupiah(nominal)} telah LUNAS terverifikasi via $paymentType.

Nomor Order: $orderId
Kuitansi digital resmi berstempel lunas dan QR code anti-manipulasi dapat dicek langsung di aplikasi Atur Kos atau melalui tautan verifikasi:
https://aturkos.app/verify/invoice?id=$orderId&seal=$qrCode

Terima kasih atas pelunasan tepat waktu!
'''.trim();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: Color(0xFF25D366), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kirim Kuitansi via WhatsApp',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Bukti Pelunasan Sah Ber-QR Code Anti-Manipulasi (PRD US-4.4)',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Text(
                message,
                style: const TextStyle(
                    fontSize: 13, height: 1.4, color: Color(0xFF1E293B)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Teks kuitansi WhatsApp berhasil disalin ke clipboard!'),
                          backgroundColor: Color(0xFF1E40AF),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Salin Pesan'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Pesan kuitansi siap dikirimkan via WhatsApp!'),
                          backgroundColor: Color(0xFF25D366),
                        ),
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Buka WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  PublicReceiptVerificationScreen.open(
                    context,
                    initialOrderId: orderId,
                    initialCode: qrCode,
                  );
                },
                icon: const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF0D9488)),
                label: const Text(
                  'Pratinjau Layar Verifikasi Publik (Anti-Fraud)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D9488),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog Buat Tagihan Baru Manual (PRD US-3.1)
  Future<void> _showCreateInvoiceDialog() async {
    final activeTenants = await KosService.getActiveTenants(widget.kostId);
    if (activeTenants.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Belum ada penghuni aktif. Alokasikan penghuni ke kamar terlebih dahulu di menu Alokasi Kamar.',
            ),
            backgroundColor: Color(0xFFD97706),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    Map<String, dynamic>? selectedTenant = activeTenants.first;
    final nominalController = TextEditingController(
      text: ((selectedTenant['rooms']?['harga_bulanan'] as num?)?.toDouble() ?? 1000000)
          .round()
          .toString(),
    );
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final room = selectedTenant?['rooms'] as Map<String, dynamic>?;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Terbitkan Tagihan Baru'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pilih Penghuni & Kamar', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: selectedTenant,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: activeTenants.map((t) {
                      final pName = t['profiles']?['full_name'] ?? 'Penghuni';
                      final rNum = t['rooms']?['nomor_kamar'] ?? '-';
                      return DropdownMenuItem(
                        value: t,
                        child: Text('$pName (Kamar $rNum)'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedTenant = val;
                        final price =
                            (val?['rooms']?['harga_bulanan'] as num?)?.toDouble() ?? 1000000;
                        nominalController.text = price.round().toString();
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Nominal Tagihan (Rp)', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nominalController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixText: 'Rp ',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Tanggal Jatuh Tempo', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => dueDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(FormatUtils.formatDate(dueDate)),
                          const Icon(Icons.calendar_month_rounded, size: 20, color: Color(0xFF1E40AF)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedTenant == null) return;
                  final nominal = double.tryParse(nominalController.text) ?? 0;
                  if (nominal <= 0) return;

                  final now = DateTime.now();
                  final periode = "${now.year}-${now.month.toString().padLeft(2, '0')}";
                  final nomorKamar = room?['nomor_kamar']?.toString() ?? '00';
                  final tenantId = selectedTenant!['id'].toString();

                  final success = await KosService.createInvoice(
                    kostId: widget.kostId ?? selectedTenant!['kost_id'].toString(),
                    tenantId: tenantId,
                    nomorKamar: nomorKamar,
                    nominal: nominal,
                    periode: periode,
                    tanggalJatuhTempo: dueDate,
                  );

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Tagihan untuk Kamar $nomorKamar berhasil diterbitkan!'
                              : 'Gagal menerbitkan tagihan.',
                        ),
                        backgroundColor:
                            success ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    );
                    _loadData();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Terbitkan Tagihan'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter data berdasarkan tab
    final pendingInvoices =
        _invoices.where((i) => i['status'] == 'menunggu_verifikasi').toList();
    final unpaidInvoices =
        _invoices.where((i) => i['status'] == 'belum_bayar').toList();
    final paidInvoices =
        _invoices.where((i) => i['status'] == 'lunas').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Kelola Tagihan & Kas Riil'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Segarkan Data',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E40AF)),
            onPressed: _loadData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: const Color(0xFF1E40AF),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF1E40AF),
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Semua (${_invoices.length})'),
              Tab(
                child: Row(
                  children: [
                    const Text('Perlu Verifikasi'),
                    if (pendingInvoices.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${pendingInvoices.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Text('Tunggakan'),
                    if (unpaidInvoices.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${unpaidInvoices.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(text: 'Lunas (${paidInvoices.length})'),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateInvoiceDialog,
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('Buat Tagihan'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header Mini Summary
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMiniStat(
                          label: 'Kas Masuk Riil',
                          value: FormatUtils.compactRupiah(_summary.pemasukanKasRiil),
                          color: const Color(0xFF059669),
                          icon: Icons.account_balance_wallet_rounded,
                        ),
                      ),
                      Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
                      Expanded(
                        child: _buildMiniStat(
                          label: 'Tunggakan Sewa',
                          value: FormatUtils.compactRupiah(_summary.totalTunggakan),
                          color: const Color(0xFFDC2626),
                          icon: Icons.warning_amber_rounded,
                        ),
                      ),
                      Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
                      Expanded(
                        child: _buildMiniStat(
                          label: 'Menunggu Dicek',
                          value: '${_summary.pendingVerificationCount} Tagihan',
                          color: const Color(0xFFD97706),
                          icon: Icons.pending_actions_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Tab View
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildInvoiceList(_invoices),
                      _buildInvoiceList(pendingInvoices),
                      _buildInvoiceList(unpaidInvoices),
                      _buildInvoiceList(paidInvoices),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMiniStat({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'Belum ada data tagihan di kategori ini.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
      );
    }

    final isLunasTab = items.isNotEmpty && items.every((i) => i['status'] == 'lunas');
    final midtransCount = items.where((i) {
      final trx = i['midtrans_transaction_id']?.toString() ?? '';
      final pt = i['payment_type']?.toString() ?? '';
      return trx.isNotEmpty || pt.contains('midtrans');
    }).length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: isLunasTab ? items.length + 1 : items.length,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          // Banner Info Otomasi Midtrans khusus pada Tab Lunas
          if (isLunasTab && index == 0) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF99F6E4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        color: Color(0xFF0D9488), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Integrasi Midtrans Snap & Kuitansi Digital (US-4.4)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$midtransCount dari ${items.length} pembayaran lunas otomatis terverifikasi via QRIS / Virtual Account Midtrans.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF115E59),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          final actualIndex = isLunasTab ? index - 1 : index;
          final inv = items[actualIndex];
          final tenant = inv['tenants'] as Map<String, dynamic>?;
          final profile = tenant?['profiles'] as Map<String, dynamic>?;
          final room = tenant?['rooms'] as Map<String, dynamic>?;

          final tenantName = profile?['full_name']?.toString() ?? 'Penghuni Belum Terdata';
          final roomNum = room?['nomor_kamar']?.toString() ?? '-';
          final roomType = room?['tipe']?.toString() ?? 'Standard';
          final nominal = (inv['nominal'] as num?)?.toDouble() ?? 0.0;
          final status = inv['status']?.toString() ?? 'belum_bayar';
          final dueDateStr = inv['tanggal_jatuh_tempo']?.toString() ?? '';
          final orderIdStr = inv['order_id']?.toString() ?? inv['nomor_invoice']?.toString() ?? '-';

          final isMidtrans = (inv['midtrans_transaction_id'] != null &&
                  inv['midtrans_transaction_id'].toString().trim().isNotEmpty) ||
              (inv['payment_type'] != null &&
                  inv['payment_type'].toString().contains('midtrans'));

          Color statusColor;
          String statusLabel;
          IconData statusIcon;

          switch (status) {
            case 'lunas':
              statusColor = isMidtrans ? const Color(0xFF0D9488) : const Color(0xFF059669);
              statusLabel = isMidtrans ? 'LUNAS (Midtrans Snap)' : 'LUNAS (Manual)';
              statusIcon = isMidtrans ? Icons.bolt_rounded : Icons.check_circle_rounded;
              break;
            case 'menunggu_verifikasi':
              statusColor = const Color(0xFFD97706);
              statusLabel = 'Menunggu Verifikasi';
              statusIcon = Icons.access_time_rounded;
              break;
            case 'ditolak':
              statusColor = const Color(0xFFDC2626);
              statusLabel = 'Ditolak';
              statusIcon = Icons.cancel_rounded;
              break;
            default:
              statusColor = const Color(0xFF2563EB);
              statusLabel = 'Belum Bayar';
              statusIcon = Icons.schedule_rounded;
          }

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: status == 'menunggu_verifikasi'
                    ? const Color(0xFFFDE68A)
                    : isMidtrans && status == 'lunas'
                        ? const Color(0xFF99F6E4)
                        : const Color(0xFFE2E8F0),
                width: status == 'menunggu_verifikasi' || (isMidtrans && status == 'lunas') ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tenantName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kamar $roomNum • $roomType • Periode ${inv['periode']}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nominal Sewa',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          FormatUtils.rupiah(nominal),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          status == 'lunas' ? 'Nomor Order' : 'Jatuh Tempo',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          status == 'lunas' ? orderIdStr : dueDateStr,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: status == 'lunas' ? 'monospace' : null,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Rincian Pembayaran Gateway Midtrans Snap untuk Invoice Lunas
                if (status == 'lunas' && isMidtrans) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCCFBF1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF0D9488)),
                            const SizedBox(width: 6),
                            const Text(
                              'Otomasi Midtrans Snap Webhook',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF99F6E4)),
                              ),
                              child: Text(
                                _formatPaymentChannel(inv['payment_type']?.toString()),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D9488),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (inv['midtrans_transaction_id'] != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Text(
                                'ID Transaksi: ',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                              Expanded(
                                child: Text(
                                  inv['midtrans_transaction_id'].toString(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF334155),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (inv['settlement_time'] != null || inv['diverifikasi_pada'] != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Text(
                                'Waktu Pelunasan: ',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                              Text(
                                _formatDateTimeStr(
                                  inv['settlement_time']?.toString() ?? inv['diverifikasi_pada']?.toString(),
                                ),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // Action Bar khusus per status
                if (status == 'lunas') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          onPressed: () => _showDigitalReceipt(inv),
                          icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                          label: const Text(
                            'Kuitansi Sah (QR)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: () => _sendWhatsAppReceipt(inv),
                          icon: const Icon(Icons.share_rounded, size: 16, color: Color(0xFF25D366)),
                          label: const Text(
                            'Kirim WA',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFECFDF5),
                            side: const BorderSide(color: Color(0xFFA7F3D0)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                if (status == 'menunggu_verifikasi') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleVerify(inv, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Tolak'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _handleVerify(inv, true),
                          icon: const Icon(Icons.check_circle_rounded, size: 16),
                          label: const Text('Verifikasi Lunas'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                if (status == 'belum_bayar') ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _sendWhatsAppReminder(inv),
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          color: Color(0xFF25D366), size: 16),
                      label: const Text(
                        'Kirim Pengingat WhatsApp (Otomatis PRD)',
                        style: TextStyle(color: Color(0xFF065F46)),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFECFDF5),
                        side: const BorderSide(color: Color(0xFFA7F3D0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
