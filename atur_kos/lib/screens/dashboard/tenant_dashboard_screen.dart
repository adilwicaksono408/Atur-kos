import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:atur_kos/models/user_profile.dart';
import 'package:atur_kos/screens/payment/midtrans_tenant_payment_dialog.dart';
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
  late UserProfile _currentProfile;
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _assignmentData;
  Map<String, dynamic>? _linkedKosData;
  Map<String, dynamic>? _activeInvoice;
  List<Map<String, dynamic>> _complaints = [];
  bool _isLoading = true;
  bool _isProofUploaded = false;
  bool _isJoiningKos = false;
  bool _showManualTransferOptions = false;
  String? _h30Status; // 'lanjut', 'selesai', 'menunggu'
  final _kodeUndanganController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentProfile = widget.profile;
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
    Map<String, dynamic>? activeInvoice;

    // Refresh data profil terbaru untuk identitas KTP & kontak darurat
    UserProfile? freshProfile;
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser != null) {
      try {
        freshProfile = await AuthService.fetchUserProfile(authUser);
      } catch (_) {}
    }

    if (assignment != null) {
      final kostId = assignment['kost_id']?.toString();
      final tenantId = assignment['id']?.toString();
      final room = assignment['rooms'] as Map<String, dynamic>?;
      final roomPrice = (room?['harga_bulanan'] as num?)?.toDouble() ?? 1200000.0;
      final roomNum = room?['nomor_kamar']?.toString() ?? '01';

      if (tenantId != null) {
        activeInvoice = await KosService.getTenantActiveInvoice(
          tenantId,
          kostId: kostId,
          nominal: roomPrice,
          nomorKamar: roomNum,
        );
      }

      complaints = await KosService.getComplaints(
        kostId: kostId,
        tenantId: tenantId,
      );
      _h30Status = assignment['h30_response']?.toString();
      if (assignment['kosts'] is Map<String, dynamic>) {
        linkedKos = assignment['kosts'] as Map<String, dynamic>;
      } else if (kostId != null && kostId.isNotEmpty) {
        linkedKos = await KosService.getKosProfile(kostId);
      }
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
        if (freshProfile != null) {
          _currentProfile = freshProfile;
        }
        _assignmentData = assignment;
        _linkedKosData = linkedKos;
        _activeInvoice = activeInvoice;
        _complaints = complaints;
        _isProofUploaded = activeInvoice?['status'] == 'menunggu_verifikasi';
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
    final name = _currentProfile.fullName.trim();
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

  String _getKosName() {
    if (_linkedKosData != null &&
        _linkedKosData!['nama_kost'] != null &&
        _linkedKosData!['nama_kost'].toString().trim().isNotEmpty) {
      return _linkedKosData!['nama_kost'].toString();
    }
    if (_assignmentData != null) {
      final kosts = _assignmentData!['kosts'];
      if (kosts is Map &&
          kosts['nama_kost'] != null &&
          kosts['nama_kost'].toString().trim().isNotEmpty) {
        return kosts['nama_kost'].toString();
      }
    }
    return 'Kos';
  }

  Future<void> _handleUploadProof() async {
    final invoiceId = _activeInvoice?['id']?.toString();
    if (invoiceId != null) {
      await KosService.uploadTenantInvoiceProofManual(
        invoiceId: invoiceId,
        buktiBayarUrl: 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=600',
      );
    }

    setState(() {
      _isProofUploaded = true;
    });

    _fetchTenantData();

    if (mounted) {
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
  }

  /// Membuka dialog pembayaran Midtrans Snap Sandbox untuk sewa kamar (PRD Modul 4)
  Future<void> _openMidtransPayment() async {
    if (_assignmentData == null || _activeInvoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data tagihan belum siap. Silakan muat ulang dasbor.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final invoiceId = _activeInvoice!['id']?.toString() ?? '';
    final kostId = _assignmentData!['kost_id']?.toString() ?? '';
    final tenantId = _assignmentData!['id']?.toString() ?? '';
    final room = _assignmentData!['rooms'] as Map<String, dynamic>?;
    final roomNumber = room?['nomor_kamar']?.toString() ?? '01';
    final roomType = room?['tipe']?.toString() ?? 'Standard';
    final nominal = (_activeInvoice!['nominal'] as num?)?.toDouble() ??
        (room?['harga_bulanan'] as num?)?.toDouble() ??
        1200000.0;
    final periode = _activeInvoice!['periode']?.toString() ??
        "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
    final orderId = _activeInvoice!['order_id']?.toString() ?? _activeInvoice!['nomor_invoice']?.toString();
    final dueDate = _activeInvoice!['tanggal_jatuh_tempo']?.toString();

    final settled = await MidtransTenantPaymentDialog.show(
      context,
      invoiceId: invoiceId,
      kostId: kostId,
      tenantId: tenantId,
      kosName: _getKosName(),
      roomNumber: roomNumber,
      roomType: roomType,
      tenantName: _getDisplayName(),
      periode: periode,
      nominal: nominal,
      existingOrderId: orderId,
      dueDate: dueDate,
      onPaymentSuccess: () {
        _fetchTenantData();
      },
    );

    if (settled == true) {
      _fetchTenantData();
    }
  }

  /// Menampilkan modal kuitansi sah digital ber-QR code anti-manipulasi (US-4.4)
  void _openDigitalReceipt() {
    if (_activeInvoice == null) return;
    final room = _assignmentData?['rooms'] as Map<String, dynamic>?;
    final roomNumber = room?['nomor_kamar']?.toString() ?? '01';
    final roomType = room?['tipe']?.toString() ?? 'Standard';
    final orderId = _activeInvoice!['order_id']?.toString() ?? _activeInvoice!['nomor_invoice']?.toString() ?? '-';
    final midtransTrxId = _activeInvoice!['midtrans_transaction_id']?.toString() ?? 'MTR-AUTO-SETTLED';
    final nominal = (_activeInvoice!['nominal'] as num?)?.toDouble() ?? 1200000.0;
    final paymentType = _activeInvoice!['payment_type']?.toString().toUpperCase() ?? 'MIDTRANS SNAP';
    final settlementTime = _activeInvoice!['settlement_time']?.toString() ??
        _activeInvoice!['diverifikasi_pada']?.toString() ??
        DateTime.now().toIso8601String().substring(0, 16);
    final qrVerificationCode = _activeInvoice!['qr_verification_code']?.toString() ??
        'ATURKOS-$orderId';

    MidtransTenantPaymentDialog.showReceiptModal(
      context,
      orderId: orderId,
      midtransTrxId: midtransTrxId,
      kosName: _getKosName(),
      roomNumber: roomNumber,
      roomType: roomType,
      tenantName: _getDisplayName(),
      periode: _activeInvoice!['periode']?.toString() ?? 'Bulan Ini',
      nominal: nominal,
      paymentType: paymentType,
      settlementTime: settlementTime,
      qrVerificationCode: qrVerificationCode,
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
        content: Text(
          'Masa sewa Anda mendekati periode akhir. Untuk kenyamanan bersama dan perencanaan operasional kamar, apakah Anda akan melanjutkan sewa di ${_getKosName()} untuk bulan berikutnya?',
          style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF475569)),
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
                  _getKosName(),
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
                                  ? 'Selamat beraktivitas di ${_getKosName()}. Seluruh layanan kenyamanan kamar siap diakses.'
                                  : 'Akun Anda aktif. Saat ini menunggu pemilik kos menghubungkan nomor kamar Anda.',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                      // Kartu Identitas Diri & Dokumen KTP (PRD Identitas Penghuni)
                      _buildIdentityCard(),

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
                            'Dapatkan kode ini dari pemilik atau pengelola kos Anda',
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
                    hintText: hasLinkedKos ? kodeKost : 'Contoh: KOSKU123',
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

  /// Tampilan saat penghuni sudah memiliki kamar aktif di kos
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

        // Kartu Tagihan Bulan Berjalan (Smart Billing PRD Modul 4)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tagihan Sewa Bulan Ini',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 12, color: Color(0xFF0D9488)),
                  SizedBox(width: 4),
                  Text(
                    'Midtrans Protected',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Builder(
          builder: (context) {
            final activeNominal = (_activeInvoice?['nominal'] as num?)?.toDouble() ?? price;
            final orderId = _activeInvoice?['order_id']?.toString() ?? _activeInvoice?['nomor_invoice']?.toString() ?? '-';
            final periodeStr = _activeInvoice?['periode']?.toString() ?? 'Bulan Berjalan';
            final status = _activeInvoice?['status']?.toString() ?? (_isProofUploaded ? 'menunggu_verifikasi' : 'belum_bayar');
            final isPaid = status == 'lunas';
            final isPending = status == 'menunggu_verifikasi';

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPaid
                      ? const Color(0xFF10B981)
                      : isPending
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF0D9488),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isPaid
                        ? const Color(0xFF10B981).withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
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
                          Text(
                            'Periode $periodeStr',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            FormatUtils.rupiah(activeNominal),
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
                          color: isPaid
                              ? const Color(0xFFDCFCE7)
                              : isPending
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPaid) ...[
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              isPaid
                                  ? 'Lunas'
                                  : isPending
                                      ? 'Menunggu Verifikasi'
                                      : 'Belum Bayar',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPaid
                                    ? const Color(0xFF16A34A)
                                    : isPending
                                        ? const Color(0xFFB45309)
                                        : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 14),

                  // Kondisi 1: SUDAH LUNAS (Midtrans Snap auto-settlement atau manual)
                  if (isPaid) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Terbayar via ${_activeInvoice?['payment_type']?.toString().toUpperCase() ?? 'MIDTRANS SNAP'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Order ID: $orderId',
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF166534)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openDigitalReceipt,
                        icon: const Icon(Icons.receipt_long_rounded, size: 18),
                        label: const Text('Lihat Kuitansi Sah Digital (QR Code)', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ]
                  // Kondisi 2: MENUNGGU VERIFIKASI (Bukti transfer manual)
                  else if (isPending) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bukti transfer telah diterima. Pemilik kos sedang memvalidasi pembayaran Anda.',
                              style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openMidtransPayment,
                        icon: const Icon(Icons.flash_on_rounded, size: 18, color: Color(0xFF0D9488)),
                        label: const Text(
                          'Atau Bayar Instan via Midtrans (Auto-Lunas)',
                          style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0D9488)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ]
                  // Kondisi 3: BELUM BAYAR (Alur Utama: Midtrans Snap Gateway)
                  else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCCFBF1)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.flash_on_rounded, color: Color(0xFF0D9488), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bayar instan via QRIS atau Virtual Account semua bank. Verifikasi otomatis tanpa perlu konfirmasi manual!',
                              style: TextStyle(fontSize: 11, color: Color(0xFF0F766E), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tombol Utama: Bayar via Midtrans Snap (Sandbox)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openMidtransPayment,
                        icon: const Icon(Icons.payment_rounded, size: 18),
                        label: const Text(
                          'Bayar via Midtrans (Sandbox)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Opsi Transfer Manual Bank Kos (Accordion / Toggle)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showManualTransferOptions = !_showManualTransferOptions;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _showManualTransferOptions ? 'Sembunyikan Opsi Transfer Manual' : 'Opsi Alternatif: Transfer Bank Manual',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showManualTransferOptions ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: const Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_showManualTransferOptions) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _handleUploadProof,
                                icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                                label: const Text('Unggah Bukti Transfer Bank', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF475569),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            );
          },
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

  // ===========================================================================
  // KELENGKAPAN IDENTITAS DIRI & DOKUMEN KTP PENGHUNI (PRD IDENTITAS PENGHUNI)
  // ===========================================================================

  Widget _buildIdentityCard() {
    final hasKtp = _currentProfile.hasKtp;
    final hasNik = _currentProfile.hasNik;
    final isComplete = hasKtp && hasNik;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isComplete ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isComplete ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isComplete ? const Color(0xFF16A34A) : const Color(0xFFD97706))
                .withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isComplete ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isComplete ? Icons.badge_rounded : Icons.contact_emergency_rounded,
                  color: isComplete ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                  size: 24,
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
                            isComplete ? 'Identitas Diri & KTP Terlampir' : 'Kelengkapan Identitas & KTP',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isComplete ? const Color(0xFF14532D) : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isComplete ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isComplete ? 'Terverifikasi' : 'Perlu Dilengkapi',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isComplete
                          ? 'Data NIK KTP dan kontak darurat Anda telah tercatat dengan aman untuk keperluan administrasi kos.'
                          : 'Pemilik kos menganjurkan Anda melengkapi NIK, foto fisik KTP, dan kontak darurat untuk ketertiban sewa & pencatatan warga.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isComplete ? const Color(0xFF166534) : const Color(0xFFB45309),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          // Info Ringkas
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nomor NIK KTP',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentProfile.maskedNik,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kontak Darurat',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentProfile.kontakDaruratNama != null &&
                              _currentProfile.kontakDaruratNama!.isNotEmpty
                          ? '${_currentProfile.kontakDaruratNama} (${_currentProfile.kontakDaruratWa ?? "-"})'
                          : 'Belum diisi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _currentProfile.kontakDaruratNama != null
                            ? const Color(0xFF0F172A)
                            : Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Action Buttons
          Row(
            children: [
              if (hasKtp) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showKtpPreviewModal(
                      title: 'Dokumen KTP Saya',
                      imageUrl: _currentProfile.dokumenKtpUrl!,
                      nik: _currentProfile.nikKtp ?? '-',
                      name: _currentProfile.fullName,
                      emergencyName: _currentProfile.kontakDaruratNama,
                      emergencyWa: _currentProfile.kontakDaruratWa,
                    ),
                    icon: const Icon(Icons.fullscreen_rounded, size: 18),
                    label: const Text('Lihat Foto KTP'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF16A34A),
                      side: const BorderSide(color: Color(0xFF16A34A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showEditIdentityDialog,
                  icon: Icon(hasKtp ? Icons.edit_rounded : Icons.upload_file_rounded, size: 18),
                  label: Text(hasKtp ? 'Ubah Data' : 'Lengkapi KTP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasKtp ? const Color(0xFF0F172A) : const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Dialog Form Lengkapi Identitas Diri, NIK & Dokumen KTP
  Future<void> _showEditIdentityDialog() async {
    final formKey = GlobalKey<FormState>();
    final nikController = TextEditingController(text: _currentProfile.nikKtp ?? '');
    final nameController = TextEditingController(text: _currentProfile.fullName);
    final emergencyNameController =
        TextEditingController(text: _currentProfile.kontakDaruratNama ?? '');
    final emergencyWaController =
        TextEditingController(text: _currentProfile.kontakDaruratWa ?? '');

    String currentKtpUrl = _currentProfile.dokumenKtpUrl ?? '';
    Uint8List? localKtpBytes;
    bool isUploadingKtp = false;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickImage(ImageSource source) async {
            try {
              setDialogState(() => isUploadingKtp = true);
              final XFile? picked = await _picker.pickImage(
                source: source,
                maxWidth: 1200,
                maxHeight: 1200,
                imageQuality: 80,
              );
              if (picked == null) {
                setDialogState(() => isUploadingKtp = false);
                return;
              }
              final bytes = await picked.readAsBytes();
              final ext = picked.name.split('.').last.toLowerCase();
              final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
              String finalUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';

              try {
                final fileName =
                    'ktp_${_currentProfile.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
                final path = 'tenants/$fileName';
                await Supabase.instance.client.storage
                    .from('verification-docs')
                    .uploadBinary(
                      path,
                      bytes,
                      fileOptions: FileOptions(contentType: mimeType, upsert: true),
                    );
                final publicUrl = Supabase.instance.client.storage
                    .from('verification-docs')
                    .getPublicUrl(path);
                finalUrl = publicUrl;
              } catch (storageError) {
                debugPrint('Storage bucket fallback to Base64: $storageError');
              }

              setDialogState(() {
                localKtpBytes = bytes;
                currentKtpUrl = finalUrl;
                isUploadingKtp = false;
              });
            } catch (e) {
              setDialogState(() => isUploadingKtp = false);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal memilih gambar: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }

          final hasImage = currentKtpUrl.isNotEmpty || localKtpBytes != null;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
              padding: const EdgeInsets.all(22),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.badge_rounded, color: Color(0xFF0D9488), size: 24),
                            SizedBox(width: 10),
                            Text(
                              'Identitas Diri & KTP',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (!isSaving)
                          IconButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            icon: const Icon(Icons.close_rounded),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Lengkapi data NIK dan foto KTP asli Anda untuk pencatatan resmi warga kos dan kontak darurat.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Nama Sesuai KTP
                            const Text(
                              'Nama Lengkap (Sesuai KTP)',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: nameController,
                              decoration: InputDecoration(
                                hintText: 'Nama lengkap sesuai KTP',
                                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Nama lengkap wajib diisi';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // 2. NIK KTP
                            const Text(
                              'Nomor Induk Kependudukan (NIK KTP)',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: nikController,
                              keyboardType: TextInputType.number,
                              maxLength: 16,
                              decoration: InputDecoration(
                                hintText: 'Contoh: 3201234567890001',
                                counterText: '',
                                prefixIcon: const Icon(Icons.credit_card_rounded, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              validator: (val) {
                                if (val != null && val.trim().isNotEmpty) {
                                  final clean = val.trim();
                                  if (clean.length != 16 || int.tryParse(clean) == null) {
                                    return 'NIK KTP harus tepat 16 digit angka';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // 3. Foto Dokumen KTP
                            const Text(
                              'Foto / Scan Dokumen KTP Asli',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pastikan foto jelas, tidak buram, dan teks terbaca.',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 8),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: hasImage ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                children: [
                                  if (isUploadingKtp)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 30),
                                      child: Column(
                                        children: [
                                          CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488)),
                                          SizedBox(height: 10),
                                          Text('Memproses foto KTP...', style: TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    )
                                  else if (hasImage) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        height: 170,
                                        width: double.infinity,
                                        child: _buildKtpImageWidget(currentKtpUrl, localKtpBytes),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () {
                                            setDialogState(() {
                                              localKtpBytes = null;
                                              currentKtpUrl = '';
                                            });
                                          },
                                          icon: const Icon(Icons.delete_outline_rounded,
                                              size: 16, color: Colors.red),
                                          label: const Text('Hapus',
                                              style: TextStyle(fontSize: 12, color: Colors.red)),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          onPressed: () => pickImage(ImageSource.gallery),
                                          icon: const Icon(Icons.photo_library_rounded, size: 16),
                                          label: const Text('Ganti', style: TextStyle(fontSize: 12)),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            minimumSize: Size.zero,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      child: Column(
                                        children: [
                                          Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey.shade400),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Pilih Foto Dokumen KTP',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Kamera langsung atau ambil dari galeri',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                          ),
                                          const SizedBox(height: 14),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: () => pickImage(ImageSource.camera),
                                                icon: const Icon(Icons.camera_alt_rounded, size: 16),
                                                label: const Text('Kamera', style: TextStyle(fontSize: 12)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF0F172A),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  elevation: 0,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              OutlinedButton.icon(
                                                onPressed: () => pickImage(ImageSource.gallery),
                                                icon: const Icon(Icons.photo_library_rounded, size: 16),
                                                label: const Text('Galeri', style: TextStyle(fontSize: 12)),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(0xFF0F172A),
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                            const SizedBox(height: 18),

                            // 4. Kontak Darurat
                            const Text(
                              'Kontak Darurat (Emergency Contact)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Dihubungi pemilik kos jika ada kondisi mendesak atau darurat medis.',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: emergencyNameController,
                              decoration: InputDecoration(
                                labelText: 'Nama Kerabat / Orang Tua',
                                hintText: 'Contoh: Bapak Hendra (Ayah)',
                                prefixIcon: const Icon(Icons.people_outline_rounded, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: emergencyWaController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Nomor WhatsApp Darurat',
                                hintText: 'Contoh: 081234567890',
                                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;
                                    setDialogState(() => isSaving = true);
                                    final navigator = Navigator.of(dialogCtx);
                                    final messenger = ScaffoldMessenger.of(context);

                                    final success = await KosService.updateTenantIdentity(
                                      userId: _currentProfile.id,
                                      nikKtp: nikController.text.trim(),
                                      dokumenKtpUrl: currentKtpUrl,
                                      emergencyName: emergencyNameController.text.trim(),
                                      emergencyWa: emergencyWaController.text.trim(),
                                      fullName: nameController.text.trim(),
                                    );

                                    if (mounted) {
                                      if (success) {
                                        setState(() {
                                          _currentProfile = _currentProfile.copyWith(
                                            nikKtp: nikController.text.trim(),
                                            dokumenKtpUrl: currentKtpUrl,
                                            kontakDaruratNama: emergencyNameController.text.trim(),
                                            kontakDaruratWa: emergencyWaController.text.trim(),
                                            fullName: nameController.text.trim(),
                                            statusIdentitas: 'terunggah',
                                          );
                                        });
                                        navigator.pop();
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: const Row(
                                              children: [
                                                Icon(Icons.check_circle_rounded,
                                                    color: Colors.white, size: 20),
                                                SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    'Data identitas dan KTP berhasil disimpan!',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: const Color(0xFF059669),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10)),
                                          ),
                                        );
                                      } else {
                                        setDialogState(() => isSaving = false);
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Gagal menyimpan identitas. Periksa koneksi Anda.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Simpan Identitas'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Modal Pratinjau Foto KTP dengan Zoom Interaktif
  void _showKtpPreviewModal({
    required String title,
    required String imageUrl,
    required String nik,
    required String name,
    String? emergencyName,
    String? emergencyWa,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.badge_rounded, color: Color(0xFF0D9488), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Image Viewer with Zoom
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.05),
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Center(
                        child: _buildKtpImageWidget(imageUrl, null),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nama: $name',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('NIK: $nik',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    if (emergencyName != null && emergencyName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Kontak Darurat: $emergencyName (${emergencyWa ?? "-"})',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKtpImageWidget(String url, Uint8List? localBytes) {
    if (localBytes != null) {
      return Image.memory(
        localBytes,
        fit: BoxFit.contain,
        width: double.infinity,
      );
    }
    if (url.startsWith('data:image')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          width: double.infinity,
        );
      } catch (_) {}
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      width: double.infinity,
      errorBuilder: (ctx, err, stack) => Container(
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_rounded, color: Colors.grey, size: 36),
            SizedBox(height: 8),
            Text('Gagal memuat foto KTP', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
