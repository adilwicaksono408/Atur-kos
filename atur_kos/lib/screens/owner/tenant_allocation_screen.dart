import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:atur_kos/services/kos_service.dart';
import 'package:atur_kos/utils/format_utils.dart';
import 'package:url_launcher/url_launcher.dart';

/// Halaman Alokasi Kamar & Manajemen Penghuni (PRD Modul 2 - US-2.2)
/// Menghubungkan akun penghuni terdaftar ke kamar kosong
class TenantAllocationScreen extends StatefulWidget {
  final String? kostId;
  final String kosName;

  const TenantAllocationScreen({
    super.key,
    required this.kostId,
    required this.kosName,
  });

  @override
  State<TenantAllocationScreen> createState() => _TenantAllocationScreenState();
}

class _TenantAllocationScreenState extends State<TenantAllocationScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeTenants = [];
  List<Map<String, dynamic>> _unallocatedProfiles = [];
  List<Map<String, dynamic>> _emptyRooms = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      KosService.getActiveTenants(widget.kostId),
      KosService.getUnallocatedTenants(widget.kostId),
      KosService.getRooms(widget.kostId),
    ]);

    if (mounted) {
      final allRooms = results[2];
      setState(() {
        _activeTenants = results[0];
        _unallocatedProfiles = results[1].where((p) {
          final role = p['role']?.toString().toLowerCase().trim();
          final email = p['email']?.toString().toLowerCase().trim() ?? '';
          final name = (p['full_name'] ?? p['nama'] ?? p['name'])?.toString().toLowerCase().trim() ?? '';
          return role != 'super_admin' &&
              role != 'owner' &&
              !email.contains('wicaksonoadil768') &&
              !name.contains('wicaksonoadil768');
        }).toList();
        _emptyRooms = allRooms.where((r) => r['status'] == 'kosong').toList();
        _isLoading = false;
      });
    }
  }

  String _resolveProfileName(Map<String, dynamic> p) {
    final candidates = [
      p['full_name'],
      p['nama'],
      p['name'],
      p['nama_lengkap'],
      p['display_name'],
    ];

    for (final c in candidates) {
      if (c != null &&
          c.toString().trim().isNotEmpty &&
          c.toString().trim().toLowerCase() != 'calon penghuni') {
        return c.toString().trim();
      }
    }

    if (p['email'] != null && p['email'].toString().trim().isNotEmpty) {
      final emailStr = p['email'].toString().trim();
      return emailStr.split('@').first;
    }

    return 'Calon Penghuni';
  }

  /// Dialog Form Alokasi Penghuni ke Kamar Kosong
  Future<void> _showAllocationDialog([Map<String, dynamic>? preselectedProfile]) async {
    if (_emptyRooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua kamar saat ini terisi atau belum ada kamar tersedia.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    if (_unallocatedProfiles.isEmpty && preselectedProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Belum ada akun calon penghuni baru yang mendaftar. Bagikan Kode Undangan kos Anda terlebih dahulu.',
          ),
          backgroundColor: Color(0xFF1E40AF),
        ),
      );
      return;
    }

    Map<String, dynamic>? selectedRoom = _emptyRooms.first;
    Map<String, dynamic>? selectedProfile = preselectedProfile ??
        (_unallocatedProfiles.isNotEmpty ? _unallocatedProfiles.first : null);
    DateTime tanggalMasuk = DateTime.now();
    int tanggalJatuhTempo = 1;
    final hargaController = TextEditingController(
      text: ((selectedRoom['harga_bulanan'] as num?)?.toDouble() ?? 1000000)
          .round()
          .toString(),
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF1E40AF)),
                SizedBox(width: 8),
                Text('Alokasi Kamar'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pilih Akun Penghuni', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: selectedProfile,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: () {
                      final list = List<Map<String, dynamic>>.from(_unallocatedProfiles);
                      if (selectedProfile != null && !list.any((p) => p['id'] == selectedProfile!['id'])) {
                        list.insert(0, selectedProfile!);
                      }
                      return list.map((p) {
                        final name = _resolveProfileName(p);
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: p,
                          child: Text(name),
                        );
                      }).toList();
                    }(),
                    onChanged: (val) {
                      setDialogState(() => selectedProfile = val);
                    },
                  ),
                  if (selectedProfile != null) _buildTenantKtpBanner(selectedProfile!),
                  const SizedBox(height: 14),
                  const Text('Pilih Kamar Kosong', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: selectedRoom,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _emptyRooms.map((r) {
                      final rNum = r['nomor_kamar']?.toString() ?? '-';
                      final rTipe = r['tipe']?.toString() ?? 'Standard';
                      return DropdownMenuItem(
                        value: r,
                        child: Text('Kamar $rNum ($rTipe)'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedRoom = val;
                        final price =
                            (val?['harga_bulanan'] as num?)?.toDouble() ?? 1000000;
                        hargaController.text = price.round().toString();
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Harga Sewa Disepakati (Rp)',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: hargaController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixText: 'Rp ',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Tanggal Mulai Sewa', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: tanggalMasuk,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() => tanggalMasuk = picked);
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
                          Text(FormatUtils.formatDate(tanggalMasuk)),
                          const Icon(Icons.calendar_month_rounded, size: 20, color: Color(0xFF1E40AF)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Siklus Jatuh Tempo Bulanan',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: tanggalJatuhTempo,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: List.generate(28, (i) => i + 1).map((day) {
                      return DropdownMenuItem(
                        value: day,
                        child: Text('Setiap Tanggal $day Tiap Bulan'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => tanggalJatuhTempo = val);
                      }
                    },
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
                  if (selectedProfile == null || selectedRoom == null) return;
                  final harga = double.tryParse(hargaController.text) ?? 0;
                  if (harga <= 0) return;

                  final userId = selectedProfile!['id'].toString();
                  final roomId = selectedRoom!['id'].toString();
                  final nomorKamar = selectedRoom!['nomor_kamar'].toString();
                  final kostId = widget.kostId ?? selectedRoom!['kost_id'].toString();

                  final success = await KosService.allocateRoom(
                    kostId: kostId,
                    userId: userId,
                    roomId: roomId,
                    hargaBulanan: harga,
                    nomorKamar: nomorKamar,
                    tanggalMasuk: tanggalMasuk,
                    tanggalJatuhTempo: tanggalJatuhTempo,
                  );

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Kamar $nomorKamar berhasil dialokasikan! Tagihan pertama otomatis terbit.'
                              : 'Gagal mengalokasikan kamar.',
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
                child: const Text('Simpan Alokasi'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Alokasi & Penghuni Aktif'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E40AF)),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAllocationDialog,
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Alokasi Kamar'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: Color(0xFF1E40AF), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Kamar Siap Huni vs Penghuni Baru',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_emptyRooms.length} Kamar Kosong Siap Alokasi • ${_unallocatedProfiles.length} Akun Calon Penghuni Menunggu',
                                style: const TextStyle(
                                  color: Color(0xFF1E40AF),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SECTION 1: CALON PENGHUNI MENUNGGU ALOKASI KAMAR
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Calon Penghuni Menunggu Alokasi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _unallocatedProfiles.isNotEmpty
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_unallocatedProfiles.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _unallocatedProfiles.isNotEmpty
                                    ? const Color(0xFFB45309)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_unallocatedProfiles.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person_search_rounded,
                                color: Color(0xFF1E40AF), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Belum ada calon penghuni yang menunggu',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Penghuni yang mendaftar atau memasukkan kode undangan kos (${widget.kosName}) akan langsung tampil di sini untuk Anda alokasikan.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._unallocatedProfiles.map((p) {
                      final name = _resolveProfileName(p);
                      final phone = p['nomor_wa']?.toString() ?? '-';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD97706).withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFFFEF3C7),
                              child: const Icon(Icons.person_add_rounded,
                                  color: Color(0xFFD97706)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFFBEB),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Menunggu Kamar',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFB45309),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildKtpStatusBadge(p),
                                      if (phone != '-') ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '• WA: $phone',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Lihat Identitas & Dokumen KTP',
                                  icon: Icon(
                                    _hasKtp(p) ? Icons.badge_rounded : Icons.badge_outlined,
                                    color: _hasKtp(p) ? const Color(0xFF16A34A) : Colors.grey.shade500,
                                    size: 22,
                                  ),
                                  onPressed: () => _showTenantKtpPreview(p),
                                ),
                                const SizedBox(width: 4),
                                ElevatedButton.icon(
                                  onPressed: () => _showAllocationDialog(p),
                                  icon: const Icon(Icons.meeting_room_rounded, size: 16),
                                  label: const Text('Alokasikan', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E40AF),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 20),

                  // SECTION 2: DAFTAR PENGHUNI AKTIF
                  const Text(
                    'Daftar Penghuni Aktif Menempati Kamar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_activeTenants.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(Icons.people_outline_rounded,
                                size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text(
                              'Belum ada penghuni aktif yang menempati kamar.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._activeTenants.map((t) {
                      final profile = t['profiles'] as Map<String, dynamic>?;
                      final room = t['rooms'] as Map<String, dynamic>?;
                      final tenantName = profile != null ? _resolveProfileName(profile) : 'Penghuni';
                      final roomNum = room?['nomor_kamar']?.toString() ?? '-';
                      final roomType = room?['tipe']?.toString() ?? 'Standard';
                      final price =
                          (room?['harga_bulanan'] as num?)?.toDouble() ?? 0.0;
                      final dueDateDay = t['tanggal_jatuh_tempo_bulanan'] ?? 1;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  const Color(0xFF1E40AF).withValues(alpha: 0.1),
                              child: const Icon(Icons.person_rounded,
                                  color: Color(0xFF1E40AF)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tenantName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Kamar $roomNum • $roomType • ${FormatUtils.rupiah(price)}/bln',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Jatuh tempo tiap tanggal $dueDateDay',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Text(
                                    'Aktif',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                                if (profile != null) ...[
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () => _showTenantKtpPreview(profile, roomNumber: roomNum),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _hasKtp(profile) ? Icons.badge_rounded : Icons.badge_outlined,
                                            size: 13,
                                            color: _hasKtp(profile) ? const Color(0xFF16A34A) : Colors.grey.shade500,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            _hasKtp(profile) ? 'KTP' : 'No KTP',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: _hasKtp(profile) ? const Color(0xFF16A34A) : Colors.grey.shade500,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  // ===========================================================================
  // HELPER & PREVIEW DOKUMEN KTP PENGHUNI
  // ===========================================================================

  bool _hasKtp(Map<String, dynamic> p) {
    final url = p['dokumen_ktp_url']?.toString() ?? p['foto_ktp_url']?.toString();
    return url != null && url.trim().isNotEmpty;
  }

  Widget _buildKtpStatusBadge(Map<String, dynamic> p) {
    final hasKtp = _hasKtp(p);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: hasKtp ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasKtp ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasKtp ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: hasKtp ? const Color(0xFF16A34A) : const Color(0xFFD97706),
            size: 11,
          ),
          const SizedBox(width: 3),
          Text(
            hasKtp ? 'KTP Terlampir' : 'Belum Ada KTP',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: hasKtp ? const Color(0xFF166534) : const Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantKtpBanner(Map<String, dynamic> p) {
    final hasKtp = _hasKtp(p);
    final nik = p['nik_ktp']?.toString() ?? '-';

    if (hasKtp) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Foto KTP Terlampir',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF166534)),
                  ),
                  Text(
                    'NIK: $nik',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _showTenantKtpPreview(p),
              icon: const Icon(Icons.visibility_rounded, size: 14),
              label: const Text('Lihat KTP', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF166534),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Perhatian: Calon penghuni belum mengunggah foto KTP. Anda tetap dapat melanjutkan alokasi kamar sekarang.',
              style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  void _showTenantKtpPreview(Map<String, dynamic> p, {String? roomNumber}) {
    final name = _resolveProfileName(p);
    final nik = p['nik_ktp']?.toString() ?? '-';
    final phone = p['nomor_wa']?.toString() ?? '-';
    final emergencyName = p['kontak_darurat_nama']?.toString();
    final emergencyWa = p['kontak_darurat_wa']?.toString();
    final ktpUrl = p['dokumen_ktp_url']?.toString() ?? p['foto_ktp_url']?.toString() ?? '';
    final hasKtp = ktpUrl.trim().isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 650),
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
                      const Icon(Icons.badge_rounded, color: Color(0xFF1E40AF), size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Identitas Penghuni: $name',
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
              if (hasKtp) ...[
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
                          child: _buildKtpImageWidget(ktpUrl),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 40, color: Color(0xFFD97706)),
                      const SizedBox(height: 8),
                      const Text(
                        'Foto KTP Belum Diunggah',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Penghuni belum melampirkan foto dokumen KTP di portal penghuni mereka.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (roomNumber != null) ...[
                      Text('Alokasi: Kamar $roomNumber',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF), fontSize: 13)),
                      const SizedBox(height: 4),
                    ],
                    Text('Nama Lengkap: $name', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Nomor NIK KTP: $nik', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    const SizedBox(height: 4),
                    Text('Nomor WhatsApp: $phone', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    if (emergencyName != null && emergencyName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Kontak Darurat: $emergencyName (${emergencyWa ?? "-"})',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (phone != '-' && phone.isNotEmpty) ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
                        if (clean.startsWith('0')) clean = '62${clean.substring(1)}';
                        final msg = Uri.encodeComponent(
                          'Halo Kak $name, mohon lengkapi identitas dan foto KTP Anda di aplikasi Atur Kos untuk verifikasi administrasi kos.',
                        );
                        final uri = Uri.parse('https://wa.me/$clean?text=$msg');
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (_) {}
                      },
                      icon: const Icon(Icons.chat_rounded, size: 16, color: Color(0xFF059669)),
                      label: const Text('Ingatkan via WA', style: TextStyle(fontSize: 12, color: Color(0xFF059669))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF059669)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKtpImageWidget(String url) {
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
