import 'package:flutter_test/flutter_test.dart';
import 'package:atur_kos/models/announcement_model.dart';

void main() {
  group('AnnouncementModel Tests (PRD Modul 9: Papan Pengumuman & Paket Kurir)', () {
    test('Identifikasi kategori pengumuman, label, dan status broadcast vs kamar spesifik', () {
      final paketKamar5 = AnnouncementModel(
        id: 'ann-1',
        kostId: 'kost-1',
        authorId: 'owner-1',
        targetRoomId: 'room-5',
        targetRoomNumber: '05',
        kategori: 'paket',
        judul: 'Paket Kurir Tiba di Lobi',
        deskripsi: 'Paket Shopee untuk Kamar 05 sudah ditaruh di rak lobi.',
        fotoUrls: ['https://storage.supabase.co/photos/paket1.jpg'],
        isPinned: false,
        isResolved: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      final infoAirDarurat = AnnouncementModel(
        id: 'ann-2',
        kostId: 'kost-1',
        authorId: 'owner-1',
        targetRoomId: null, // Broadcast
        kategori: 'info_operasional',
        judul: 'Pengurasan Toren Air',
        deskripsi: 'Air akan dimatikan sementara pukul 13:00 - 15:00 WIB.',
        isPinned: true,
        isResolved: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      // Verifikasi paket spesifik
      expect(paketKamar5.isPaket, isTrue);
      expect(paketKamar5.isBroadcast, isFalse);
      expect(paketKamar5.targetRoomNumber, equals('05'));
      expect(paketKamar5.kategoriLabel, equals('Paket Kurir Tiba'));
      expect(paketKamar5.hasPhoto, isTrue);
      expect(paketKamar5.primaryPhotoUrl, equals('https://storage.supabase.co/photos/paket1.jpg'));
      expect(paketKamar5.timeAgo, contains('menit lalu'));

      // Verifikasi info broadcast & pin
      expect(infoAirDarurat.isInfoOperasional, isTrue);
      expect(infoAirDarurat.isBroadcast, isTrue);
      expect(infoAirDarurat.isPinned, isTrue);
      expect(infoAirDarurat.kategoriLabel, equals('Info Operasional Kos'));
      expect(infoAirDarurat.timeAgo, contains('jam lalu'));
    });

    test('Serialisasi fromMap & toMap dengan relasi Supabase joins', () {
      final dbMap = {
        'id': 'uuid-1234',
        'kost_id': 'kost-abc',
        'author_id': 'user-xyz',
        'target_room_id': 'room-01',
        'kategori': 'barang_hilang',
        'judul': 'Ditemukan Kunci Motor Honda',
        'deskripsi': 'Kunci motor tertinggal di area parkir dekat jemuran.',
        'foto_urls': ['https://example.com/kunci.jpg'],
        'is_pinned': true,
        'is_resolved': false,
        'created_at': '2026-10-18T10:00:00.000Z',
        'updated_at': '2026-10-18T10:30:00.000Z',
        'rooms': {
          'nomor_kamar': '01',
          'tipe': 'Deluxe AC',
        },
        'profiles': {
          'full_name': 'Pak Budi (Pemilik Kos)',
          'role': 'owner',
        },
      };

      final model = AnnouncementModel.fromMap(dbMap);

      expect(model.id, equals('uuid-1234'));
      expect(model.kostId, equals('kost-abc'));
      expect(model.kategori, equals('barang_hilang'));
      expect(model.isBarangHilang, isTrue);
      expect(model.kategoriLabel, equals('Barang Tercecer / Hilang'));
      expect(model.targetRoomNumber, equals('01'));
      expect(model.targetRoomType, equals('Deluxe AC'));
      expect(model.authorName, equals('Pak Budi (Pemilik Kos)'));
      expect(model.authorRole, equals('owner'));
      expect(model.isPinned, isTrue);
      expect(model.isResolved, isFalse);
      expect(model.fotoUrls.length, equals(1));

      // Tes toMap
      final outMap = model.toMap();
      expect(outMap['id'], equals('uuid-1234'));
      expect(outMap['kost_id'], equals('kost-abc'));
      expect(outMap['kategori'], equals('barang_hilang'));
      expect(outMap['target_room_id'], equals('room-01'));
      expect(outMap['is_pinned'], isTrue);
      expect(outMap['is_resolved'], isFalse);
    });

    test('copyWith menghasilkan objek baru yang tidak memutasi aslinya (Immutability)', () {
      final original = AnnouncementModel(
        id: 'ann-init',
        kostId: 'kost-1',
        authorId: 'auth-1',
        kategori: 'paket',
        judul: 'Paket J&T Express',
        deskripsi: 'Di teras depan',
        isResolved: false,
        createdAt: DateTime(2026, 10, 18, 14, 0),
      );

      final updated = original.copyWith(isResolved: true);

      expect(original.isResolved, isFalse);
      expect(updated.isResolved, isTrue);
      expect(updated.id, equals(original.id));
      expect(updated.judul, equals(original.judul));
    });
  });
}
