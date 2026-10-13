/// Status Verifikasi Properti Kos oleh Super Admin (PRD v2.0.0)
enum KostStatus {
  pendingVerification,
  active,
  rejected,
  suspended;

  static KostStatus fromString(String? val) {
    if (val != null) {
      final clean = val.trim().toLowerCase();
      if (clean == 'active' || clean == 'aktif') {
        return KostStatus.active;
      }
      if (clean == 'rejected' || clean == 'ditolak') {
        return KostStatus.rejected;
      }
      if (clean == 'suspended' || clean == 'dibekukan') {
        return KostStatus.suspended;
      }
    }
    return KostStatus.pendingVerification;
  }

  String get value {
    switch (this) {
      case KostStatus.active:
        return 'active';
      case KostStatus.rejected:
        return 'rejected';
      case KostStatus.suspended:
        return 'suspended';
      case KostStatus.pendingVerification:
        return 'pending_verification';
    }
  }

  String get label {
    switch (this) {
      case KostStatus.active:
        return 'Terverifikasi Aktif';
      case KostStatus.rejected:
        return 'Ditolak';
      case KostStatus.suspended:
        return 'Dibekukan';
      case KostStatus.pendingVerification:
        return 'Menunggu Verifikasi';
    }
  }
}

/// Tier Paket Langganan Properti Kos (2-Tier Freemium PRD v2.0.0)
enum SubscriptionTier {
  starter,
  juragan;

  static SubscriptionTier fromString(String? val) {
    if (val != null && val.trim().toLowerCase() == 'juragan') {
      return SubscriptionTier.juragan;
    }
    return SubscriptionTier.starter;
  }

  String get value => this == SubscriptionTier.juragan ? 'juragan' : 'starter';

  String get label => this == SubscriptionTier.juragan ? 'Paket Juragan' : 'Paket Starter (Gratis)';

  int get defaultMaxRooms => this == SubscriptionTier.juragan ? 25 : 5;
}

