enum UserRole {
  superAdmin,
  owner,
  tenant;

  static UserRole fromString(String? role) {
    if (role != null) {
      final clean = role.trim().toLowerCase();
      if (clean == 'super_admin' || clean == 'superadmin') {
        return UserRole.superAdmin;
      }
      if (clean == 'owner') {
        return UserRole.owner;
      }
    }
    return UserRole.tenant;
  }

  String get value {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.owner:
        return 'owner';
      case UserRole.tenant:
        return 'tenant';
    }
  }

  String get label {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.owner:
        return 'Pemilik Kos';
      case UserRole.tenant:
        return 'Penghuni Kos';
    }
  }
}

/// Model Profil Pengguna Atur Kos
class UserProfile {
  final String id;
  final String fullName;
  final String? email;
  final String? nomorWa;
  final String? avatarUrl;
  final UserRole role;
  final String? kostId;
  final DateTime? createdAt;

  // Field Identitas KTP & Kontak Darurat (PRD Identitas Penghuni)
  final String? nikKtp;
  final String? dokumenKtpUrl;
  final String? kontakDaruratNama;
  final String? kontakDaruratWa;
  final String? statusIdentitas;

  const UserProfile({
    required this.id,
    required this.fullName,
    this.email,
    this.nomorWa,
    this.avatarUrl,
    required this.role,
    this.kostId,
    this.createdAt,
    this.nikKtp,
    this.dokumenKtpUrl,
    this.kontakDaruratNama,
    this.kontakDaruratWa,
    this.statusIdentitas,
  });

  bool get hasKtp => dokumenKtpUrl != null && dokumenKtpUrl!.trim().isNotEmpty;
  bool get hasNik => nikKtp != null && nikKtp!.trim().isNotEmpty;
  bool get isIdentityComplete => hasKtp && hasNik;

  /// Format sensor NIK untuk privasi (contoh: 3201**********34)
  String get maskedNik {
    if (nikKtp == null || nikKtp!.trim().isEmpty) return '-';
    final clean = nikKtp!.trim();
    if (clean.length <= 6) return clean;
    final prefix = clean.substring(0, 4);
    final suffix = clean.substring(clean.length - 2);
    final stars = '*' * (clean.length - 6);
    return '$prefix$stars$suffix';
  }

  factory UserProfile.fromMap(
    Map<String, dynamic> map, {
    String? fallbackEmail,
    Map<String, dynamic>? metadata,
  }) {
    // Ambil nama dari profil, fallback ke metadata auth
    String name = map['full_name'] as String? ?? '';
    if (name.isEmpty && metadata != null) {
      name = (metadata['full_name'] ?? metadata['name']) as String? ?? '';
    }
    if (name.isEmpty) {
      name = fallbackEmail ?? 'Pengguna';
    }

    // Role dari tabel atau metadata auth
    final roleRaw = map['role'] as String? ?? metadata?['role'] as String?;

    final nik = map['nik_ktp'] as String? ?? metadata?['nik_ktp'] as String?;
    final ktpUrl = map['dokumen_ktp_url'] as String? ??
        map['foto_ktp_url'] as String? ??
        metadata?['dokumen_ktp_url'] as String? ??
        metadata?['foto_ktp_url'] as String?;
    final emergencyName = map['kontak_darurat_nama'] as String? ??
        metadata?['kontak_darurat_nama'] as String?;
    final emergencyWa = map['kontak_darurat_wa'] as String? ??
        metadata?['kontak_darurat_wa'] as String?;
    final statusId = map['status_identitas'] as String? ??
        metadata?['status_identitas'] as String?;

    return UserProfile(
      id: map['id'] as String? ?? '',
      fullName: name,
      email: fallbackEmail,
      nomorWa: map['nomor_wa'] as String? ?? metadata?['nomor_wa'] as String?,
      avatarUrl: map['avatar_url'] as String? ??
          metadata?['avatar_url'] as String? ??
          metadata?['picture'] as String?,
      role: UserRole.fromString(roleRaw),
      kostId: map['kost_id'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      nikKtp: nik,
      dokumenKtpUrl: ktpUrl,
      kontakDaruratNama: emergencyName,
      kontakDaruratWa: emergencyWa,
      statusIdentitas: statusId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      if (email != null) 'email': email,
      if (nomorWa != null) 'nomor_wa': nomorWa,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'role': role.value,
      if (kostId != null) 'kost_id': kostId,
      if (nikKtp != null) 'nik_ktp': nikKtp,
      if (dokumenKtpUrl != null) 'dokumen_ktp_url': dokumenKtpUrl,
      if (kontakDaruratNama != null) 'kontak_darurat_nama': kontakDaruratNama,
      if (kontakDaruratWa != null) 'kontak_darurat_wa': kontakDaruratWa,
      if (statusIdentitas != null) 'status_identitas': statusIdentitas,
    };
  }

  UserProfile copyWith({
    String? fullName,
    String? nomorWa,
    String? avatarUrl,
    UserRole? role,
    String? kostId,
    String? nikKtp,
    String? dokumenKtpUrl,
    String? kontakDaruratNama,
    String? kontakDaruratWa,
    String? statusIdentitas,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email,
      nomorWa: nomorWa ?? this.nomorWa,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      kostId: kostId ?? this.kostId,
      createdAt: createdAt,
      nikKtp: nikKtp ?? this.nikKtp,
      dokumenKtpUrl: dokumenKtpUrl ?? this.dokumenKtpUrl,
      kontakDaruratNama: kontakDaruratNama ?? this.kontakDaruratNama,
      kontakDaruratWa: kontakDaruratWa ?? this.kontakDaruratWa,
      statusIdentitas: statusIdentitas ?? this.statusIdentitas,
    );
  }
}
