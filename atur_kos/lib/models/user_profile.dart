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

  const UserProfile({
    required this.id,
    required this.fullName,
    this.email,
    this.nomorWa,
    this.avatarUrl,
    required this.role,
    this.kostId,
    this.createdAt,
  });

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

    return UserProfile(
      id: map['id'] as String? ?? '',
      fullName: name,
      email: fallbackEmail,
      nomorWa: map['nomor_wa'] as String? ?? metadata?['nomor_wa'] as String?,
      avatarUrl: map['avatar_url'] as String? ?? metadata?['avatar_url'] as String? ?? metadata?['picture'] as String?,
      role: UserRole.fromString(roleRaw),
      kostId: map['kost_id'] as String?,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  UserProfile copyWith({
    String? fullName,
    String? nomorWa,
    String? avatarUrl,
    UserRole? role,
    String? kostId,
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
    );
  }
}
