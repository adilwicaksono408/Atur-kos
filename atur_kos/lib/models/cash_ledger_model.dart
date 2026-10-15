import 'package:flutter/material.dart';

/// Model Entitas Buku Kas (Cash Ledger) PRD Modul 6
/// Merepresentasikan mutasi kas masuk (otomatis saat invoice lunas / manual)
/// dan kas keluar (pengeluaran operasional kos).
class CashLedgerModel {
  final String id;
  final String kostId;
  final String tipe; // 'masuk' | 'keluar'
  final String kategori;
  final double nominal;
  final DateTime tanggal;
  final String keterangan;
  final String? invoiceId;
  final String? buktiNotaUrl;
  final DateTime? createdAt;

  const CashLedgerModel({
    required this.id,
    required this.kostId,
    required this.tipe,
    required this.kategori,
    required this.nominal,
    required this.tanggal,
    required this.keterangan,
    this.invoiceId,
    this.buktiNotaUrl,
    this.createdAt,
  });

  bool get isMasuk => tipe.toLowerCase() == 'masuk';
  bool get isKeluar => tipe.toLowerCase() == 'keluar';

  factory CashLedgerModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedTanggal;
    try {
      final t = map['tanggal']?.toString() ?? '';
      parsedTanggal = DateTime.tryParse(t) ?? DateTime.now();
    } catch (_) {
      parsedTanggal = DateTime.now();
    }

    DateTime? parsedCreated;
    try {
      final c = map['created_at']?.toString();
      if (c != null && c.isNotEmpty) {
        parsedCreated = DateTime.tryParse(c);
      }
    } catch (_) {}

    return CashLedgerModel(
      id: map['id']?.toString() ?? '',
      kostId: map['kost_id']?.toString() ?? '',
      tipe: map['tipe']?.toString() ?? 'masuk',
      kategori: map['kategori']?.toString() ?? 'lainnya',
      nominal: (map['nominal'] as num?)?.toDouble() ?? 0.0,
      tanggal: parsedTanggal,
      keterangan: map['keterangan']?.toString() ?? '',
      invoiceId: map['invoice_id']?.toString(),
      buktiNotaUrl: map['bukti_nota_url']?.toString(),
      createdAt: parsedCreated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kost_id': kostId,
      'tipe': tipe,
      'kategori': kategori,
      'nominal': nominal,
      'tanggal':
          "${tanggal.year}-${tanggal.month.toString().padLeft(2, '0')}-${tanggal.day.toString().padLeft(2, '0')}",
      'keterangan': keterangan,
      'invoice_id': invoiceId,
      'bukti_nota_url': buktiNotaUrl,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Label kategori yang rapi dan ramah dibaca
  String get kategoriLabel {
    switch (kategori.toLowerCase()) {
      // Kategori Pengeluaran
      case 'listrik':
        return 'Token Listrik PLN';
      case 'wifi':
        return 'WiFi & Internet';
      case 'air':
        return 'Air PDAM / Tangki';
      case 'perbaikan':
        return 'Perbaikan & Servis';
      case 'kebersihan':
        return 'Iuran Sampah & Kebersihan';
      case 'gaji':
        return 'Gaji Penjaga / Karyawan';
      // Kategori Pemasukan
      case 'sewa_kamar':
        return 'Sewa Kamar';
      case 'deposit':
        return 'Uang Deposit / Jaminan';
      case 'denda':
        return 'Denda Keterlambatan';
      default:
        return kategori.replaceAll('_', ' ').toUpperCase();
    }
  }

  /// Ikon representatif untuk setiap kategori transaksi
  IconData get kategoriIcon {
    switch (kategori.toLowerCase()) {
      case 'listrik':
        return Icons.bolt_rounded;
      case 'wifi':
        return Icons.wifi_rounded;
      case 'air':
        return Icons.water_drop_rounded;
      case 'perbaikan':
        return Icons.home_repair_service_rounded;
      case 'kebersihan':
        return Icons.delete_outline_rounded;
      case 'gaji':
        return Icons.badge_rounded;
      case 'sewa_kamar':
        return Icons.meeting_room_rounded;
      case 'deposit':
        return Icons.shield_rounded;
      case 'denda':
        return Icons.warning_amber_rounded;
      default:
        return isMasuk
            ? Icons.arrow_downward_rounded
            : Icons.arrow_upward_rounded;
    }
  }

  /// Warna aksen untuk visualisasi kategori
  Color get kategoriColor {
    switch (kategori.toLowerCase()) {
      case 'listrik':
        return const Color(0xFFEAB308); // Kuning / Amber
      case 'wifi':
        return const Color(0xFF3B82F6); // Biru
      case 'air':
        return const Color(0xFF06B6D4); // Cyan
      case 'perbaikan':
        return const Color(0xFFF97316); // Orange
      case 'kebersihan':
        return const Color(0xFF10B981); // Emerald
      case 'gaji':
        return const Color(0xFF8B5CF6); // Ungu
      case 'sewa_kamar':
        return const Color(0xFF059669); // Hijau
      case 'deposit':
        return const Color(0xFF0284C7); // Biru Langit
      case 'denda':
        return const Color(0xFFDC2626); // Merah
      default:
        return isMasuk ? const Color(0xFF059669) : const Color(0xFFEF4444);
    }
  }
}

/// Ringkasan Finansial Arus Kas per Periode (Bulan / Tahun)
class CashLedgerSummary {
  final double totalPemasukan;
  final double totalPengeluaran;
  final double labaBersih;
  final int jumlahTransaksiMasuk;
  final int jumlahTransaksiKeluar;
  final Map<String, double> pengeluaranPerKategori;
  final Map<String, double> pemasukanPerKategori;

