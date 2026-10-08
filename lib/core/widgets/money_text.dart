import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';

/// Renders a financial figure with tabular monospace numerals
/// to guarantee zero jitter in tables, columns, and ticker dials.
class MoneyText extends StatelessWidget {
  final num amount;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final bool includeDecimals;
  final bool isVariance;
  final String? prefix;
  final String? suffix;

  const MoneyText(
    this.amount, {
    super.key,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w700,
    this.color,
    this.includeDecimals = false,
    this.isVariance = false,
    this.prefix,
    this.suffix,
  });

  /// Hero-scale financial display for executive cards
  const MoneyText.hero(
    this.amount, {
    super.key,
    this.fontSize = 32,
    this.fontWeight = FontWeight.w800,
    this.color = Colors.white,
    this.includeDecimals = false,
    this.prefix,
    this.suffix,
  }) : isVariance = false;

  /// High-contrast variance indicator (+₦500 or -₦1,200)
  const MoneyText.variance(
    this.amount, {
    super.key,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w700,
    this.color,
    this.prefix,
    this.suffix,
  })  : isVariance = true,
        includeDecimals = false;

  @override
  Widget build(BuildContext context) {
    Color textColor = color ?? (Theme.of(context).brightness == Brightness.dark ? AppColors.darkInk : AppColors.ink);

    String formatted;
    if (isVariance) {
      formatted = CurrencyFormatter.formatVariance(amount);
      if (color == null) {
        if (amount < -1.0) {
          textColor = AppColors.bad;
        } else if (amount > 1.0) {
          textColor = AppColors.ok;
        } else {
          textColor = AppColors.muted;
        }
      }
    } else {
      formatted = CurrencyFormatter.formatNaira(amount, includeDecimals: includeDecimals);
    }

    final displayText = '${prefix ?? ''}$formatted${suffix ?? ''}';

    return Text(
      displayText,
      style: AppTypography.monoNumeric(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: textColor,
      ),
    );
  }
}
