import 'package:flutter/material.dart';

/// Kategori resmi pengumuman digital sesuai PRD Modul 9
enum AnnouncementCategory {
  paket,
  barangHilang,
  infoOperasional,
  umum;

  String get code {
    switch (this) {
      case AnnouncementCategory.paket:
        return 'paket';
      case AnnouncementCategory.barangHilang:
        return 'barang_hilang';
      case AnnouncementCategory.infoOperasional:
        return 'info_operasional';
      case AnnouncementCategory.umum:
        return 'umum';
    }
  }

  static AnnouncementCategory fromCode(String? code) {
    switch (code?.toLowerCase()) {
      case 'barang_hilang':
        return AnnouncementCategory.barangHilang;
      case 'info_operasional':
        return AnnouncementCategory.infoOperasional;
      case 'umum':
        return AnnouncementCategory.umum;
      case 'paket':
      default:
        return AnnouncementCategory.paket;
    }
  }
}

/// Model Entitas Papan Pengumuman Digital & Paket Kurir Tiba (PRD Modul 9)
class AnnouncementModel {
  final String id;
  final String kostId;
  final String authorId;
  final String? targetRoomId;
  final String kategori; // 'paket' | 'barang_hilang' | 'info_operasional' | 'umum'
  final String judul;
  final String deskripsi;
  final List<String> fotoUrls;
  final bool isPinned;
  final bool isResolved;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Atribut gabungan hasil kueri relasi (Joins)
  final String? authorName;
  final String? authorRole;
  final String? targetRoomNumber;
  final String? targetRoomType;

  const AnnouncementModel({
    required this.id,
    required this.kostId,
    required this.authorId,
    this.targetRoomId,
    required this.kategori,
    required this.judul,
    required this.deskripsi,
    this.fotoUrls = const [],
    this.isPinned = false,
    this.isResolved = false,
    required this.createdAt,
    this.updatedAt,
    this.authorName,
    this.authorRole,
    this.targetRoomNumber,
    this.targetRoomType,
  });

  bool get isPaket => kategori == 'paket';
  bool get isBarangHilang => kategori == 'barang_hilang';
  bool get isInfoOperasional => kategori == 'info_operasional';
  bool get isUmum => kategori == 'umum';
  bool get isBroadcast => targetRoomId == null || targetRoomId!.isEmpty;
  bool get hasPhoto => fotoUrls.isNotEmpty;
  String? get primaryPhotoUrl => fotoUrls.isNotEmpty ? fotoUrls.first : null;

  /// Label kategori dalam Bahasa Indonesia yang ramah pengguna
  String get kategoriLabel {
    switch (kategori.toLowerCase()) {
      case 'paket':
        return 'Paket Kurir Tiba';
      case 'barang_hilang':
        return 'Barang Tercecer / Hilang';
      case 'info_operasional':
        return 'Info Operasional Kos';
      case 'umum':
      default:
        return 'Pengumuman Umum';
    }
  }

  /// Warna aksen kartu berdasarkan kategori
  Color get kategoriColor {
    switch (kategori.toLowerCase()) {
      case 'paket':
        return const Color(0xFF2563EB); // Biru kurir/ekspres
      case 'barang_hilang':
        return const Color(0xFFEA580C); // Jingga peringatan
      case 'info_operasional':
        return const Color(0xFFDC2626); // Merah darurat/penting
      case 'umum':
      default:
        return const Color(0xFF059669); // Hijau komunitas
    }
  }

  /// Warna latar lembut untuk chip & badge
  Color get kategoriBgColor {
    switch (kategori.toLowerCase()) {
      case 'paket':
        return const Color(0xFFEFF6FF);
      case 'barang_hilang':
        return const Color(0xFFFFF7ED);
      case 'info_operasional':
        return const Color(0xFFFEF2F2);
      case 'umum':
      default:
        return const Color(0xFFECFDF5);
    }
  }

