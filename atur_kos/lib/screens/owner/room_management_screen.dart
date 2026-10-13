import 'package:flutter/material.dart';
import 'package:atur_kos/models/kost_model.dart';
import 'package:atur_kos/services/kos_service.dart';

/// Halaman Manajemen Inventaris Kamar Kos (CRUD Kamar)
/// Pemilik dapat menambah kamar baru secara manual atau menggunakan template preset default.
class RoomManagementScreen extends StatefulWidget {
  final String? kostId;
  final String kosName;

  const RoomManagementScreen({
    super.key,
    required this.kostId,
    required this.kosName,
  });

  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  List<Map<String, dynamic>> _rooms = [];
  KostModel? _kostModel;
  bool _isLoading = true;
  String _selectedFilter = 'semua'; // 'semua', 'kosong', 'terisi', 'perbaikan'

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      KosService.getRooms(widget.kostId),
      KosService.getKostModel(widget.kostId),
    ]);
    if (mounted) {
      setState(() {
        _rooms = results[0] as List<Map<String, dynamic>>;
        _kostModel = results[1] as KostModel?;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredRooms {
    if (_selectedFilter == 'semua') return _rooms;
    return _rooms.where((r) => (r['status'] ?? 'kosong') == _selectedFilter).toList();
  }

  // Dialog Upgrade Paket Juragan (PRD v2.0.0 Modul 3 & 10)
  void _showUpgradeDialog() {
    int selectedDuration = 12; // 1 = bulanan, 12 = tahunan (default rekomendasi)

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.star_rounded, color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upgrade ke Paket Juragan',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Buka kuota hingga 25 kamar & fitur otomasi penuh',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Text(
                      'Batas kuota Paket Starter (${_kostModel?.maxRooms ?? 5} kamar) telah tercapai. Tingkatkan paket untuk mengelola lebih banyak kamar.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Fitur Paket Juragan
                  const Text('Keuntungan Paket Juragan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  _buildFeatureRow('Kuota kamar terbuka hingga 25 kamar'),
                  _buildFeatureRow('Pengingat WhatsApp Otomatis (Protokol Anti-Ban)'),
                  _buildFeatureRow('AI Marketing Poster Generator (Format 1:1 & 9:16)'),
                  _buildFeatureRow('Deteksi Mitigasi Kamar Kosong H-30'),
                  _buildFeatureRow('Papan Pengumuman & Notifikasi Paket Kurir (FCM)'),
                  const SizedBox(height: 14),

                  // Opsi Durasi Langganan
                  const Text('Pilih Siklus Langganan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => setDialogState(() => selectedDuration = 1),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selectedDuration == 1 ? const Color(0xFFEFF6FF) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selectedDuration == 1 ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                          width: selectedDuration == 1 ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedDuration == 1 ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: const Color(0xFF2563EB),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Paket Bulanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Rp 50.000 / bulan', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => setDialogState(() => selectedDuration = 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selectedDuration == 12 ? const Color(0xFFEFF6FF) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selectedDuration == 12 ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                          width: selectedDuration == 12 ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedDuration == 12 ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: const Color(0xFF2563EB),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('Paket Tahunan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    SizedBox(width: 6),
                                    Text('🎉 HEMAT 2 BULAN',
                                        style: TextStyle(
                                            color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Text('Rp 500.000 / tahun (Bayar 10 bulan dapat 12 bulan)',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
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
                child: const Text('Nanti Saja', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  final kostId = widget.kostId;
                  if (kostId == null || kostId.isEmpty) return;

                  final success = await KosService.upgradeKostSubscription(
                    kostId: kostId,
                    tier: SubscriptionTier.juragan,
                    months: selectedDuration,
                  );

                  if (mounted) {
                    if (success) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('🎉 Selamat! Kos Anda berhasil di-upgrade ke Paket Juragan! Kuota 25 kamar aktif.'),
                          backgroundColor: Color(0xFF16A34A),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      _loadRooms();
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Gagal melakukan upgrade paket. Coba lagi nanti.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Aktifkan Paket Juragan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
          ),
        ],
      ),
    );
  }

  // Dialog Tambah Kamar Baru
  void _showAddRoomDialog() {
    // Validasi kuota paket sebelum membuka form (PRD v2.0.0 Modul 3)
    final maxRooms = _kostModel?.maxRooms ?? 5;
    if (_rooms.length >= maxRooms) {
      _showUpgradeDialog();
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nomorController = TextEditingController();
    final hargaController = TextEditingController(text: '1500000');
    String selectedTipe = 'Standard';
    String selectedStatus = 'kosong';

    final List<String> availableFacilities = [
      'AC',
      'Kamar Mandi Dalam',
      'WiFi Cepat',
      'Kasur Springbed',
      'Lemari Pakaian',
      'Meja & Kursi Belajar',
      'Air Panas',
      'Jendela Luar',
    ];

    final Set<String> selectedFacilities = {
      'AC',
      'Kamar Mandi Dalam',
      'WiFi Cepat',
      'Kasur Springbed',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tambah Kamar Baru',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Nomor Kamar
                      TextFormField(
                        controller: nomorController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Nomor / Nama Kamar',
                          hintText: 'Contoh: Kamar 01, Kamar A2',
                          prefixIcon: const Icon(Icons.meeting_room_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Nomor kamar wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),

                      // Tipe Kamar & Status
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedTipe,
                              decoration: InputDecoration(
                                labelText: 'Tipe Kamar',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Standard', child: Text('Standard')),
                                DropdownMenuItem(value: 'Deluxe', child: Text('Deluxe')),
                                DropdownMenuItem(value: 'VIP', child: Text('VIP')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedTipe = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedStatus,
                              decoration: InputDecoration(
                                labelText: 'Status Awal',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'kosong', child: Text('Kosong')),
                                DropdownMenuItem(value: 'terisi', child: Text('Terisi')),
                                DropdownMenuItem(value: 'perbaikan', child: Text('Perbaikan')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedStatus = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Tarif Bulanan
                      TextFormField(
                        controller: hargaController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Tarif Sewa Bulanan (Rp)',
                          prefixText: 'Rp ',
                          prefixIcon: const Icon(Icons.payments_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || double.tryParse(value.trim()) == null) {
                            return 'Nominal tarif tidak valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Fasilitas Pilihan Cepat
                      const Text(
                        'Pilih Fasilitas Kamar (Preset Cepat):',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: availableFacilities.map((facility) {
                          final isSelected = selectedFacilities.contains(facility);
                          return FilterChip(
                            label: Text(facility, style: const TextStyle(fontSize: 12)),
                            selected: isSelected,
                            selectedColor: const Color(0xFFEFF6FF),
                            checkmarkColor: const Color(0xFF1E40AF),
                            labelStyle: TextStyle(
                              color: isSelected ? const Color(0xFF1E40AF) : const Color(0xFF475569),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  selectedFacilities.add(facility);
                                } else {
                                  selectedFacilities.remove(facility);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Tombol Simpan
                      ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          final noKamarInput = nomorController.text.trim();
                          final double harga = double.tryParse(hargaController.text.trim()) ?? 1500000;

                          navigator.pop();

                          final success = await KosService.addRoom(
                            kostId: widget.kostId ?? '',
                            nomorKamar: noKamarInput,
                            tipe: selectedTipe,
                            hargaBulanan: harga,
                            fasilitas: selectedFacilities.toList(),
                            status: selectedStatus,
                          );

                          if (mounted) {
                            if (success) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Kamar $noKamarInput berhasil ditambahkan!'),
                                  backgroundColor: const Color(0xFF059669),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              _loadRooms();
                            } else {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Gagal menambahkan kamar. Periksa koneksi.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Simpan Kamar ke Database', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Pasang Kamar Preset Default Kos Princess (10 Kamar Siap Pakai)
  Future<void> _populateDefaultPresetRooms() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pasang Preset Kamar Kos Princess?'),
        content: const Text(
          'Sistem akan otomatis membuat 10 kamar contoh Kos Princess (Kamar 01 s/d 10) lengkap dengan harga dan fasilitas default.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF)),
            child: const Text('Pasang Preset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final defaultRooms = [
      {'no': 'Kamar 01', 'tipe': 'Standard', 'harga': 1250000.0, 'status': 'terisi'},
      {'no': 'Kamar 02', 'tipe': 'Standard', 'harga': 1250000.0, 'status': 'kosong'},
      {'no': 'Kamar 03', 'tipe': 'Standard', 'harga': 1250000.0, 'status': 'terisi'},
      {'no': 'Kamar 04', 'tipe': 'Deluxe', 'harga': 1500000.0, 'status': 'kosong'},
      {'no': 'Kamar 05', 'tipe': 'Deluxe', 'harga': 1500000.0, 'status': 'terisi'},
      {'no': 'Kamar 06', 'tipe': 'Deluxe', 'harga': 1500000.0, 'status': 'kosong'},
      {'no': 'Kamar 07', 'tipe': 'VIP', 'harga': 1800000.0, 'status': 'terisi'},
      {'no': 'Kamar 08', 'tipe': 'VIP', 'harga': 1800000.0, 'status': 'akan_kosong'},
      {'no': 'Kamar 09', 'tipe': 'Standard', 'harga': 1250000.0, 'status': 'kosong'},
      {'no': 'Kamar 10', 'tipe': 'Standard', 'harga': 1250000.0, 'status': 'perbaikan'},
    ];

    for (var r in defaultRooms) {
      await KosService.addRoom(
        kostId: widget.kostId ?? '',
        nomorKamar: r['no'] as String,
        tipe: r['tipe'] as String,
        hargaBulanan: r['harga'] as double,
        fasilitas: ['AC', 'Kamar Mandi Dalam', 'WiFi Cepat', 'Kasur Springbed', 'Lemari'],
        status: r['status'] as String,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('10 Kamar preset Kos Princess berhasil dipasang!'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadRooms();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Manajemen Kamar • ${widget.kosName}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E40AF)),
            tooltip: 'Segarkan',
            onPressed: _loadRooms,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRoomDialog,
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Kamar', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Kuota & Tier Banner (PRD v2.0.0 2-Tier Pricing)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _kostModel?.isJuragan == true ? const Color(0xFFDBEAFE) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _kostModel?.isJuragan == true ? Icons.star_rounded : Icons.inventory_2_outlined,
                    color: _kostModel?.isJuragan == true ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    size: 20,
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
                            _kostModel?.tier.label ?? 'Paket Starter',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${_rooms.length} / ${_kostModel?.maxRooms ?? 5} Kamar)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _rooms.length >= (_kostModel?.maxRooms ?? 5) ? Colors.red.shade700 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_kostModel?.maxRooms ?? 5) > 0
                              ? (_rooms.length / (_kostModel?.maxRooms ?? 5)).clamp(0.0, 1.0)
                              : 0.0,
                          backgroundColor: const Color(0xFFCBD5E1),
                          color: _rooms.length >= (_kostModel?.maxRooms ?? 5)
                              ? Colors.red.shade600
                              : const Color(0xFF2563EB),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_kostModel?.isStarter == true) ...[
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _showUpgradeDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Upgrade', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),

          // Filter Status Kamar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildFilterChip('semua', 'Semua (${_rooms.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('kosong', 'Kosong'),
                const SizedBox(width: 8),
                _buildFilterChip('terisi', 'Terisi'),
                const SizedBox(width: 8),
                _buildFilterChip('perbaikan', 'Perbaikan'),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Daftar Kamar
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)))
                : _filteredRooms.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.bed_outlined, size: 52, color: Color(0xFF1E40AF)),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Belum Ada Kamar Terdaftar',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Anda bisa menambahkan kamar satu per satu atau pasang preset kamar Kos Princess siap pakai.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                onPressed: _populateDefaultPresetRooms,
                                icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFD97706)),
                                label: const Text('Pasang Preset Kamar Kos Princess (10 Kamar)'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1E40AF),
                                  side: const BorderSide(color: Color(0xFF93C5FD)),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: _filteredRooms.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final room = _filteredRooms[index];
                          return _buildRoomCard(room);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E40AF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final status = (room['status'] ?? 'kosong').toString();
    final harga = (room['harga_bulanan'] ?? 0).toDouble();
    final noKamar = room['nomor_kamar'] ?? '-';
    final tipe = room['tipe'] ?? 'Standard';
    final fasilitas = (room['fasilitas'] as List<dynamic>?)?.cast<String>() ?? [];

    Color badgeColor;
    Color badgeTextColor;
    String statusLabel;

    switch (status) {
      case 'terisi':
        badgeColor = const Color(0xFFDCFCE7);
        badgeTextColor = const Color(0xFF166534);
        statusLabel = 'Terisi';
        break;
      case 'perbaikan':
        badgeColor = const Color(0xFFFEE2E2);
        badgeTextColor = const Color(0xFF991B1B);
        statusLabel = 'Perbaikan';
        break;
      case 'akan_kosong':
        badgeColor = const Color(0xFFFEF3C7);
        badgeTextColor = const Color(0xFF92400E);
        statusLabel = 'Akan Kosong (H-30)';
        break;
      default:
        badgeColor = const Color(0xFFEFF6FF);
        badgeTextColor = const Color(0xFF1E40AF);
        statusLabel = 'Kosong';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.meeting_room_rounded, color: Color(0xFF1E40AF), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        noKamar,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        tipe,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeTextColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Rp ${harga.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} / bulan',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
          ),
          if (fasilitas.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: fasilitas.take(4).map((f) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(f, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
