import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:atur_kos/services/kos_service.dart';
import 'package:atur_kos/utils/format_utils.dart';

/// Halaman Manajemen Helpdesk & Tiket Keluhan Kerusakan Fasilitas (PRD Modul 4, US-4.3)
/// Pemilik dapat memantau, memfilter, dan memperbarui status pengerjaan komplain fasilitas kamar & umum
class ComplaintManagementScreen extends StatefulWidget {
  final String? kostId;
  final String kosName;

  const ComplaintManagementScreen({
    super.key,
    required this.kostId,
    required this.kosName,
  });

  @override
  State<ComplaintManagementScreen> createState() => _ComplaintManagementScreenState();
}

class _ComplaintManagementScreenState extends State<ComplaintManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _complaints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadComplaints();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadComplaints() async {
    setState(() => _isLoading = true);
    final data = await KosService.getComplaints(kostId: widget.kostId);
    if (mounted) {
      setState(() {
        _complaints = data;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filterComplaints(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return _complaints.where((c) => c['status'] == 'diajukan').toList();
      case 2:
        return _complaints.where((c) => c['status'] == 'sedang_dikerjakan').toList();
      case 3:
        return _complaints.where((c) => c['status'] == 'selesai').toList();
      default:
        return _complaints;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'sedang_dikerjakan':
        return const Color(0xFF2563EB); // Biru
      case 'selesai':
        return const Color(0xFF059669); // Hijau
      case 'diajukan':
      default:
        return const Color(0xFFDC2626); // Merah
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'sedang_dikerjakan':
        return 'Sedang Dikerjakan';
      case 'selesai':
        return 'Selesai';
      case 'diajukan':
      default:
        return 'Perlu Ditangani';
    }
  }

  /// Dialog untuk memperbarui status dan catatan penanganan tukang
  Future<void> _showUpdateStatusDialog(Map<String, dynamic> complaint) async {
    final complaintId = complaint['id'].toString();
    final currentStatus = complaint['status']?.toString() ?? 'diajukan';
    final initialNotes = complaint['catatan_penanganan']?.toString() ?? '';
    final notesController = TextEditingController(text: initialNotes);
    String selectedStatus = currentStatus == 'diajukan' ? 'sedang_dikerjakan' : 'selesai';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.build_circle_rounded, color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Update Status Perbaikan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  complaint['judul']?.toString() ?? 'Keluhan',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Ubah Status Menjadi:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'diajukan',
                      child: Text('Diajukan (Belum diproses)'),
                    ),
                    DropdownMenuItem(
                      value: 'sedang_dikerjakan',
                      child: Text('Sedang Dikerjakan (Tukang ditugaskan)'),
                    ),
                    DropdownMenuItem(
                      value: 'selesai',
                      child: Text('Selesai (Fasilitas telah diperbaiki)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedStatus = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Catatan Teknisi / Progres Penanganan:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Tukang Pak Slamet dijadwalkan datang besok jam 10.00 membawa kran baru.',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Simpan Progres'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final success = await KosService.updateComplaintStatus(
        complaintId: complaintId,
        status: selectedStatus,
        catatanPenanganan: notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Status keluhan berhasil diperbarui menjadi "${_getStatusLabel(selectedStatus)}"'
                  : 'Gagal memperbarui status tiket.',
            ),
            backgroundColor: success ? const Color(0xFF059669) : Colors.red,
          ),
        );
        _loadComplaints();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _complaints.where((c) => c['status'] == 'diajukan').length;
    final inProgressCount = _complaints.where((c) => c['status'] == 'sedang_dikerjakan').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Helpdesk & Tiket Keluhan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
            ),
            Text(
              '${widget.kosName} • Kerusakan Fasilitas',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E40AF)),
            onPressed: _loadComplaints,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1E40AF),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF1E40AF),
          indicatorWeight: 3,
          isScrollable: true,
          tabs: [
            Tab(text: 'Semua (${_complaints.length})'),
            Tab(
              child: Row(
                children: [
                  const Text('Perlu Tindakan'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Text('Dikerjakan'),
                  if (inProgressCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$inProgressCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(text: 'Selesai (${_complaints.where((c) => c['status'] == 'selesai').length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)))
          : TabBarView(
              controller: _tabController,
              children: List.generate(4, (index) {
                final filtered = _filterComplaints(index);
                if (filtered.isEmpty) {
                  return _buildEmptyState(index);
                }
                return RefreshIndicator(
                  onRefresh: _loadComplaints,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, i) => _buildComplaintCard(filtered[i]),
                  ),
                );
              }),
            ),
    );
  }

  Widget _buildEmptyState(int index) {
    String message = 'Belum ada tiket keluhan yang dilaporkan.';
    if (index == 1) message = 'Hebat! Tidak ada keluhan yang perlu ditangani saat ini.';
    if (index == 2) message = 'Tidak ada keluhan yang sedang dalam pengerjaan tukang.';
    if (index == 3) message = 'Belum ada riwayat keluhan yang ditandai selesai.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_rounded, size: 48, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'diajukan';
    final scope = item['tipe_fasilitas']?.toString() ?? 'kamar_pribadi';
    final isGeneral = scope == 'fasilitas_umum';
    final title = item['judul']?.toString() ?? 'Kerusakan Fasilitas';
    final desc = item['deskripsi']?.toString() ?? '-';
    final notes = item['catatan_penanganan']?.toString();
    final createdAt = item['created_at']?.toString();
    final dateFormatted = createdAt != null ? FormatUtils.isoToDate(createdAt) : '-';

    // Info penghuni & kamar dari relational query
    final tenantData = item['tenants'] as Map<String, dynamic>?;
    final profileData = tenantData?['profiles'] as Map<String, dynamic>?;
    final roomData = tenantData?['rooms'] as Map<String, dynamic>?;
    final tenantName = profileData?['full_name']?.toString() ?? 'Penghuni';
    final roomNumber = roomData?['nomor_kamar']?.toString() ?? '-';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: status == 'diajukan' ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Cakupan & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isGeneral ? const Color(0xFFEDE9FE) : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isGeneral ? Icons.apartment_rounded : Icons.meeting_room_rounded,
                        size: 14,
                        color: isGeneral ? const Color(0xFF7C3AED) : const Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isGeneral ? 'Fasilitas Umum Kos' : 'Kamar $roomNumber (Pribadi)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isGeneral ? const Color(0xFF7C3AED) : const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _getStatusLabel(status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Judul & Deskripsi
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // Foto Lampiran Kerusakan (Opsional)
            ..._buildCardPhotoSection(item),

            const SizedBox(height: 12),

            // Catatan Penanganan Teknisi (jika ada)
            if (notes != null && notes.trim().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.handyman_rounded, size: 16, color: Color(0xFF475569)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Catatan Progres Teknisi:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            notes,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            // Footer: Pelapor & Aksi Update Status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pelapor: $tenantName • Kamar $roomNumber',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dibuat pada $dateFormatted',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showUpdateStatusDialog(item),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: Text(
                    status == 'diajukan'
                        ? 'Tugaskan'
                        : (status == 'sedang_dikerjakan' ? 'Selesaikan' : 'Edit Catatan'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status == 'diajukan'
                        ? const Color(0xFFDC2626)
                        : (status == 'sedang_dikerjakan' ? const Color(0xFF2563EB) : const Color(0xFF475569)),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCardPhotoSection(Map<String, dynamic> item) {
    final rawPhotos = item['foto_urls'];
    List<String> fotoUrls = [];
    if (rawPhotos is List) {
      fotoUrls = rawPhotos.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }

    if (fotoUrls.isEmpty) {
      return [
        Row(
          children: const [
            Icon(Icons.image_not_supported_outlined, size: 14, color: Color(0xFF94A3B8)),
            SizedBox(width: 6),
            Text(
              'Tidak ada foto bukti yang dilampirkan (opsional)',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ];
    }

    return [
      Row(
        children: [
          const Icon(Icons.photo_library_outlined, size: 14, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            'Foto Bukti Kerusakan (${fotoUrls.length}):',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            '• Ketuk untuk perbesar',
            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
          ),
        ],
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 85,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: fotoUrls.length,
          separatorBuilder: (_, index) => const SizedBox(width: 8),
          itemBuilder: (ctx, idx) {
            final photoUrl = fotoUrls[idx];
            return GestureDetector(
              onTap: () => _showFullScreenImage(context, photoUrl),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 85,
                      height: 85,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _buildComplaintImage(photoUrl, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.zoom_in_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _buildComplaintImage(String url, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(bytes, width: width, height: height, fit: fit);
      } catch (_) {
        return Container(
          width: width,
          height: height,
          color: const Color(0xFFF1F5F9),
          child: const Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8)),
        );
      }
    }
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        width: width,
        height: height,
        color: const Color(0xFFF1F5F9),
        child: const Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8)),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 520, maxWidth: 650),
                  color: Colors.black,
                  child: _buildComplaintImage(imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