  /// Ikon representatif
  IconData get kategoriIcon {
    switch (kategori.toLowerCase()) {
      case 'paket':
        return Icons.inventory_2_rounded;
      case 'barang_hilang':
        return Icons.search_rounded;
      case 'info_operasional':
        return Icons.warning_amber_rounded;
      case 'umum':
      default:
        return Icons.campaign_rounded;
    }
  }

  /// Format waktu relatif bahasa Indonesia
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays == 1) {
      return 'Kemarin, ${_pad(createdAt.hour)}:${_pad(createdAt.minute)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      return '${_pad(createdAt.day)}/${_pad(createdAt.month)}/${createdAt.year}';
    }
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  factory AnnouncementModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedCreated;
    try {
      final c = map['created_at']?.toString() ?? '';
      parsedCreated = DateTime.tryParse(c) ?? DateTime.now();
    } catch (_) {
      parsedCreated = DateTime.now();
    }

    DateTime? parsedUpdated;
    try {
      final u = map['updated_at']?.toString();
      if (u != null && u.isNotEmpty) {
        parsedUpdated = DateTime.tryParse(u);
      }
    } catch (_) {}

    // Parsing foto_urls aman (bisa List dynamic, List String, atau null)
    List<String> parsedFotos = [];
    if (map['foto_urls'] is List) {
      parsedFotos = (map['foto_urls'] as List)
          .map((item) => item?.toString() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }

    // Parsing relasi kamar
    String? roomNum;
    String? roomType;
    if (map['rooms'] is Map<String, dynamic>) {
      final roomMap = map['rooms'] as Map<String, dynamic>;
      roomNum = roomMap['nomor_kamar']?.toString();
      roomType = roomMap['tipe']?.toString();
    }

    // Parsing relasi author profil
    String? authName;
    String? authRole;
    if (map['profiles'] is Map<String, dynamic>) {
      final profMap = map['profiles'] as Map<String, dynamic>;
      authName = profMap['full_name']?.toString();
      authRole = profMap['role']?.toString();
    }

    return AnnouncementModel(
      id: map['id']?.toString() ?? '',
      kostId: map['kost_id']?.toString() ?? '',
      authorId: map['author_id']?.toString() ?? '',
      targetRoomId: map['target_room_id']?.toString(),
      kategori: map['kategori']?.toString() ?? 'paket',
      judul: map['judul']?.toString() ?? '',
      deskripsi: map['deskripsi']?.toString() ?? '',
      fotoUrls: parsedFotos,
      isPinned: map['is_pinned'] == true,
      isResolved: map['is_resolved'] == true,
      createdAt: parsedCreated,
      updatedAt: parsedUpdated,
      authorName: authName,
      authorRole: authRole,
      targetRoomNumber: roomNum,
      targetRoomType: roomType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'kost_id': kostId,
      'author_id': authorId,
      'target_room_id': targetRoomId,
      'kategori': kategori,
      'judul': judul,
      'deskripsi': deskripsi,
      'foto_urls': fotoUrls,
      'is_pinned': isPinned,
      'is_resolved': isResolved,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  AnnouncementModel copyWith({
    String? id,
    String? kostId,
    String? authorId,
    String? targetRoomId,
    String? kategori,
    String? judul,
    String? deskripsi,
    List<String>? fotoUrls,
    bool? isPinned,
    bool? isResolved,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? authorName,
    String? authorRole,
    String? targetRoomNumber,
    String? targetRoomType,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      kostId: kostId ?? this.kostId,
      authorId: authorId ?? this.authorId,
      targetRoomId: targetRoomId ?? this.targetRoomId,
      kategori: kategori ?? this.kategori,
      judul: judul ?? this.judul,
      deskripsi: deskripsi ?? this.deskripsi,
      fotoUrls: fotoUrls ?? this.fotoUrls,
      isPinned: isPinned ?? this.isPinned,
      isResolved: isResolved ?? this.isResolved,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      targetRoomNumber: targetRoomNumber ?? this.targetRoomNumber,
      targetRoomType: targetRoomType ?? this.targetRoomType,
    );
  }
}
