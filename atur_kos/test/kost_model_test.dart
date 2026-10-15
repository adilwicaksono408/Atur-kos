import 'package:flutter_test/flutter_test.dart';
import 'package:atur_kos/models/kost_model.dart';

void main() {
  group('SubscriptionTier and KostModel Unlimited Room Tests', () {
    test('SubscriptionTier Juragan provides unlimited rooms default (>= 9999)', () {
      final starter = SubscriptionTier.starter;
      final juragan = SubscriptionTier.juragan;

      expect(starter.defaultMaxRooms, equals(5));
      expect(juragan.defaultMaxRooms, greaterThanOrEqualTo(9999));
    });

    test('KostModel correctly identifies unlimited rooms for Juragan', () {
      final juraganKost = KostModel(
        id: 'kost-1',
        namaKost: 'Kost Sultan Juragan',
        alamat: 'Jl. Kaliurang KM 5',
        nomorKontak: '08123456789',
        tier: SubscriptionTier.juragan,
        maxRooms: SubscriptionTier.juragan.defaultMaxRooms,
      );

      expect(juraganKost.isJuragan, isTrue);
      expect(juraganKost.hasUnlimitedRooms, isTrue);
    });

    test('KostModel identifies limited rooms for Starter tier', () {
      final starterKost = KostModel(
        id: 'kost-2',
        namaKost: 'Kost Starter',
        alamat: 'Jl. Kaliurang KM 6',
        nomorKontak: '08123456780',
        tier: SubscriptionTier.starter,
        maxRooms: 5,
      );

      expect(starterKost.isJuragan, isFalse);
      expect(starterKost.hasUnlimitedRooms, isFalse);
      expect(starterKost.maxRooms, equals(5));
    });
  });
}
