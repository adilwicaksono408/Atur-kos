/// Utilitas formatting mata uang, tanggal, dan tautan WhatsApp
class FormatUtils {
  /// Format angka ke Rupiah, misal: 1500000 -> "Rp 1.500.000"
  static String rupiah(num? amount) {
    if (amount == null) return 'Rp 0';
    final isNegative = amount < 0;
    final intVal = amount.abs().round();
    final str = intVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return '${isNegative ? "-Rp " : "Rp "}${buffer.toString()}';
  }

  /// Alias formatRupiah untuk kemudahan pemanggilan
  static String formatRupiah(num? amount) => rupiah(amount);

  /// Format angka ringkas untuk kartu KPI, misal: 1500000 -> "Rp 1,5 Jt"
  static String compactRupiah(num? amount) {
    if (amount == null || amount == 0) return 'Rp 0';
    final val = amount.toDouble();
    if (val >= 1000000000) {
      return 'Rp ${(val / 1000000000).toStringAsFixed(1).replaceAll('.', ',')} M';
    } else if (val >= 1000000) {
      final formatted = (val / 1000000).toStringAsFixed(1).replaceAll('.', ',');
      return 'Rp ${formatted.endsWith(",0") ? formatted.substring(0, formatted.length - 2) : formatted} Jt';
    } else if (val >= 1000) {
      final formatted = (val / 1000).toStringAsFixed(0);
      return 'Rp $formatted Rb';
    }
    return rupiah(amount);
  }

  /// Format tanggal standar Indonesia, misal: "1 Okt 2026"
  static String formatDate(DateTime? date) {
    if (date == null) return '-';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Format string ISO ke format tanggal Indonesia, misal: "2026-10-06T..." -> "6 Okt 2026"
  static String isoToDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final parsed = DateTime.tryParse(iso);
    return formatDate(parsed);
  }

  /// Format nomor WhatsApp ke format internasional E.164 (628xxx)
  static String sanitizeWaNumber(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '62${cleaned.substring(1)}';
    } else if (cleaned.startsWith('+62')) {
      cleaned = cleaned.substring(1);
    } else if (!cleaned.startsWith('62')) {
      cleaned = '62$cleaned';
    }
    return cleaned;
  }

  /// Buat link WhatsApp API lengkap dengan teks pesan
  static String buildWaLink(String phone, String message) {
    final sanitized = sanitizeWaNumber(phone);
    final encodedMessage = Uri.encodeComponent(message);
    return 'https://wa.me/$sanitized?text=$encodedMessage';
  }
}
