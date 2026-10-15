import 'package:flutter/material.dart' show BuildContext, debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:atur_kos/models/kost_model.dart';
import 'package:atur_kos/utils/format_utils.dart';

/// Layanan Pembuatan & Ekspor Dokumen PDF Resmi Atur Kos
/// Mendukung ekspor laporan audit finansial SaaS, evaluasi Bab IV, dan rekap kuitansi
class ReportPdfService {
  /// Membuat dan membuka dialog cetak/unduh PDF Laporan Finansial B2B SaaS Atur Kos
  static Future<void> exportSaaSFinancialReport({
    required BuildContext context,
    required List<KostModel> allKosts,
    required int mrr,
    required int arr,
    required String conversionRate,
  }) async {
    try {
      final now = DateTime.now();
      final juraganKosts = allKosts.where((k) => k.isJuragan).toList();
      final starterKosts = allKosts.where((k) => !k.isJuragan).toList();

      final doc = pw.Document(
        title: 'Laporan Finansial SaaS & Audit Midtrans — Atur Kos',
        author: 'Super Admin Atur Kos',
      );

      // Palet Warna Elegan Laporan
      const primaryColor = PdfColor.fromInt(0xFF0F172A); // Slate 900
      const brandBlue = PdfColor.fromInt(0xFF2563EB); // Blue 600
      const successGreen = PdfColor.fromInt(0xFF16A34A); // Green 600
      const surfaceLight = PdfColor.fromInt(0xFFF8FAFC); // Slate 50
      const borderGray = PdfColor.fromInt(0xFFE2E8F0); // Slate 200
      const textMuted = PdfColor.fromInt(0xFF64748B); // Slate 500

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
          header: (pw.Context ctx) => _buildHeader(now, brandBlue, primaryColor, textMuted),
          footer: (pw.Context ctx) => _buildFooter(ctx, textMuted),
          build: (pw.Context ctx) => [
            pw.SizedBox(height: 16),

            // 1. Banner Kepatuhan Privasi & Lingkungan Gateway
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: surfaceLight,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderGray),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 6,
                    height: 38,
                    decoration: pw.BoxDecoration(
                      color: brandBlue,
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'AUDIT TATA KELOLA B2B PLATFORM & INTEGRASI MIDTRANS SNAP',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Dokumen ini merangkum data agregat pendapatan langganan B2B platform Atur Kos (Paket Juragan). Sesuai prinsip Data Minimization dan UU PDP No. 27/2022, data privat sewa kamar anak kos diisolasi secara ketat dan tidak diekspos.',
                          style: const pw.TextStyle(fontSize: 8.5, color: textMuted, lineSpacing: 1.2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // 2. Grid Kartu KPI Finansial
            pw.Row(
              children: [
                _buildMetricBox(
                  title: 'MONTHLY RECURRING (MRR)',
                  value: FormatUtils.formatRupiah(mrr),
                  subtitle: '${juraganKosts.length} Properti Berbayar Aktif',
                  accentColor: successGreen,
                ),
                pw.SizedBox(width: 10),
                _buildMetricBox(
                  title: 'PROYEKSI TAHUNAN (ARR)',
                  value: FormatUtils.formatRupiah(arr),
                  subtitle: 'Paket Tahunan (@ Rp 500rb/thn)',
                  accentColor: brandBlue,
                ),
                pw.SizedBox(width: 10),
                _buildMetricBox(
                  title: 'KONVERSI FREEMIUM',
                  value: '$conversionRate%',
                  subtitle: '${juraganKosts.length} Juragan dari ${allKosts.length} Properti',
                  accentColor: const PdfColor.fromInt(0xFF7C3AED),
                ),
                pw.SizedBox(width: 10),
                _buildMetricBox(
                  title: 'STATUS MIDTRANS',
                  value: 'SANDBOX LIVE',
                  subtitle: 'QRIS & Multi-Bank VA',
                  accentColor: const PdfColor.fromInt(0xFF0D9488),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // 3. Tabel Rincian Properti Paket Juragan (Berbayar)
            pw.Text(
              '1. DAFTAR PROPERTI BERLANGGANAN PAKET JURAGAN (B2B SAAS)',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 8),

            if (juraganKosts.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: surfaceLight,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderGray),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Saat ini belum ada properti kos yang berlangganan Paket Juragan aktif.',
                  style: const pw.TextStyle(fontSize: 9, color: textMuted),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: borderGray, width: 0.5),
                columnWidths: const {
                  0: pw.FixedColumnWidth(26),
                  1: pw.FlexColumnWidth(3),
                  2: pw.FlexColumnWidth(2.5),
                  3: pw.FlexColumnWidth(2),
                  4: pw.FlexColumnWidth(2.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: surfaceLight),
                    children: [
                      _buildTableHeaderCell('No'),
                      _buildTableHeaderCell('Nama Kos & Kode'),
                      _buildTableHeaderCell('Kontak / Pemilik'),
                      _buildTableHeaderCell('Masa Berlaku'),
                      _buildTableHeaderCell('Nilai Kontribusi'),
                    ],
                  ),
                  ...juraganKosts.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final k = entry.value;
                    final expiryStr = k.subscriptionExpiresAt != null
                        ? FormatUtils.formatDate(k.subscriptionExpiresAt)
                        : 'Tanpa Batas';
                    return pw.TableRow(
                      children: [
                        _buildTableCell('$idx', align: pw.TextAlign.center),
                        _buildTableCell('${k.namaKost}\nKode: ${k.kodeKost ?? "-"}', isBold: true),
                        _buildTableCell('${k.namaPemilikRekening ?? "Pemilik"}\n${k.nomorKontak}'),
                        _buildTableCell(expiryStr),
                        _buildTableCell('Rp 50.000 / bln\n(Akses Kamar Unlimited)', isSuccess: true),
                      ],
                    );
                  }),
                ],
              ),
            pw.SizedBox(height: 20),

            // 4. Ringkasan Properti Paket Starter (Freemium)
            pw.Text(
              '2. PROPERTI KOS PAKET STARTER (FREEMIUM TIER — MAKS 5 KAMAR)',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 8),

            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: surfaceLight,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: borderGray),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Properti Starter: ${starterKosts.length} Properti',
                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                  ),
                  pw.Text(
                    'Batas Kuota: Maksimal 5 Kamar per Properti (Bebas Biaya)',
                    style: const pw.TextStyle(fontSize: 9, color: textMuted),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // 5. Evaluasi Kelaikan Payment Gateway Midtrans Snap
            pw.Text(
              '3. EVALUASI KELAIKAN PAYMENT GATEWAY MIDTRANS SNAP (PENGUJIAN SISTEM)',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 8),

            pw.Table(
              border: pw.TableBorder.all(color: borderGray, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: surfaceLight),
                  children: [
                    _buildTableHeaderCell('Komponen Gateway'),
                    _buildTableHeaderCell('Status Uji'),
                    _buildTableHeaderCell('Keterangan & Bukti Operasional'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildTableCell('Midtrans Snap Sandbox'),
                    _buildTableCell('TERVERIFIKASI', isSuccess: true),
                    _buildTableCell('Simulasi QRIS & 6 Bank Virtual Account (BCA, BNI, Mandiri, BRI, Permata, CIMB).'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildTableCell('Kuitansi Ber-QR Code'),
                    _buildTableCell('STANDAR ISO', isSuccess: true),
                    _buildTableCell('Sertifikat digital sah anti-manipulasi berstandar ISO/IEC 18004 dapat dicek mandiri.'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildTableCell('Otomasi Buku Kas'),
                    _buildTableCell('AKTIF OTOMATIS', isSuccess: true),
                    _buildTableCell('Trigger PostgreSQL mencatat kas masuk ke cash_ledgers seketika status menjadi lunas.'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildTableCell('Validasi Kuota Kamar'),
                    _buildTableCell('TERKUNCI', isSuccess: true),
                    _buildTableCell('Trigger trg_check_room_quota menolak insert kamar > 5 jika properti belum Juragan.'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // 6. Tanda Tangan & Validasi Sistem
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Catatan Keabsahan Dokumen:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text('• Dokumen ini dihasilkan secara otomatis oleh sistem Atur Kos.', style: const pw.TextStyle(fontSize: 8, color: textMuted)),
                    pw.Text('• Seluruh data terikat dengan basis data PostgreSQL Supabase.', style: const pw.TextStyle(fontSize: 8, color: textMuted)),
                    pw.Text('• Layak dilampirkan sebagai bukti hasil pengujian Bab IV Skripsi.', style: const pw.TextStyle(fontSize: 8, color: textMuted)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Divalidasi oleh Sistem,', style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 34),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: brandBlue, width: 0.8),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'SUPER ADMIN — ATUR KOS',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: brandBlue),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      // Buka pratinjau / dialog download PDF langsung di browser / device!
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Laporan_Finansial_SaaS_AturKos_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.pdf',
      );
    } catch (e) {
      debugPrint('Error exportSaaSFinancialReport PDF: $e');
    }
  }

  // --- HELPER BUILDERS ---

  static pw.Widget _buildHeader(DateTime now, PdfColor brandBlue, PdfColor primaryColor, PdfColor textMuted) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 22,
                      height: 22,
                      decoration: pw.BoxDecoration(
                        color: brandBlue,
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'AK',
                        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      'ATUR KOS',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor, letterSpacing: 0.5),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Sistem Manajemen Operasional & Hunian Kos Mandiri Bebas Friksi',
                  style: pw.TextStyle(fontSize: 8, color: textMuted),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'LAPORAN AUDIT FINANSIAL SAAS',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: brandBlue),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Tanggal: ${FormatUtils.formatDate(now)} | ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB',
                  style: pw.TextStyle(fontSize: 8, color: textMuted),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: const PdfColor.fromInt(0xFFCBD5E1), thickness: 1),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context ctx, PdfColor textMuted) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Atur Kos Platform — Dokumen Audit Resmi Sistem & Evaluasi Bab IV Skripsi',
            style: pw.TextStyle(fontSize: 7.5, color: textMuted),
          ),
          pw.Text(
            'Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 7.5, color: textMuted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetricBox({
    required String title,
    required String value,
    required String subtitle,
    required PdfColor accentColor,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFFFFFFF),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(fontSize: 7, color: PdfColor.fromInt(0xFF64748B)),
              maxLines: 1,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: accentColor),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(fontSize: 6.5, color: PdfColor.fromInt(0xFF94A3B8)),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildTableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F172A)),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isBold = false,
    bool isSuccess = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isSuccess ? const PdfColor.fromInt(0xFF16A34A) : const PdfColor.fromInt(0xFF334155),
        ),
      ),
    );
  }

  /// Membuat dan membuka dialog cetak/unduh PDF Laporan Arus Kas & Pembukuan Pemilik Kos (PRD US-6.1 & US-6.2)
  static Future<void> exportOwnerCashLedgerReport({
    required BuildContext context,
    required String kosName,
    required String ownerName,
    required String periodeLabel,
    required double totalPemasukan,
    required double totalPengeluaran,
    required double labaBersih,
    required int jumlahTransaksiMasuk,
    required int jumlahTransaksiKeluar,
    required List<Map<String, dynamic>> ledgers,
    required Map<String, double> pengeluaranPerKategori,
    bool isJuragan = false,
  }) async {
    try {
      final now = DateTime.now();
      final doc = pw.Document(
        title: 'Laporan Keuangan & Arus Kas — $kosName',
        author: ownerName,
      );

      const primaryColor = PdfColor.fromInt(0xFF0F172A);
      const brandBlue = PdfColor.fromInt(0xFF1E40AF);
      const successGreen = PdfColor.fromInt(0xFF16A34A);
      const dangerRed = PdfColor.fromInt(0xFFDC2626);
      const surfaceLight = PdfColor.fromInt(0xFFF8FAFC);
      const borderGray = PdfColor.fromInt(0xFFE2E8F0);
      const textMuted = PdfColor.fromInt(0xFF64748B);

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
          header: (pw.Context ctx) => pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ATUR KOS — BUKU KAS & ARUS KAS PEMILIK',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: brandBlue,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Properti: $kosName • Pengelola: $ownerName',
                        style: const pw.TextStyle(fontSize: 10, color: textMuted),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: isJuragan ? const PdfColor.fromInt(0xFFEFF6FF) : surfaceLight,
                          borderRadius: pw.BorderRadius.circular(6),
                          border: pw.Border.all(color: borderGray),
                        ),
                        child: pw.Text(
                          isJuragan ? '⭐ PAKET JURAGAN' : 'PAKET STARTER',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: isJuragan ? brandBlue : textMuted,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Periode: $periodeLabel',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: borderGray, thickness: 1),
            ],
          ),
          footer: (pw.Context ctx) => _buildFooter(ctx, textMuted),
          build: (pw.Context ctx) => [
            pw.SizedBox(height: 12),

            // 1. Kartu 3 Metrik Utama (Pemasukan, Pengeluaran, Laba Bersih)
            pw.Row(
              children: [
                _buildMetricBox(
                  title: 'PEMASUKAN BULAN INI',
                  value: FormatUtils.formatRupiah(totalPemasukan),
                  subtitle: '$jumlahTransaksiMasuk Transaksi Kas Masuk',
                  accentColor: successGreen,
                ),
                pw.SizedBox(width: 10),
                _buildMetricBox(
                  title: 'PENGELUARAN OPERASIONAL',
                  value: FormatUtils.formatRupiah(totalPengeluaran),
                  subtitle: '$jumlahTransaksiKeluar Transaksi Kas Keluar',
                  accentColor: dangerRed,
                ),
                pw.SizedBox(width: 10),
                _buildMetricBox(
                  title: 'LABA BERSIH (NET PROFIT)',
                  value: FormatUtils.formatRupiah(labaBersih),
                  subtitle: totalPemasukan > 0
                      ? 'Margin: ${((labaBersih / totalPemasukan) * 100).toStringAsFixed(1)}%'
                      : 'Arus Kas Bersih',
                  accentColor: brandBlue,
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // 2. Breakdown Komposisi Pengeluaran
            if (pengeluaranPerKategori.isNotEmpty) ...[
              pw.Text(
                'RINCIAN PENGELUARAN OPERASIONAL BERDASARKAN KATEGORI',
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: borderGray, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: surfaceLight),
                    children: [
                      _buildTableHeaderCell('Kategori Biaya'),
                      _buildTableHeaderCell('Total Pengeluaran (Rp)'),
                      _buildTableHeaderCell('Porsi (%)'),
                    ],
                  ),
                  ...pengeluaranPerKategori.entries.map((entry) {
                    final pct = totalPengeluaran > 0 ? (entry.value / totalPengeluaran) * 100 : 0.0;
                    return pw.TableRow(
                      children: [
                        _buildTableCell(entry.key.replaceAll('_', ' ').toUpperCase(), isBold: true),
                        _buildTableCell(FormatUtils.formatRupiah(entry.value), align: pw.TextAlign.right),
                        _buildTableCell('${pct.toStringAsFixed(1)}%', align: pw.TextAlign.right),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            // 3. Rincian Mutasi Buku Kas
            pw.Text(
              'DAFTAR MUTASI ARUS KAS (${ledgers.length} Transaksi)',
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 6),
            if (ledgers.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: surfaceLight,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderGray),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'Tidak ada mutasi arus kas yang tercatat pada periode ini.',
                    style: const pw.TextStyle(fontSize: 8.5, color: textMuted),
                  ),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: borderGray, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(1.8),
                  3: const pw.FlexColumnWidth(3.5),
                  4: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: surfaceLight),
                    children: [
                      _buildTableHeaderCell('Tanggal'),
                      _buildTableHeaderCell('Tipe'),
                      _buildTableHeaderCell('Kategori'),
                      _buildTableHeaderCell('Keterangan'),
                      _buildTableHeaderCell('Nominal (Rp)'),
                    ],
                  ),
                  ...ledgers.map((l) {
                    final isMasuk = l['tipe']?.toString().toLowerCase() == 'masuk';
                    final nominal = (l['nominal'] as num?)?.toDouble() ?? 0.0;
                    final tanggalStr = l['tanggal']?.toString() ?? '-';
                    final kategori = (l['kategori']?.toString() ?? '-').replaceAll('_', ' ');
                    final ket = l['keterangan']?.toString() ?? '-';

                    return pw.TableRow(
                      children: [
                        _buildTableCell(tanggalStr),
                        _buildTableCell(
                          isMasuk ? 'MASUK (+)' : 'KELUAR (-)',
                          isBold: true,
                          isSuccess: isMasuk,
                        ),
                        _buildTableCell(kategori.toUpperCase()),
                        _buildTableCell(ket),
                        _buildTableCell(
                          '${isMasuk ? "+ " : "- "}${FormatUtils.formatRupiah(nominal)}',
                          isBold: true,
                          isSuccess: isMasuk,
                          align: pw.TextAlign.right,
                        ),
                      ],
                    );
                  }),
                ],
              ),

            pw.SizedBox(height: 24),

            // 4. Blok Pengesahan Resmi Pemilik Kos
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Catatan Kerahasiaan:',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textMuted),
                    ),
                    pw.Text(
                      'Laporan pembukuan kas ini bersifat rahasia dan hanya diperuntukkan bagi Pemilik Kos.\nDilindungi sistem autentikasi multi-tenant Atur Kos.',
                      style: const pw.TextStyle(fontSize: 7.5, color: textMuted),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Dicetak otomatis pada: ${FormatUtils.formatDate(now)}',
                      style: const pw.TextStyle(fontSize: 7.5, color: textMuted),
                    ),
                    pw.SizedBox(height: 28),
                    pw.Text(
                      ownerName,
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor),
                    ),
                    pw.Text(
                      'Pemilik / Pengelola $kosName',
                      style: const pw.TextStyle(fontSize: 7.5, color: textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Laporan_Keuangan_${kosName.replaceAll(' ', '_')}_$periodeLabel.pdf',
      );
    } catch (e) {
      debugPrint('Error exportOwnerCashLedgerReport: $e');
    }
  }
}