  const CashLedgerSummary({
    this.totalPemasukan = 0.0,
    this.totalPengeluaran = 0.0,
    this.labaBersih = 0.0,
    this.jumlahTransaksiMasuk = 0,
    this.jumlahTransaksiKeluar = 0,
    this.pengeluaranPerKategori = const {},
    this.pemasukanPerKategori = const {},
  });

  /// Rasio Margin Laba Bersih (%)
  double get profitMargin {
    if (totalPemasukan <= 0) return 0.0;
    return (labaBersih / totalPemasukan) * 100;
  }

  /// Status Kesehatan Finansial
  String get financialHealthStatus {
    if (totalPemasukan == 0 && totalPengeluaran == 0) {
      return 'Belum Ada Transaksi';
    }
    if (labaBersih > 0) {
      if (profitMargin >= 50) return 'Sangat Sehat (Laba Tinggi)';
      return 'Positif (Arus Kas Surplus)';
    } else if (labaBersih == 0) {
      return 'Titik Impas (BEP)';
    } else {
      return 'Defisit (Pengeluaran Tinggi)';
    }
  }

  /// Komputasi ringkasan dari daftar transaksi cash ledgers
  factory CashLedgerSummary.fromLedgers(List<CashLedgerModel> ledgers) {
    double masuk = 0.0;
    double keluar = 0.0;
    int countMasuk = 0;
    int countKeluar = 0;
    final Map<String, double> expByCat = {};
    final Map<String, double> incByCat = {};

    for (final item in ledgers) {
      if (item.isMasuk) {
        masuk += item.nominal;
        countMasuk++;
        incByCat[item.kategori] =
            (incByCat[item.kategori] ?? 0.0) + item.nominal;
      } else {
        keluar += item.nominal;
        countKeluar++;
        expByCat[item.kategori] =
            (expByCat[item.kategori] ?? 0.0) + item.nominal;
      }
    }

    return CashLedgerSummary(
      totalPemasukan: masuk,
      totalPengeluaran: keluar,
      labaBersih: masuk - keluar,
      jumlahTransaksiMasuk: countMasuk,
      jumlahTransaksiKeluar: countKeluar,
      pengeluaranPerKategori: expByCat,
      pemasukanPerKategori: incByCat,
    );
  }
}
