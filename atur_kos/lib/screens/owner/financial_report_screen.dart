import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:atur_kos/models/cash_ledger_model.dart';
import 'package:atur_kos/services/kos_service.dart';
import 'package:atur_kos/services/report_pdf_service.dart';
import 'package:atur_kos/utils/format_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Halaman Laporan Keuangan & Buku Kas (Cash Flow) Pemilik Kos
/// Sesuai Spesifikasi PRD Modul 6 (Arus Kas Masuk Otomatis & Pengeluaran Manual)
/// Hak Akses: 100% Eksklusif untuk Pemilik Kos (Owner)
class FinancialReportScreen extends StatefulWidget {
  final String? kostId;
  final String kosName;
  final bool isJuragan;

  const FinancialReportScreen({
    super.key,
    required this.kostId,
    required this.kosName,
    this.isJuragan = false,
  });

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<CashLedgerModel> _allLedgers = [];
  String _ownerName = 'Pemilik Kos';

  // Filter Periode (Tahun & Bulan)
  late DateTime _selectedPeriod;
  bool _isAllPeriod = false;

  // Visualisasi Mode Tab
  int _chartModeIndex = 0; // 0 = Perbandingan Kas, 1 = Tren 6 Bulan
  int _transactionFilterIndex = 0; // 0 = Semua, 1 = Masuk (+), 2 = Keluar (-)
  final TextEditingController _searchController = TextEditingController();

  final List<String> _monthNames = const [
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedPeriod = DateTime(now.year, now.month);
    _loadOwnerName();
    _fetchLedgerData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadOwnerName() {
    final user = Supabase.instance.client.auth.currentUser;
    final metaName = user?.userMetadata?['full_name']?.toString();
    if (metaName != null && metaName.trim().isNotEmpty) {
      _ownerName = metaName.trim();
    }
  }

  /// Mengambil data mutasi buku kas dari database Supabase
  Future<void> _fetchLedgerData() async {
    setState(() => _isLoading = true);
    final rawData = await KosService.getCashLedgers(widget.kostId);

    if (mounted) {
      setState(() {
        _allLedgers = rawData.map((e) => CashLedgerModel.fromMap(e)).toList();
        _isLoading = false;
      });
    }
  }

  /// Filter ledgers sesuai bulan & tahun yang dipilih
  List<CashLedgerModel> get _filteredLedgers {
    return _allLedgers.where((l) {
      if (!_isAllPeriod) {
        if (l.tanggal.year != _selectedPeriod.year ||
            l.tanggal.month != _selectedPeriod.month) {
          return false;
        }
      }

      // Filter Tab: 1 = Masuk, 2 = Keluar
      if (_transactionFilterIndex == 1 && !l.isMasuk) return false;
      if (_transactionFilterIndex == 2 && !l.isKeluar) return false;

      // Filter Pencarian Teks
      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matchKet = l.keterangan.toLowerCase().contains(query);
        final matchKat = l.kategoriLabel.toLowerCase().contains(query);
        final matchNom = l.nominal.toString().contains(query);
        if (!matchKet && !matchKat && !matchNom) return false;
      }

      return true;
    }).toList();
  }

  /// Ringkasan Finansial untuk periode terpilih
  CashLedgerSummary get _currentSummary {
    final periodLedgers = _allLedgers.where((l) {
      if (_isAllPeriod) return true;
      return l.tanggal.year == _selectedPeriod.year &&
          l.tanggal.month == _selectedPeriod.month;
    }).toList();

    return CashLedgerSummary.fromLedgers(periodLedgers);
  }

  String get _periodLabel {
    if (_isAllPeriod) return 'Semua Periode (Akumulasi)';
    return "${_monthNames[_selectedPeriod.month - 1]} ${_selectedPeriod.year}";
  }

  void _changeMonth(int delta) {
    setState(() {
      _isAllPeriod = false;
      _selectedPeriod = DateTime(
        _selectedPeriod.year,
        _selectedPeriod.month + delta,
      );
    });
  }

