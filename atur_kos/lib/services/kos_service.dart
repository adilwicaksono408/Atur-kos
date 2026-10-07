import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Model Data Ringkasan Operasional Properti (KPI PRD Kos Princess)
class OperationalSummary {
  final int totalRooms;
  final int occupiedRooms;
  final int emptyRooms;
  final double occupancyRate;
  final double pemasukanKasRiil; // Cash Basis: Hanya invoice LUNAS yang terverifikasi
  final double totalTunggakan; // Akrual: Total tagihan belum bayar / lewat jatuh tempo
  final int tunggakanCount;
  final int overdueCount;
  final int pendingVerificationCount;
  final int activeComplaintsCount;

  const OperationalSummary({
    this.totalRooms = 0,
    this.occupiedRooms = 0,
    this.emptyRooms = 0,
    this.occupancyRate = 0.0,
    this.pemasukanKasRiil = 0.0,
    this.totalTunggakan = 0.0,
    this.tunggakanCount = 0,
    this.overdueCount = 0,
    this.pendingVerificationCount = 0,
    this.activeComplaintsCount = 0,
  });
}

/// Layanan terpusat untuk interaksi data Properti Kos, Kamar, Penghuni, Tagihan, dan Kas
class KosService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ===========================================================================
  // 1. PROFIL PROPERTI KOS
  // ===========================================================================

  /// Mengambil data profil kos berdasarkan kostId
  static Future<Map<String, dynamic>?> getKosProfile(String? kostId) async {
    try {
      if (kostId == null || kostId.isEmpty) {
        // Fallback mengambil kos default (Kos Princess)
        final fallback = await _client
            .from('kosts')
            .select()
            .order('created_at', ascending: true)
            .limit(1)
            .maybeSingle();
        return fallback;
      }

      final data = await _client
          .from('kosts')
          .select()
          .eq('id', kostId)
          .maybeSingle();
      return data;
    } catch (e) {
      return null;
    }
  }

  /// Memperbarui informasi profil properti kos & rekening pembayaran
  static Future<bool> updateKosProfile({
    required String kostId,
    required String namaKost,
    required String alamat,
    required String nomorKontak,
    String? rekeningBank,
    String? namaPemilikRekening,
    String? kodeKost,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'nama_kost': namaKost,
        'alamat': alamat,
        'nomor_kontak': nomorKontak,
        'rekening_bank': rekeningBank,
        'nama_pemilik_rekening': namaPemilikRekening,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (kodeKost != null && kodeKost.trim().isNotEmpty) {
        updateData['kode_kost'] = kodeKost.trim().toUpperCase();
      }
      await _client.from('kosts').update(updateData).eq('id', kostId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Menghubungkan akun penghuni ke properti kos berdasarkan kode undangan (PRD US-1.1 & Multi-tenant)
  static Future<Map<String, dynamic>?> joinKosByInvitationCode({
    required String userId,
    required String invitationCode,
    String? userName,
  }) async {
    try {
      final cleanCode = invitationCode.trim().toUpperCase();
      if (cleanCode.isEmpty) return null;

      // 1. Cari kos yang memiliki kode_kost ini
      var kosData = await _client
          .from('kosts')
          .select()
          .ilike('kode_kost', cleanCode)
          .maybeSingle();

      // Fallback: jika kode sama dengan nama kos
      kosData ??= await _client
          .from('kosts')
          .select()
          .ilike('nama_kost', cleanCode)
          .maybeSingle();

      // Fallback: jika kode 'PRINCESS' tapi kolom kode_kost di DB belum terisi
      if (kosData == null && cleanCode == 'PRINCESS') {
        kosData = await _client
            .from('kosts')
            .select()
            .order('created_at', ascending: true)
            .limit(1)
            .maybeSingle();
        if (kosData != null) {
          await _client.from('kosts').update({'kode_kost': 'PRINCESS'}).eq('id', kosData['id']);
        }
      }

      if (kosData == null) return null;

      final kostId = kosData['id'].toString();

      // 2. Pastikan profil pengguna ada dan terikat ke kost_id ini di tabel profiles (upsert)
      final authUser = _client.auth.currentUser;
      final existingProfile = await _client
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      final existingName = existingProfile?['full_name']?.toString().trim();
      final validExistingName = (existingName != null &&
              existingName.isNotEmpty &&
              existingName.toLowerCase() != 'calon penghuni')
          ? existingName
          : null;

      final metaName = authUser?.userMetadata?['full_name']?.toString().trim() ??
          authUser?.userMetadata?['name']?.toString().trim() ??
          authUser?.userMetadata?['nama']?.toString().trim();
      final validMetaName = (metaName != null &&
              metaName.isNotEmpty &&
              metaName.toLowerCase() != 'calon penghuni')
          ? metaName
          : null;

      final validPassedName = (userName != null &&
              userName.trim().isNotEmpty &&
              userName.trim().toLowerCase() != 'calon penghuni')
          ? userName.trim()
          : null;

      final fullName = validPassedName ??
          validExistingName ??
          validMetaName ??
          (authUser?.email != null ? authUser!.email!.split('@').first : null) ??
          'Calon Penghuni';

      final nomorWa = existingProfile?['nomor_wa']?.toString() ??
          authUser?.userMetadata?['nomor_wa']?.toString();

      await _client.from('profiles').upsert({
        'id': userId,
        'full_name': fullName,
        'role': 'tenant',
        'kost_id': kostId,
        if (nomorWa != null && nomorWa.isNotEmpty) 'nomor_wa': nomorWa,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 3. Update juga metadata sesi user di Supabase Auth
      try {
        await _client.auth.updateUser(
          UserAttributes(
            data: {
              'kost_id': kostId,
              'kode_kost': cleanCode,
              'role': 'tenant',
            },
          ),
        );
      } catch (_) {}

      return kosData;
    } catch (e) {
      debugPrint('Error joinKosByInvitationCode: $e');
      return null;
    }
  }

  // ===========================================================================
  // 2. RINGKASAN OPERASIONAL & KPI REAL-TIME (SESUAI PRD 5.3 & 5.6)
  // ===========================================================================

  /// Mengambil ringkasan operasional properti secara real-time dari database
  static Future<OperationalSummary> getOperationalSummary(String? kostId) async {
    try {
      String? resolvedKostId = kostId;
      if (resolvedKostId == null || resolvedKostId.isEmpty) {
        final profile = await getKosProfile(null);
        resolvedKostId = profile?['id']?.toString();
      }

      if (resolvedKostId == null) {
        return const OperationalSummary();
      }

      // 1. Data Kamar
      final roomsData = await _client
          .from('rooms')
          .select('status')
          .eq('kost_id', resolvedKostId);
      final roomsList = List<Map<String, dynamic>>.from(roomsData);

      final totalRooms = roomsList.length;
      final occupiedRooms =
          roomsList.where((r) => r['status'] == 'terisi').length;
      final emptyRooms =
          roomsList.where((r) => r['status'] == 'kosong').length;
      final occupancyRate =
          totalRooms > 0 ? (occupiedRooms / totalRooms) * 100 : 0.0;

      // 2. Data Tagihan & Kas (Invoices)
      final invoicesData = await _client
          .from('invoices')
          .select('status, nominal, tanggal_jatuh_tempo, diverifikasi_pada')
          .eq('kost_id', resolvedKostId);
      final invoicesList = List<Map<String, dynamic>>.from(invoicesData);

      double pemasukanKasRiil = 0.0;
      double totalTunggakan = 0.0;
      int tunggakanCount = 0;
      int overdueCount = 0;
      int pendingVerificationCount = 0;

      final now = DateTime.now();
      final todayDateStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      for (var inv in invoicesList) {
        final status = inv['status']?.toString();
        final nominal = (inv['nominal'] as num?)?.toDouble() ?? 0.0;
        final dueDateStr = inv['tanggal_jatuh_tempo']?.toString() ?? '';

        if (status == 'lunas') {
          pemasukanKasRiil += nominal;
        } else if (status == 'menunggu_verifikasi') {
          pendingVerificationCount++;
        } else if (status == 'belum_bayar') {
          totalTunggakan += nominal;
          tunggakanCount++;
          if (dueDateStr.isNotEmpty && dueDateStr.compareTo(todayDateStr) < 0) {
            overdueCount++;
          }
        }
      }

      // 3. Data Tiket Keluhan Aktif
      int activeComplaintsCount = 0;
      try {
        final complaintsData = await _client
            .from('complaints')
            .select('status')
            .eq('kost_id', resolvedKostId)
            .inFilter('status', ['diajukan', 'sedang_dikerjakan']);
        activeComplaintsCount = (complaintsData as List).length;
      } catch (_) {
        activeComplaintsCount = 0;
      }

      return OperationalSummary(
        totalRooms: totalRooms,
        occupiedRooms: occupiedRooms,
        emptyRooms: emptyRooms,
        occupancyRate: occupancyRate,
        pemasukanKasRiil: pemasukanKasRiil,
        totalTunggakan: totalTunggakan,
        tunggakanCount: tunggakanCount,
        overdueCount: overdueCount,
        pendingVerificationCount: pendingVerificationCount,
        activeComplaintsCount: activeComplaintsCount,
      );
    } catch (e) {
      return const OperationalSummary();
    }
  }

  // ===========================================================================
  // 3. MANAJEMEN INVENTARIS KAMAR (PRD MODUL 2)
  // ===========================================================================

  /// Mengambil daftar kamar untuk kos tertentu
  static Future<List<Map<String, dynamic>>> getRooms(String? kostId) async {
    try {
      var query = _client.from('rooms').select();
      if (kostId != null && kostId.isNotEmpty) {
        query = query.eq('kost_id', kostId);
      }
      final data = await query.order('nomor_kamar', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  /// Menambahkan kamar baru ke database Supabase
  static Future<bool> addRoom({
    required String kostId,
    required String nomorKamar,
    required String tipe,
    required double hargaBulanan,
    required List<String> fasilitas,
    String status = 'kosong',
  }) async {
    try {
      await _client.from('rooms').insert({
        'kost_id': kostId,
        'nomor_kamar': nomorKamar,
        'tipe': tipe,
        'harga_bulanan': hargaBulanan,
        'fasilitas': fasilitas,
        'status': status,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Memperbarui status kamar (kosong, terisi, perbaikan, akan_kosong)
  static Future<bool> updateRoomStatus(String roomId, String newStatus) async {
    try {
      await _client.from('rooms').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', roomId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Menghapus kamar
  static Future<bool> deleteRoom(String roomId) async {
    try {
      await _client.from('rooms').delete().eq('id', roomId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ===========================================================================
  // 4. ALOKASI PENGHUNI KE KAMAR (PRD US-2.2)
  // ===========================================================================

  /// Mengambil daftar penghuni yang terdaftar tapi belum memiliki kamar aktif
  static Future<List<Map<String, dynamic>>> getUnallocatedTenants(
      String? kostId) async {
    try {
      // 1. Ambil seluruh profil pengguna non-owner dari database
      final profilesData = await _client
          .from('profiles')
          .select('*')
          .neq('role', 'owner');
      final profiles = List<Map<String, dynamic>>.from(profilesData);

      // 2. Cek siapa saja yang sudah menempati kamar aktif di tabel tenants
      final activeTenantsData = await _client
          .from('tenants')
          .select('user_id')
          .eq('status_sewa', 'aktif');
      final activeUserIds = (activeTenantsData as List)
          .map((t) => t['user_id']?.toString())
          .toSet();

      // 3. Filter calon yang belum memiliki kamar aktif
      final unallocated = profiles
          .where((p) => !activeUserIds.contains(p['id']?.toString()))
          .toList();

      // 4. Jika kostId spesifik disediakan, prioritaskan yang cocok dengan kos ini atau belum terikat
      if (kostId != null && kostId.isNotEmpty) {
        final matching = unallocated.where((p) {
          final pKostId = p['kost_id']?.toString();
          return pKostId == null || pKostId.isEmpty || pKostId == kostId;
        }).toList();

        if (matching.isNotEmpty) {
          return matching;
        }
      }

      // Fallback: kembalikan seluruh calon penghuni unallocated agar pemilik tidak kehilangan calon
      return unallocated;
    } catch (e) {
      debugPrint('Error getUnallocatedTenants: $e');
      return [];
    }
  }

  /// Mengambil daftar penyewa aktif beserta info kamar dan profil
  static Future<List<Map<String, dynamic>>> getActiveTenants(String? kostId) async {
    try {
      var query = _client.from('tenants').select('''
        id,
        kost_id,
        user_id,
        room_id,
        tanggal_masuk,
        tanggal_jatuh_tempo_bulanan,
        status_sewa,
        profiles:user_id (*),
        rooms:room_id (id, nomor_kamar, tipe, harga_bulanan)
      ''').eq('status_sewa', 'aktif');

      if (kostId != null && kostId.isNotEmpty) {
        query = query.eq('kost_id', kostId);
      }

      final data = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  /// Alokasikan akun penghuni terdaftar ke kamar tertentu (US-2.2)
  /// Sekaligus otomatis menerbitkan tagihan pertama (US-3.1)
  static Future<bool> allocateRoom({
    required String kostId,
    required String userId,
    required String roomId,
    required double hargaBulanan,
    required String nomorKamar,
    required DateTime tanggalMasuk,
    required int tanggalJatuhTempo,
  }) async {
    try {
      // 1. Buat record tenant baru
      final tenantInsert = await _client
          .from('tenants')
          .insert({
            'kost_id': kostId,
            'user_id': userId,
            'room_id': roomId,
            'tanggal_masuk':
                "${tanggalMasuk.year}-${tanggalMasuk.month.toString().padLeft(2, '0')}-${tanggalMasuk.day.toString().padLeft(2, '0')}",
            'tanggal_jatuh_tempo_bulanan': tanggalJatuhTempo,
            'status_sewa': 'aktif',
          })
          .select('id')
          .single();

      final tenantId = tenantInsert['id'].toString();

      // 2. Hubungkan juga profil user ke kost_id ini di tabel profiles
      try {
        await _client.from('profiles').update({
          'kost_id': kostId,
          'role': 'tenant',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      } catch (e) {
        debugPrint('Warning: gagal update profiles.kost_id saat alokasi: $e');
      }

      // 3. Ubah status kamar menjadi 'terisi'
      await _client.from('rooms').update({
        'status': 'terisi',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', roomId);

      // 3. Terbitkan invoice pertama secara otomatis (PRD Modul 3)
      final now = DateTime.now();
      final periode =
          "${now.year}-${now.month.toString().padLeft(2, '0')}";
      final nomorInvoice =
          "INV/${now.year}${now.month.toString().padLeft(2, '0')}/$nomorKamar/${tenantId.substring(0, 4).toUpperCase()}";

      final dueDate = DateTime(now.year, now.month, tanggalJatuhTempo);
      final dueDateStr =
          "${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}";

      await _client.from('invoices').insert({
        'kost_id': kostId,
        'tenant_id': tenantId,
        'nomor_invoice': nomorInvoice,
        'periode': periode,
        'nominal': hargaBulanan,
        'tanggal_jatuh_tempo': dueDateStr,
        'status': 'belum_bayar',
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // ===========================================================================
  // 5. MANAJEMEN TAGIHAN, BUKTI BAYAR & VERIFIKASI (PRD MODUL 3 & 6)
  // ===========================================================================

  /// Mengambil daftar invoice untuk kos tertentu
  static Future<List<Map<String, dynamic>>> getInvoices(
    String? kostId, {
    String? statusFilter,
  }) async {
    try {
      var query = _client.from('invoices').select('''
        id,
        kost_id,
        tenant_id,
        nomor_invoice,
        periode,
        nominal,
        tanggal_jatuh_tempo,
        bukti_bayar_url,
        tanggal_bayar,
        diverifikasi_pada,
        status,
        catatan_penolakan,
        created_at,
        tenants:tenant_id (
          id,
          user_id,
          room_id,
          profiles:user_id (id, full_name),
          rooms:room_id (id, nomor_kamar, tipe)
        )
      ''');

      if (kostId != null && kostId.isNotEmpty) {
        query = query.eq('kost_id', kostId);
      }
      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.eq('status', statusFilter);
      }

      final data = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  /// Verifikasi bukti transfer oleh Pemilik (PRD US-3.3 & US-6.1)
  /// Jika Lunas, otomatis mencatat Kas Masuk ke tabel cash_ledgers!
  static Future<bool> verifyInvoice({
    required String invoiceId,
    required String kostId,
    required double nominal,
    required String nomorInvoice,
    required bool approve,
    String? rejectionReason,
  }) async {
    try {
      final nowStr = DateTime.now().toIso8601String();

      if (approve) {
        // 1. Ubah status invoice menjadi 'lunas'
        await _client.from('invoices').update({
          'status': 'lunas',
          'diverifikasi_pada': nowStr,
          'updated_at': nowStr,
        }).eq('id', invoiceId);

        // 2. OTOMASI PRD US-6.1: Catat kas masuk ke tabel cash_ledgers
        await _client.from('cash_ledgers').insert({
          'kost_id': kostId,
          'tipe': 'masuk',
          'kategori': 'sewa_kamar',
          'nominal': nominal,
          'tanggal': nowStr.substring(0, 10),
          'keterangan': 'Pelunasan tagihan $nomorInvoice',
          'invoice_id': invoiceId,
        });
      } else {
        // Tolak pembayaran
        await _client.from('invoices').update({
          'status': 'ditolak',
          'catatan_penolakan': rejectionReason ?? 'Bukti pembayaran tidak sesuai nominal atau rekening tujuan.',
          'updated_at': nowStr,
        }).eq('id', invoiceId);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Terbitkan tagihan baru secara manual atau untuk periode tertentu
  static Future<bool> createInvoice({
    required String kostId,
    required String tenantId,
    required String nomorKamar,
    required double nominal,
    required String periode,
    required DateTime tanggalJatuhTempo,
  }) async {
    try {
      final dueDateStr =
          "${tanggalJatuhTempo.year}-${tanggalJatuhTempo.month.toString().padLeft(2, '0')}-${tanggalJatuhTempo.day.toString().padLeft(2, '0')}";
      final nomorInvoice =
          "INV/${periode.replaceAll('-', '')}/$nomorKamar/${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";

      await _client.from('invoices').insert({
        'kost_id': kostId,
        'tenant_id': tenantId,
        'nomor_invoice': nomorInvoice,
        'periode': periode,
        'nominal': nominal,
        'tanggal_jatuh_tempo': dueDateStr,
        'status': 'belum_bayar',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ===========================================================================
  // 6. PEMBUKUAN KAS (CASH LEDGER - PRD MODUL 6)
  // ===========================================================================

  /// Mengambil daftar mutasi kas masuk dan kas keluar
  static Future<List<Map<String, dynamic>>> getCashLedgers(String? kostId) async {
    try {
      var query = _client.from('cash_ledgers').select();
      if (kostId != null && kostId.isNotEmpty) {
        query = query.eq('kost_id', kostId);
      }
      final data = await query.order('tanggal', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  /// Tambah pencatatan pengeluaran operasional manual (PRD US-6.2)
  static Future<bool> addExpense({
    required String kostId,
    required String kategori,
    required double nominal,
    required String keterangan,
    required DateTime tanggal,
  }) async {
    try {
      final dateStr =
          "${tanggal.year}-${tanggal.month.toString().padLeft(2, '0')}-${tanggal.day.toString().padLeft(2, '0')}";
      await _client.from('cash_ledgers').insert({
        'kost_id': kostId,
        'tipe': 'keluar',
        'kategori': kategori,
        'nominal': nominal,
        'tanggal': dateStr,
        'keterangan': keterangan,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ===========================================================================
  // 7. HELPDESK & TIKET KELUHAN KERUSAKAN FASILITAS (PRD MODUL 4)
  // ===========================================================================

  /// Mengambil daftar keluhan kerusakan fasilitas
  static Future<List<Map<String, dynamic>>> getComplaints({
    String? kostId,
    String? tenantId,
    String? scope, // 'kamar_pribadi' | 'fasilitas_umum'
    String? statusFilter, // 'diajukan' | 'sedang_dikerjakan' | 'selesai'
  }) async {
    try {
      var query = _client.from('complaints').select('''
        id,
        kost_id,
        tenant_id,
        tipe_fasilitas,
        judul,
        deskripsi,
        foto_urls,
        status,
        catatan_penanganan,
        diselesaikan_pada,
        created_at,
        tenants:tenant_id (
          id,
          user_id,
          room_id,
          rooms:room_id (nomor_kamar, tipe),
          profiles:user_id (full_name, nomor_wa)
        )
      ''');

      if (kostId != null && kostId.isNotEmpty) {
        query = query.eq('kost_id', kostId);
      }
      if (tenantId != null && tenantId.isNotEmpty) {
        query = query.eq('tenant_id', tenantId);
      }
      if (scope != null && scope.isNotEmpty) {
        query = query.eq('tipe_fasilitas', scope);
      }
      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.eq('status', statusFilter);
      }

      final data = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  /// Membuat tiket keluhan baru oleh penghuni (PRD US-4.1)
  static Future<bool> createComplaint({
    required String kostId,
    required String tenantId,
    required String tipeFasilitas, // 'kamar_pribadi' atau 'fasilitas_umum'
    required String judul,
    required String deskripsi,
    List<String> fotoUrls = const [],
  }) async {
    try {
      await _client.from('complaints').insert({
        'kost_id': kostId,
        'tenant_id': tenantId,
        'tipe_fasilitas': tipeFasilitas,
        'judul': judul,
        'deskripsi': deskripsi,
        'foto_urls': fotoUrls,
        'status': 'diajukan',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Memperbarui status tiket keluhan oleh pemilik (PRD US-4.3)
  static Future<bool> updateComplaintStatus({
    required String complaintId,
    required String status, // 'diajukan', 'sedang_dikerjakan', 'selesai'
    String? catatanPenanganan,
  }) async {
    try {
      final nowStr = DateTime.now().toIso8601String();
      final Map<String, dynamic> updateData = {
        'status': status,
        'catatan_penanganan': catatanPenanganan,
        'updated_at': nowStr,
      };

      if (status == 'selesai') {
        updateData['diselesaikan_pada'] = nowStr;
      }

      await _client.from('complaints').update(updateData).eq('id', complaintId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ===========================================================================
  // 8. MITIGASI KAMAR KOSONG H-30 & RADAR RETENSI (PRD MODUL 5)
  // ===========================================================================

  /// Mengambil daftar kamar yang kosong atau berstatus akan_kosong atau dalam masa H-30
  static Future<List<Map<String, dynamic>>> getH30RadarRooms(String? kostId) async {
    try {
      var query = _client.from('rooms').select('''
        id,
        kost_id,
        nomor_kamar,
        tipe,
        harga_bulanan,
        fasilitas,
        foto_url,
        status,
        tenants:tenants (
          id,
          user_id,
          tanggal_masuk,
          tanggal_akhir_sewa,
          status_sewa,
          h30_response,
          profiles:user_id (full_name, nomor_wa)
        )
      ''');

      if (kostId != null && kostId.isNotEmpty) {
        query = query.eq('kost_id', kostId);
      }

      final data = await query.order('nomor_kamar', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  /// Memperbarui respons komitmen H-30 penghuni (PRD US-5.1)
  static Future<bool> updateH30Commitment({
    required String tenantId,
    required String roomId,
    required String response, // 'lanjut' | 'selesai' | 'perlu_manual'
    DateTime? checkoutDate,
  }) async {
    try {
      final nowStr = DateTime.now().toIso8601String();

      // 1. Update di tabel tenants
      final Map<String, dynamic> tenantUpdate = {
        'h30_response': response,
        'updated_at': nowStr,
      };
      if (checkoutDate != null) {
        tenantUpdate['tanggal_akhir_sewa'] =
            "${checkoutDate.year}-${checkoutDate.month.toString().padLeft(2, '0')}-${checkoutDate.day.toString().padLeft(2, '0')}";
      }

      await _client.from('tenants').update(tenantUpdate).eq('id', tenantId);

      // 2. Jika penghuni menyatakan selesai sewa, ubah status kamar menjadi 'akan_kosong'
      if (response == 'selesai') {
        await _client.from('rooms').update({
          'status': 'akan_kosong',
          'updated_at': nowStr,
        }).eq('id', roomId);
      } else if (response == 'lanjut') {
        // Jika lanjut sewa, pastikan kamar tetap terisi
        await _client.from('rooms').update({
          'status': 'terisi',
          'updated_at': nowStr,
        }).eq('id', roomId);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // ===========================================================================
  // 9. DATA ALOKASI AKTIF PENGHUNI (PORTAL TENANT)
  // ===========================================================================

  /// Mengambil data sewa aktif penghuni yang sedang login
  static Future<Map<String, dynamic>?> getTenantActiveAssignment(String userId) async {
    try {
      final data = await _client.from('tenants').select('''
        id,
        kost_id,
        user_id,
        room_id,
        tanggal_masuk,
        tanggal_jatuh_tempo_bulanan,
        tanggal_akhir_sewa,
        status_sewa,
        h30_response,
        rooms:room_id (
          id,
          nomor_kamar,
          tipe,
          harga_bulanan,
          fasilitas,
          status,
          foto_url
        ),
        kosts:kost_id (
          id,
          nama_kost,
          alamat,
          nomor_kontak,
          rekening_bank,
          nama_pemilik_rekening
        )
      ''').eq('user_id', userId).eq('status_sewa', 'aktif').maybeSingle();

      return data;
    } catch (e) {
      return null;
    }
  }
}
