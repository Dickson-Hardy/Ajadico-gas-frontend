import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/currency_formatter.dart';

/// Recorded volume as a share of capacity, not a simulation of physical fuel height.
class ForecourtTankGauge extends StatelessWidget {
  final String tankCode;
  final String productName;
  final double capacityLitres;
  final double currentLitres;
  final double? calculatedStockLitres;
  final String? stationName;
  final DateTime? lastDipTime;
  final VoidCallback? onTap;
  final bool isCompact;
  final bool isDraft;

  const ForecourtTankGauge({
    super.key,
    required this.tankCode,
    required this.productName,
    required this.capacityLitres,
    required this.currentLitres,
    this.calculatedStockLitres,
    this.stationName,
    this.lastDipTime,
    this.onTap,
    this.isCompact = false,
    this.isDraft = false,
  });

  bool get hasCapacity => capacityLitres.isFinite && capacityLitres > 0;
  bool get hasReading => currentLitres.isFinite && currentLitres >= 0;
  bool get hasBookStock =>
      calculatedStockLitres != null &&
      calculatedStockLitres!.isFinite &&
      calculatedStockLitres! >= 0;
  bool get exceedsCapacity =>
      hasCapacity && hasReading && currentLitres > capacityLitres;
  double get fillRatio => hasCapacity && hasReading
      ? (currentLitres / capacityLitres).clamp(0.0, 1.0)
      : 0;
  double get ullageLitres => hasCapacity && hasReading
      ? (capacityLitres - currentLitres).clamp(0.0, capacityLitres)
      : 0;
  double get varianceLitres =>
      hasReading && hasBookStock ? currentLitres - calculatedStockLitres! : 0;

  String get readingNote => isDraft
      ? 'Unsaved measurement'
      : lastDipTime == null
          ? 'Reading time not recorded'
          : 'Recorded ${DateFormat('d MMM yyyy · HH:mm').format(lastDipTime!.toLocal())}';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final usable = hasCapacity && hasReading;
    final percent = usable
        ? (currentLitres / capacityLitres * 100).toStringAsFixed(1)
        : null;
    final metrics = <Widget>[
      _metric(
          context,
          'Available capacity (ullage)',
          usable
              ? CurrencyFormatter.formatLitres(ullageLitres)
              : 'Unavailable'),
      if (calculatedStockLitres != null)
        _metric(
            context,
            'Book stock',
            hasBookStock
                ? CurrencyFormatter.formatLitres(calculatedStockLitres!)
                : 'Unavailable'),
      if (calculatedStockLitres != null)
        _metric(
            context,
            'Difference from book stock',
            hasReading && hasBookStock
                ? '${varianceLitres > 0 ? '+' : varianceLitres < 0 ? '−' : ''}${CurrencyFormatter.formatLitres(varianceLitres.abs())}'
                : 'Unavailable'),
    ];

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.outlineVariant)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Tank $tankCode',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(productName,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurfaceVariant)),
                    ),
                  ]),
              if (stationName != null && stationName!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(stationName!,
                    style: TextStyle(
                        fontSize: 12, color: colors.onSurfaceVariant)),
              ],
              const SizedBox(height: 18),
              Text(isDraft ? 'Entered dip volume' : 'Recorded dip volume',
                  style:
                      TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(
                  hasReading
                      ? CurrencyFormatter.formatLitres(currentLitres)
                      : 'Measurement unavailable',
                  style: TextStyle(
                      fontSize: isCompact ? 24 : 28,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface)),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 4, children: [
                Text(
                    percent == null
                        ? 'Fill percentage unavailable'
                        : '$percent% of capacity',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface)),
                Text(
                    hasCapacity
                        ? 'Capacity ${CurrencyFormatter.formatLitres(capacityLitres)}'
                        : 'Capacity not configured',
                    style: TextStyle(
                        fontSize: 12, color: colors.onSurfaceVariant)),
              ]),
              const SizedBox(height: 8),
              if (usable)
                LinearProgressIndicator(
                  key: const ValueKey('tank-capacity-bar'),
                  value: usable ? fillRatio : 0,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                  backgroundColor: colors.surfaceContainerHighest,
                  color: exceedsCapacity ? colors.error : colors.primary,
                  semanticsLabel:
                      'Tank $tankCode volume as a share of capacity',
                  semanticsValue: (fillRatio * 100).toStringAsFixed(1),
                )
              else
                Container(
                    height: 10,
                    decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(5))),
              if (exceedsCapacity) ...[
                const SizedBox(height: 10),
                Text(
                    'Recorded volume exceeds capacity. Check the measurement and tank setup.',
                    style: TextStyle(fontSize: 12, color: colors.error)),
              ],
              const SizedBox(height: 16),
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 480
                    ? metrics.length
                    : constraints.maxWidth >= 260
                        ? 2
                        : 1;
                final width =
                    (constraints.maxWidth - 16 * (columns - 1)) / columns;
                return Wrap(
                    spacing: 16,
                    runSpacing: 14,
                    children: metrics
                        .map((metric) => SizedBox(width: width, child: metric))
                        .toList());
              }),
              const SizedBox(height: 16),
              Text(readingNote,
                  style:
                      TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface)),
          ]);
}