  /// Dialog Catat Pengeluaran Baru (PRD US-6.2)
  Future<void> _showAddExpenseDialog() async {
    final formKey = GlobalKey<FormState>();
    final nominalController = TextEditingController();
    final keteranganController = TextEditingController();
    final notaUrlController = TextEditingController();
    String selectedKategori = 'listrik';
    DateTime selectedDate = DateTime.now();
    bool isSubmitting = false;

    final categories = [
      {
        'key': 'listrik',
        'label': '⚡ Token Listrik PLN',
        'color': const Color(0xFFEAB308),
      },
      {
        'key': 'wifi',
        'label': '📶 WiFi & Internet',
        'color': const Color(0xFF3B82F6),
      },
      {
        'key': 'air',
        'label': '💧 Air PDAM / Tangki',
        'color': const Color(0xFF06B6D4),
      },
      {
        'key': 'perbaikan',
        'label': '🔧 Servis & Perbaikan Fasilitas',
        'color': const Color(0xFFF97316),
      },
      {
        'key': 'kebersihan',
        'label': '🧹 Iuran Sampah & Kebersihan',
        'color': const Color(0xFF10B981),
      },
      {
        'key': 'gaji',
        'label': '👤 Gaji Penjaga / Karyawan',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'key': 'lainnya',
        'label': '📦 Perlengkapan & Operasional Lain',
        'color': const Color(0xFF64748B),
      },
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
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
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Color(0xFFDC2626),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Catat Pengeluaran Operasional',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Input nota biaya listrik, air, servis, atau tukang',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Pilihan Kategori
                      const Text(
                        'Kategori Biaya Operasional',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedKategori,
                            isExpanded: true,
                            items: categories.map((c) {
                              return DropdownMenuItem<String>(
                                value: c['key'] as String,
                                child: Text(
                                  c['label'] as String,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => selectedKategori = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Input Nominal Pengeluaran
                      const Text(
                        'Nominal Biaya (Rp)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: nominalController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                        decoration: InputDecoration(
                          prefixText: 'Rp ',
                          prefixStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                          ),
                          hintText: 'Misal: 350000',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nominal wajib diisi';
                          }
                          final parsed = double.tryParse(
                            value.replaceAll(RegExp(r'[^0-9]'), ''),
                          );
                          if (parsed == null || parsed <= 0) {
                            return 'Nominal harus lebih dari Rp 0';
                          }
                          return null;
                        },
                      ),

                      // Quick Chips Nominal Cepat
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [50000, 100000, 250000, 500000, 1000000]
                              .map((amt) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ActionChip(
                                    label: Text(
                                      FormatUtils.compactRupiah(amt),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    onPressed: () {
                                      nominalController.text = amt.toString();
                                    },
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tanggal Pengeluaran
                      const Text(
                        'Tanggal Transaksi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 30),
                            ),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                FormatUtils.formatDate(selectedDate),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'Ubah',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E40AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Keterangan Pengeluaran
                      const Text(
                        'Keterangan / Catatan Nota',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: keteranganController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Misal: Beli token listrik kamar 01-05 & lampu teras',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Keterangan pengeluaran wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Link Bukti Nota (Opsional)
                      const Text(
                        'Link Bukti Nota / Foto Nota (Opsional)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: notaUrlController,
                        decoration: InputDecoration(
                          hintText: 'https://... atau nomor nota kasir',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Tombol Simpan
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setModalState(() => isSubmitting = true);

                                  final rawNominal = nominalController.text
                                      .replaceAll(RegExp(r'[^0-9.]'), '');
                                  final nominal =
                                      double.tryParse(rawNominal) ?? 0.0;
                                  final resolvedKostId = widget.kostId ?? '';

                                  final success = await KosService.addExpense(
                                    kostId: resolvedKostId,
                                    kategori: selectedKategori,
                                    nominal: nominal,
                                    keterangan: keteranganController.text
                                        .trim(),
                                    tanggal: selectedDate,
                                    buktiNotaUrl: notaUrlController.text.trim(),
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? 'Pengeluaran sebesar ${FormatUtils.rupiah(nominal)} berhasil dicatat ke buku kas!'
                                              : 'Gagal mencatat pengeluaran ke buku kas.',
                                        ),
                                        backgroundColor: success
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFDC2626),
                                      ),
                                    );
                                    _fetchLedgerData();
                                  }
                                },
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 20),
                          label: Text(
                            isSubmitting
                                ? 'Menyimpan...'
                                : 'Simpan Pengeluaran Kas',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Dialog Catat Pemasukan Manual (misal sewa dibayar tunai)
  Future<void> _showAddIncomeDialog() async {
    final formKey = GlobalKey<FormState>();
    final nominalController = TextEditingController();
    final keteranganController = TextEditingController();
    String selectedKategori = 'sewa_kamar';
    DateTime selectedDate = DateTime.now();
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
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
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.arrow_downward_rounded,
                                  color: Color(0xFF059669),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Catat Pemasukan Kas Manual',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Untuk pembayaran tunai langsung dari anak kos',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        'Kategori Pemasukan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedKategori,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'sewa_kamar',
                                child: Text('🏠 Sewa Kamar Tunai'),
                              ),
                              DropdownMenuItem(
                                value: 'deposit',
                                child: Text('🛡️ Uang Jaminan / Deposit'),
                              ),
                              DropdownMenuItem(
                                value: 'denda',
                                child: Text('⚠️ Denda Keterlambatan'),
                              ),
                              DropdownMenuItem(
                                value: 'lainnya',
                                child: Text('➕ Pemasukan Lainnya'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => selectedKategori = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Nominal Uang Masuk (Rp)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: nominalController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                        decoration: InputDecoration(
                          prefixText: 'Rp ',
                          prefixStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                          hintText: 'Misal: 1500000',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nominal wajib diisi';
                          }
                          final parsed = double.tryParse(
                            value.replaceAll(RegExp(r'[^0-9]'), ''),
                          );
                          if (parsed == null || parsed <= 0) {
                            return 'Nominal harus lebih dari Rp 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Keterangan Transaksi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: keteranganController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Misal: Sewa Kamar 02 (Budi Santoso) bayar tunai di tempat',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Keterangan pemasukan wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setModalState(() => isSubmitting = true);

                                  final rawNominal = nominalController.text
                                      .replaceAll(RegExp(r'[^0-9.]'), '');
                                  final nominal =
                                      double.tryParse(rawNominal) ?? 0.0;
                                  final resolvedKostId = widget.kostId ?? '';

                                  final success = await KosService.addIncome(
                                    kostId: resolvedKostId,
                                    kategori: selectedKategori,
                                    nominal: nominal,
                                    keterangan: keteranganController.text
                                        .trim(),
                                    tanggal: selectedDate,
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? 'Pemasukan sebesar ${FormatUtils.rupiah(nominal)} berhasil dicatat ke buku kas!'
                                              : 'Gagal mencatat pemasukan.',
                                        ),
                                        backgroundColor: success
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFDC2626),
                                      ),
                                    );
                                    _fetchLedgerData();
                                  }
                                },
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 20),
                          label: Text(
                            isSubmitting
                                ? 'Menyimpan...'
                                : 'Simpan Pemasukan Kas',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Konfirmasi Hapus Mutasi Kas Keluar
  Future<void> _confirmDeleteLedger(CashLedgerModel ledger) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Hapus Mutasi Kas?'),
          ],
        ),
        content: Text(
          'Hapus pencatatan "${ledger.keterangan}" sebesar ${FormatUtils.rupiah(ledger.nominal)} dari buku kas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text(
              'Ya, Hapus',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await KosService.deleteCashLedger(ledger.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Mutasi kas berhasil dihapus.'
                  : 'Gagal menghapus mutasi kas.',
            ),
            backgroundColor: ok
                ? const Color(0xFF059669)
                : const Color(0xFFDC2626),
          ),
        );
        _fetchLedgerData();
      }
    }
  }

  /// Ekspor Laporan PDF Resmi Pembukuan Kas Pemilik
  Future<void> _exportPdfReport() async {
    final summary = _currentSummary;
    final ledgers = _filteredLedgers.map((l) => l.toMap()).toList();

    await ReportPdfService.exportOwnerCashLedgerReport(
      context: context,
      kosName: widget.kosName,
      ownerName: _ownerName,
      periodeLabel: _periodLabel,
      totalPemasukan: summary.totalPemasukan,
      totalPengeluaran: summary.totalPengeluaran,
      labaBersih: summary.labaBersih,
      jumlahTransaksiMasuk: summary.jumlahTransaksiMasuk,
      jumlahTransaksiKeluar: summary.jumlahTransaksiKeluar,
      ledgers: ledgers,
      pengeluaranPerKategori: summary.pengeluaranPerKategori,
      isJuragan: widget.isJuragan,
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _currentSummary;
    final filteredList = _filteredLedgers;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Laporan Arus Kas & Laba',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 10,
                        color: Color(0xFF1E40AF),
                      ),
                      SizedBox(width: 3),
                      Text(
                        'Owner Only',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Text(
              widget.kosName,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Unduh Laporan PDF',
            icon: const Icon(
              Icons.picture_as_pdf_rounded,
              color: Color(0xFF1E40AF),
            ),
            onPressed: _exportPdfReport,
          ),
          IconButton(
            tooltip: 'Segarkan Data',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E40AF)),
            onPressed: _fetchLedgerData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchLedgerData,
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
                        'Memuat buku kas dan transaksi riil...',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Selector Periode Bulan / Tahun & Quick Actions
                      _buildPeriodSelector(),
                      const SizedBox(height: 16),

                      // 2. Tiga Kotak Metrik Warna-Warni
                      _buildThreeMetricCards(summary),
                      const SizedBox(height: 20),

                      // 3. Bilah Tombol Aksi Cepat (+ Catat Pengeluaran Baru)
                      _buildQuickActionBar(),
                      const SizedBox(height: 20),

                      // 4. Visualisasi Grafik Batang (Bar Chart)
                      _buildBarChartSection(summary),
                      const SizedBox(height: 20),

                      // 5. Visualisasi Diagram Donut / Pie Pengeluaran Operasional
                      _buildExpenseDonutSection(summary),
                      const SizedBox(height: 24),

                      // 6. Riwayat Mutasi Arus Kas
                      _buildTransactionLedgerSection(filteredList),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  /// Selector Periode: Tombol panah bulan, dropdown bulan, atau semua periode
  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.date_range_rounded,
              color: Color(0xFF1E40AF),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Periode Pembukuan',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  _periodLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          if (!_isAllPeriod) ...[
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => _changeMonth(-1),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => _changeMonth(1),
            ),
          ],
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Pilih Periode',
            icon: const Icon(
              Icons.tune_rounded,
              color: Color(0xFF1E40AF),
              size: 20,
            ),
            onSelected: (val) {
              if (val == 'all') {
                setState(() => _isAllPeriod = true);
              } else if (val == 'now') {
                final now = DateTime.now();
                setState(() {
                  _isAllPeriod = false;
                  _selectedPeriod = DateTime(now.year, now.month);
                });
              } else {
                final parts = val.split('-');
                setState(() {
                  _isAllPeriod = false;
                  _selectedPeriod = DateTime(
                    int.parse(parts[0]),
                    int.parse(parts[1]),
                  );
                });
              }
            },
            itemBuilder: (context) {
              final now = DateTime.now();
              return [
                const PopupMenuItem(value: 'now', child: Text('📌 Bulan Ini')),
                const PopupMenuItem(
                  value: 'all',
                  child: Text('🌐 Semua Periode (Akumulasi)'),
                ),
                const PopupMenuDivider(),
                for (int i = 0; i < 6; i++) ...[
                  () {
                    final d = DateTime(now.year, now.month - i);
                    return PopupMenuItem(
                      value: '${d.year}-${d.month}',
                      child: Text('${_monthNames[d.month - 1]} ${d.year}'),
                    );
                  }(),
                ],
              ];
            },
          ),
        ],
      ),
    );
  }

  /// 3 Kartu Ringkasan Metrik (Pemasukan, Pengeluaran, Laba Bersih)
  Widget _buildThreeMetricCards(CashLedgerSummary summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;

        final cards = [
          // 🟢 KARTU 1: PEMASUKAN
          _buildSummaryCard(
            title: 'PEMASUKAN KAS',
            amount: summary.totalPemasukan,
            subtext: '${summary.jumlahTransaksiMasuk} Transaksi Sewa Lunas',
            icon: Icons.arrow_downward_rounded,
            primaryColor: const Color(0xFF059669),
            bgColor: const Color(0xFFECFDF5),
            borderColor: const Color(0xFFA7F3D0),
          ),
          // 🔴 KARTU 2: PENGELUARAN
          _buildSummaryCard(
            title: 'PENGELUARAN',
            amount: summary.totalPengeluaran,
            subtext: '${summary.jumlahTransaksiKeluar} Nota Biaya Operasional',
            icon: Icons.arrow_upward_rounded,
            primaryColor: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFEF2F2),
            borderColor: const Color(0xFFFECACA),
          ),
          // 🔵 KARTU 3: LABA BERSIH
          _buildSummaryCard(
            title: 'LABA BERSIH (NET PROFIT)',
            amount: summary.labaBersih,
            subtext: summary.totalPemasukan > 0
                ? 'Margin: ${summary.profitMargin.toStringAsFixed(1)}% • ${summary.financialHealthStatus}'
                : summary.financialHealthStatus,
            icon: Icons.savings_rounded,
            primaryColor: summary.labaBersih >= 0
                ? const Color(0xFF1E40AF)
                : const Color(0xFFDC2626),
            bgColor: summary.labaBersih >= 0
                ? const Color(0xFFEFF6FF)
                : const Color(0xFFFEF2F2),
            borderColor: summary.labaBersih >= 0
                ? const Color(0xFFBFDBFE)
                : const Color(0xFFFECACA),
          ),
        ];

        if (isWide) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
              const SizedBox(width: 12),
              Expanded(child: cards[2]),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 10),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: 10),
            cards[2],
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required String subtext,
    required IconData icon,
    required Color primaryColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.04),
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: primaryColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            FormatUtils.rupiah(amount),
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.4,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Bilah Aksi Cepat Pemilik Kos
  Widget _buildQuickActionBar() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            onPressed: _showAddExpenseDialog,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text(
              '+ Catat Pengeluaran Baru',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            onPressed: _showAddIncomeDialog,
            icon: const Icon(
              Icons.add_rounded,
              size: 18,
              color: Color(0xFF059669),
            ),
            label: const Text(
              '+ Kas Masuk',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF059669),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFA7F3D0), width: 1.2),
              backgroundColor: const Color(0xFFECFDF5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// VISUALISASI DATA 1: Grafik Batang (Bar Chart)
  Widget _buildBarChartSection(CashLedgerSummary summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              const Row(
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    color: Color(0xFF1E40AF),
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Visualisasi Arus Kas (Bar Chart)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              // Toggle Chart Mode (Perbandingan vs Tren 6 Bulan)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildChartTabBtn('Rasio', 0),
                    _buildChartTabBtn('Tren 6 Bulan', 1),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _chartModeIndex == 0
                ? 'Perbandingan Pemasukan vs Pengeluaran periode $_periodLabel'
                : 'Pertumbuhan arus kas masuk & keluar 6 bulan terakhir',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 18),

          // Tampilan Grafik
          _chartModeIndex == 0
              ? _buildComparisonBarChart(summary)
              : _buildSixMonthTrendChart(),

          const SizedBox(height: 14),

          // Legenda Grafik
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Pemasukan', const Color(0xFF059669)),
              const SizedBox(width: 16),
              _buildLegendItem('Pengeluaran', const Color(0xFFDC2626)),
              if (_chartModeIndex == 0) ...[
                const SizedBox(width: 16),
                _buildLegendItem('Laba Bersih', const Color(0xFF1E40AF)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartTabBtn(String label, int index) {
    final isSelected = _chartModeIndex == index;
    return InkWell(
      onTap: () => setState(() => _chartModeIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF1E40AF)
                : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  /// Grafik Batang Perbandingan Periode Terpilih
  Widget _buildComparisonBarChart(CashLedgerSummary summary) {
    final double maxVal = math.max(
      summary.totalPemasukan,
      math.max(
        summary.totalPengeluaran,
        summary.labaBersih > 0 ? summary.labaBersih : 0,
      ),
    );

    if (maxVal == 0) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        child: const Text(
          'Belum ada transaksi di periode ini untuk digrafikkan.',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
      );
    }

    return SizedBox(
      height: 190,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = math.min(constraints.maxWidth / 4.5, 60.0);

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Batang 1: Pemasukan
              _buildSingleBar(
                label: 'Pemasukan',
                amount: summary.totalPemasukan,
                maxVal: maxVal,
                barWidth: barWidth,
                color: const Color(0xFF059669),
                gradientColors: const [Color(0xFF34D399), Color(0xFF059669)],
              ),
              // Batang 2: Pengeluaran
              _buildSingleBar(
                label: 'Pengeluaran',
                amount: summary.totalPengeluaran,
                maxVal: maxVal,
                barWidth: barWidth,
                color: const Color(0xFFDC2626),
                gradientColors: const [Color(0xFFF87171), Color(0xFFDC2626)],
              ),
              // Batang 3: Laba Bersih
              _buildSingleBar(
                label: 'Laba Bersih',
                amount: summary.labaBersih > 0 ? summary.labaBersih : 0,
                maxVal: maxVal,
                barWidth: barWidth,
                color: const Color(0xFF1E40AF),
                gradientColors: const [Color(0xFF60A5FA), Color(0xFF1E40AF)],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSingleBar({
    required String label,
    required double amount,
    required double maxVal,
    required double barWidth,
    required Color color,
    required List<Color> gradientColors,
  }) {
    final pct = maxVal > 0 ? (amount / maxVal).clamp(0.05, 1.0) : 0.05;
    const maxHeight = 130.0;
    final currentHeight = maxHeight * pct;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Label Nilai Nominal di atas bar
        Text(
          FormatUtils.compactRupiah(amount),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        // Pilar Bar
        Container(
          width: barWidth,
          height: currentHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  /// Grafik Batang Tren 6 Bulan Terakhir
  Widget _buildSixMonthTrendChart() {
    final now = DateTime.now();
    final List<Map<String, dynamic>> monthlyData = [];
    double overallMax = 0.0;

    for (int i = 5; i >= 0; i--) {
      final mDate = DateTime(now.year, now.month - i);
      final monthLedgers = _allLedgers
          .where(
            (l) =>
                l.tanggal.year == mDate.year && l.tanggal.month == mDate.month,
          )
          .toList();

      final summary = CashLedgerSummary.fromLedgers(monthLedgers);
      if (summary.totalPemasukan > overallMax) {
        overallMax = summary.totalPemasukan;
      }
      if (summary.totalPengeluaran > overallMax) {
        overallMax = summary.totalPengeluaran;
      }

      monthlyData.add({
        'label': _monthNames[mDate.month - 1].substring(0, 3),
        'pemasukan': summary.totalPemasukan,
        'pengeluaran': summary.totalPengeluaran,
      });
    }

    if (overallMax == 0) overallMax = 1.0;

    return SizedBox(
      height: 190,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: monthlyData.map((d) {
          final label = d['label'] as String;
          final inc = d['pemasukan'] as double;
          final exp = d['pengeluaran'] as double;

          const maxHeight = 120.0;
          final incH = (inc / overallMax * maxHeight).clamp(4.0, maxHeight);
          final expH = (exp / overallMax * maxHeight).clamp(4.0, maxHeight);

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Batang Hijau Masuk
                  Container(
                    width: 14,
                    height: incH,
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Batang Merah Keluar
                  Container(
                    width: 14,
                    height: expH,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// VISUALISASI DATA 2: Diagram Donut / Pie Pengeluaran Operasional
  Widget _buildExpenseDonutSection(CashLedgerSummary summary) {
    final expMap = summary.pengeluaranPerKategori;
    final totalExp = summary.totalPengeluaran;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          const Row(
            children: [
              Icon(
                Icons.donut_large_rounded,
                color: Color(0xFFDC2626),
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'Komposisi Pengeluaran Operasional',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Analisis persentase biaya kos untuk efisiensi pengeluaran',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 18),

          if (expMap.isEmpty || totalExp <= 0)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Belum Ada Pengeluaran di Periode Ini',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Klik tombol "+ Catat Pengeluaran Baru" untuk mencatat nota listrik, internet, air, atau tukang.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 550;

                final chartWidget = Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CustomPaint(
                          painter: _DonutChartPainter(
                            data: expMap,
                            total: totalExp,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            FormatUtils.compactRupiah(totalExp),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );

                final breakdownWidget = Column(
                  children: expMap.entries.map((entry) {
                    final pct = (entry.value / totalExp) * 100;
                    final categoryModel = CashLedgerModel(
                      id: '',
                      kostId: '',
                      tipe: 'keluar',
                      kategori: entry.key,
                      nominal: entry.value,
                      tanggal: DateTime.now(),
                      keterangan: '',
                    );

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: categoryModel.kategoriColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  categoryModel.kategoriLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                              Text(
                                '${pct.toStringAsFixed(0)}% • ${FormatUtils.rupiah(entry.value)}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct / 100,
                              minHeight: 5,
                              backgroundColor: const Color(0xFFF1F5F9),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                categoryModel.kategoriColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(flex: 2, child: chartWidget),
                      const SizedBox(width: 24),
                      Expanded(flex: 3, child: breakdownWidget),
                    ],
                  );
                }

                return Column(
                  children: [
                    chartWidget,
                    const SizedBox(height: 20),
                    breakdownWidget,
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// RIWAYAT MUTASI TERAKHIR BUKU KAS
  Widget _buildTransactionLedgerSection(List<CashLedgerModel> ledgers) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          color: Color(0xFF1E40AF),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Riwayat Mutasi Buku Kas (${ledgers.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    if (widget.isJuragan)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: const Text(
                          '⭐ Juragan Audit',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari catatan mutasi, nomor kamar, atau nota...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Filter Tabs: Semua / Masuk / Keluar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Semua Transaksi', 0),
                      const SizedBox(width: 8),
                      _buildFilterChip('🟢 Kas Masuk (+)', 1),
                      const SizedBox(width: 8),
                      _buildFilterChip('🔴 Kas Keluar (-)', 2),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          if (ledgers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 44,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tidak Ditemukan Mutasi Kas',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _searchController.text.isNotEmpty
                          ? 'Tidak ada transaksi dengan kata kunci "${_searchController.text}".'
                          : 'Belum ada transaksi pada periode $_periodLabel.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ledgers.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                indent: 64,
                color: Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, index) {
                final item = ledgers[index];
                return _buildLedgerTile(item);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _transactionFilterIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _transactionFilterIndex = index),
      selectedColor: const Color(0xFFEFF6FF),
      backgroundColor: const Color(0xFFF8FAFC),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? const Color(0xFF1E40AF) : const Color(0xFF64748B),
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildLedgerTile(CashLedgerModel item) {
    final isMasuk = item.isMasuk;
    final primaryColor = isMasuk
        ? const Color(0xFF059669)
        : const Color(0xFFDC2626);
    final bgColor = isMasuk ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);

    return InkWell(
      onTap: () => _showLedgerDetailDialog(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Ikon Kategori Bulat
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(item.kategoriIcon, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 12),

            // Keterangan & Kategori
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.keterangan.isNotEmpty
                        ? item.keterangan
                        : item.kategoriLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: item.kategoriColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.kategoriLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: item.kategoriColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        FormatUtils.formatDate(item.tanggal),
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Nominal Uang
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isMasuk ? "+ " : "- "}${FormatUtils.rupiah(item.nominal)}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                if (!isMasuk)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    tooltip: 'Hapus Nota',
                    onPressed: () => _confirmDeleteLedger(item),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLedgerDetailDialog(CashLedgerModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(
              item.isMasuk
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: item.isMasuk
                  ? const Color(0xFF059669)
                  : const Color(0xFFDC2626),
            ),
            const SizedBox(width: 8),
            Text(
              item.isMasuk ? 'Detail Kas Masuk' : 'Detail Kas Keluar',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              'Nominal',
              '${item.isMasuk ? "+ " : "- "}${FormatUtils.rupiah(item.nominal)}',
              isBold: true,
            ),
            _buildDetailRow('Kategori', item.kategoriLabel),
            _buildDetailRow('Tanggal', FormatUtils.formatDate(item.tanggal)),
            _buildDetailRow('Keterangan', item.keterangan),
            if (item.invoiceId != null && item.invoiceId!.isNotEmpty)
              _buildDetailRow('Ref Tagihan', item.invoiceId!),
            if (item.buktiNotaUrl != null && item.buktiNotaUrl!.isNotEmpty)
              _buildDetailRow('Bukti Nota', item.buktiNotaUrl!),
          ],
        ),
        actions: [
          if (item.isKeluar)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _confirmDeleteLedger(item);
              },
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFDC2626),
                size: 16,
              ),
              label: const Text(
                'Hapus Mutasi',
                style: TextStyle(color: Color(0xFFDC2626)),
              ),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E40AF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter untuk Donut / Pie Chart Pengeluaran Tanpa Library Eksternal
class _DonutChartPainter extends CustomPainter {
  final Map<String, double> data;
  final double total;

  _DonutChartPainter({required this.data, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 24.0;

    double startAngle = -math.pi / 2;

    for (final entry in data.entries) {
      final sweepAngle = (entry.value / total) * 2 * math.pi;
      final categoryModel = CashLedgerModel(
        id: '',
        kostId: '',
        tipe: 'keluar',
        kategori: entry.key,
        nominal: entry.value,
        tanggal: DateTime.now(),
        keterangan: '',
      );

      final paint = Paint()
        ..color = categoryModel.kategoriColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - (strokeWidth / 2)),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.data != data;
  }
}
