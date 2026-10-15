import 'package:flutter_test/flutter_test.dart';
import 'package:atur_kos/models/cash_ledger_model.dart';

void main() {
  group('CashLedgerModel & CashLedgerSummary Tests (PRD US-6.1 & US-6.2)', () {
    test('CashLedgerModel correctly identifies masuk and keluar transactions', () {
      final masuk = CashLedgerModel(
        id: 'ledger-1',
        kostId: 'kost-1',
        tipe: 'masuk',
        kategori: 'sewa_kamar',
        nominal: 1500000,
        tanggal: DateTime(2026, 10, 8),
        keterangan: 'Sewa Kamar 05 via Midtrans',
      );

      final keluar = CashLedgerModel(
        id: 'ledger-2',
        kostId: 'kost-1',
        tipe: 'keluar',
        kategori: 'listrik',
        nominal: 350000,
        tanggal: DateTime(2026, 10, 5),
        keterangan: 'Beli Token Listrik Utama',
      );

      expect(masuk.isMasuk, isTrue);
      expect(masuk.isKeluar, isFalse);
      expect(masuk.kategoriLabel, equals('Sewa Kamar'));

      expect(keluar.isMasuk, isFalse);
      expect(keluar.isKeluar, isTrue);
      expect(keluar.kategoriLabel, equals('Token Listrik PLN'));
    });

    test('CashLedgerModel fromMap and toMap serialization', () {
      final map = {
        'id': 'ledger-3',
        'kost_id': 'kost-abc',
        'tipe': 'keluar',
        'kategori': 'wifi',
        'nominal': 450000,
        'tanggal': '2026-10-01',
        'keterangan': 'Tagihan IndiHome Bulanan',
        'bukti_nota_url': 'https://example.com/nota.jpg',
      };

      final model = CashLedgerModel.fromMap(map);
      expect(model.id, equals('ledger-3'));
      expect(model.tipe, equals('keluar'));
      expect(model.kategori, equals('wifi'));
      expect(model.nominal, equals(450000.0));
      expect(model.tanggal.year, equals(2026));
      expect(model.tanggal.month, equals(10));
      expect(model.tanggal.day, equals(1));
      expect(model.keterangan, equals('Tagihan IndiHome Bulanan'));
      expect(model.buktiNotaUrl, equals('https://example.com/nota.jpg'));

      final outMap = model.toMap();
      expect(outMap['tipe'], equals('keluar'));
      expect(outMap['tanggal'], equals('2026-10-01'));
      expect(outMap['nominal'], equals(450000.0));
    });

    test('CashLedgerSummary computes total pemasukan, pengeluaran, and laba bersih correctly', () {
      final ledgers = [
        CashLedgerModel(
          id: '1',
          kostId: 'k1',
          tipe: 'masuk',
          kategori: 'sewa_kamar',
          nominal: 15000000,
          tanggal: DateTime(2026, 10, 1),
          keterangan: 'Sewa Lantai 1 (10 Kamar)',
        ),
        CashLedgerModel(
          id: '2',
          kostId: 'k1',
          tipe: 'masuk',
          kategori: 'sewa_kamar',
          nominal: 13500000,
          tanggal: DateTime(2026, 10, 2),
          keterangan: 'Sewa Lantai 2 (9 Kamar)',
        ),
        CashLedgerModel(
          id: '3',
          kostId: 'k1',
          tipe: 'keluar',
          kategori: 'listrik',
          nominal: 2000000,
          tanggal: DateTime(2026, 10, 3),
          keterangan: 'Token Listrik PLN',
        ),
        CashLedgerModel(
          id: '4',
          kostId: 'k1',
          tipe: 'keluar',
          kategori: 'wifi',
          nominal: 1200000,
          tanggal: DateTime(2026, 10, 4),
          keterangan: 'Internet Dedicated',
        ),
        CashLedgerModel(
          id: '5',
          kostId: 'k1',
          tipe: 'keluar',
          kategori: 'perbaikan',
          nominal: 1000000,
          tanggal: DateTime(2026, 10, 5),
          keterangan: 'Ganti pipa & keran air',
        ),
      ];

      final summary = CashLedgerSummary.fromLedgers(ledgers);

      // Total Pemasukan: 15.000.000 + 13.500.000 = 28.500.000
      expect(summary.totalPemasukan, equals(28500000.0));
      expect(summary.jumlahTransaksiMasuk, equals(2));

      // Total Pengeluaran: 2.000.000 + 1.200.000 + 1.000.000 = 4.200.000
      expect(summary.totalPengeluaran, equals(4200000.0));
      expect(summary.jumlahTransaksiKeluar, equals(3));

      // Laba Bersih: 28.500.000 - 4.200.000 = 24.300.000
      expect(summary.labaBersih, equals(24300000.0));

      // Profit Margin: (24.300.000 / 28.500.000) * 100 ~ 85.26%
      expect(summary.profitMargin, closeTo(85.26, 0.1));
      expect(summary.financialHealthStatus, contains('Sangat Sehat'));

      // Category breakdown
      expect(summary.pengeluaranPerKategori['listrik'], equals(2000000.0));
      expect(summary.pengeluaranPerKategori['wifi'], equals(1200000.0));
      expect(summary.pengeluaranPerKategori['perbaikan'], equals(1000000.0));
    });
  });
}