/// Model Data Properti Kos Multi-Tenant
class KostModel {
  final String id;
  final String namaKost;
  final String alamat;
  final String nomorKontak;
  final String? rekeningBank;
  final String? namaPemilikRekening;
  final String? kodeKost;
  final double? latitude;
  final double? longitude;
  final String? googleMapsUrl;
  final String? fotoBangunanUrl;
  final String? dokumenKtpUrl;
  final KostStatus statusVerifikasi;
  final String? catatanVerifikasiAdmin;
  final DateTime? diverifikasiPada;
  final SubscriptionTier tier;
  final int maxRooms;
  final DateTime? subscriptionExpiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const KostModel({
    required this.id,
    required this.namaKost,
    required this.alamat,
    required this.nomorKontak,
    this.rekeningBank,
    this.namaPemilikRekening,
    this.kodeKost,
    this.latitude,
    this.longitude,
    this.googleMapsUrl,
    this.fotoBangunanUrl,
    this.dokumenKtpUrl,
    this.statusVerifikasi = KostStatus.pendingVerification,
    this.catatanVerifikasiAdmin,
    this.diverifikasiPada,
    this.tier = SubscriptionTier.starter,
    this.maxRooms = 5,
    this.subscriptionExpiresAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => statusVerifikasi == KostStatus.active;
  bool get isPending => statusVerifikasi == KostStatus.pendingVerification;
  bool get isRejected => statusVerifikasi == KostStatus.rejected;
  bool get isSuspended => statusVerifikasi == KostStatus.suspended;
  bool get isJuragan => tier == SubscriptionTier.juragan;
  bool get isStarter => tier == SubscriptionTier.starter;

  factory KostModel.fromMap(Map<String, dynamic> map) {
    double? parseCoord(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    final tier = SubscriptionTier.fromString(map['tier']?.toString());
    final rawMax = map['max_rooms'];
    final maxRooms = rawMax is int
        ? rawMax
        : (int.tryParse(rawMax?.toString() ?? '') ?? tier.defaultMaxRooms);

    return KostModel(
      id: map['id']?.toString() ?? '',
      namaKost: map['nama_kost']?.toString() ?? 'Kos',
      alamat: map['alamat']?.toString() ?? '',
      nomorKontak: map['nomor_kontak']?.toString() ?? '',
      rekeningBank: map['rekening_bank']?.toString(),
      namaPemilikRekening: map['nama_pemilik_rekening']?.toString(),
      kodeKost: map['kode_kost']?.toString(),
      latitude: parseCoord(map['latitude']),
      longitude: parseCoord(map['longitude']),
      googleMapsUrl: map['google_maps_url']?.toString(),
      fotoBangunanUrl: map['foto_bangunan_url']?.toString(),
      dokumenKtpUrl: map['dokumen_ktp_url']?.toString(),
      statusVerifikasi: KostStatus.fromString(map['status_verifikasi']?.toString()),
      catatanVerifikasiAdmin: map['catatan_verifikasi_admin']?.toString(),
      diverifikasiPada: parseDate(map['diverifikasi_pada']),
      tier: tier,
      maxRooms: maxRooms,
      subscriptionExpiresAt: parseDate(map['subscription_expires_at']),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama_kost': namaKost,
      'alamat': alamat,
      'nomor_kontak': nomorKontak,
      'rekening_bank': rekeningBank,
      'nama_pemilik_rekening': namaPemilikRekening,
      if (kodeKost != null) 'kode_kost': kodeKost,
      'latitude': latitude,
      'longitude': longitude,
      'google_maps_url': googleMapsUrl,
      'foto_bangunan_url': fotoBangunanUrl,
      'dokumen_ktp_url': dokumenKtpUrl,
      'status_verifikasi': statusVerifikasi.value,
      'catatan_verifikasi_admin': catatanVerifikasiAdmin,
      'diverifikasi_pada': diverifikasiPada?.toIso8601String(),
      'tier': tier.value,
      'max_rooms': maxRooms,
      'subscription_expires_at': subscriptionExpiresAt?.toIso8601String(),
    };
  }

  KostModel copyWith({
    String? id,
    String? namaKost,
    String? alamat,
    String? nomorKontak,
    String? rekeningBank,
    String? namaPemilikRekening,
    String? kodeKost,
    double? latitude,
    double? longitude,
    String? googleMapsUrl,
    String? fotoBangunanUrl,
    String? dokumenKtpUrl,
    KostStatus? statusVerifikasi,
    String? catatanVerifikasiAdmin,
    DateTime? diverifikasiPada,
    SubscriptionTier? tier,
    int? maxRooms,
    DateTime? subscriptionExpiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KostModel(
      id: id ?? this.id,
      namaKost: namaKost ?? this.namaKost,
      alamat: alamat ?? this.alamat,
      nomorKontak: nomorKontak ?? this.nomorKontak,
      rekeningBank: rekeningBank ?? this.rekeningBank,
      namaPemilikRekening: namaPemilikRekening ?? this.namaPemilikRekening,
      kodeKost: kodeKost ?? this.kodeKost,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      googleMapsUrl: googleMapsUrl ?? this.googleMapsUrl,
      fotoBangunanUrl: fotoBangunanUrl ?? this.fotoBangunanUrl,
      dokumenKtpUrl: dokumenKtpUrl ?? this.dokumenKtpUrl,
      statusVerifikasi: statusVerifikasi ?? this.statusVerifikasi,
      catatanVerifikasiAdmin: catatanVerifikasiAdmin ?? this.catatanVerifikasiAdmin,
      diverifikasiPada: diverifikasiPada ?? this.diverifikasiPada,
      tier: tier ?? this.tier,
      maxRooms: maxRooms ?? this.maxRooms,
      subscriptionExpiresAt: subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
