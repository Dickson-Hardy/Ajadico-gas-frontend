import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _nairaFormat = NumberFormat.currency(
    symbol: '₦',
    decimalDigits: 0,
  );

  static final NumberFormat _decimalNairaFormat = NumberFormat.currency(
    symbol: '₦',
    decimalDigits: 2,
  );

  static final NumberFormat _litreFormat = NumberFormat('#,##0.0', 'en_US');

  /// Formats integer or rounded Naira: e.g. ₦1,250,000
  static String formatNaira(num amount, {bool includeDecimals = false}) {
    if (includeDecimals) {
      return _decimalNairaFormat.format(amount);
    }
    return _nairaFormat.format(amount);
  }

  /// Formats signed Naira differences: e.g. −₦120, +₦500, ₦0
  static String formatVariance(num diff) {
    if (diff < 0) {
      return '−₦${NumberFormat('#,##0').format(diff.abs())}';
    } else if (diff > 0) {
      return '+₦${NumberFormat('#,##0').format(diff)}';
    }
    return '₦0';
  }

  /// Formats Litres with 1 decimal place: e.g. 412,380.5 L
  static String formatLitres(num litres) {
    return '${_litreFormat.format(litres)} L';
  }
}
