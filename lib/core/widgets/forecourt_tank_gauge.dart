import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/currency_formatter.dart';

/// Industrial Graphical Underground Storage Tank (UST) Level Visualizer
/// Displays physical dip vs book stock, real-time ullage, and color-coded threshold safety.
class ForecourtTankGauge extends StatelessWidget {
  final String tankCode;
  final String productName; // 'PMS' or 'AGO'
  final double capacityLitres;
  final double currentLitres;
  final double? calculatedStockLitres;
  final String? stationName;
  final DateTime? lastDipTime;
  final VoidCallback? onTap;
  final bool isCompact;

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
  });

  double get fillRatio => (currentLitres / (capacityLitres > 0 ? capacityLitres : 1)).clamp(0.0, 1.0);
  double get bookStockRatio => calculatedStockLitres != null
      ? (calculatedStockLitres! / (capacityLitres > 0 ? capacityLitres : 1)).clamp(0.0, 1.0)
      : fillRatio;

  double get ullageLitres => (capacityLitres - currentLitres).clamp(0.0, capacityLitres);
  double get varianceLitres => calculatedStockLitres != null ? (currentLitres - calculatedStockLitres!) : 0.0;

  bool get isPms => productName.toUpperCase() == 'PMS';
  bool get isCritical => fillRatio < 0.15;
  bool get isLow => fillRatio >= 0.15 && fillRatio < 0.30;

  @override
  Widget build(BuildContext context) {
    final fuelGradient = isPms
        ? const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xFFC2410C), Color(0xFFF97316), Color(0xFFFBBF24)],
          )
        : const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xFF047857), Color(0xFF10B981), Color(0xFF34D399)],
          );

    final statusColor = isCritical
        ? AppColors.bad
        : (isLow ? AppColors.warn : AppColors.ok);

    final statusText = isCritical
        ? 'CRITICAL DEADSTOCK'
        : (isLow ? 'LOW STOCK (REORDER)' : 'SAFE OPERATING LEVEL');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCritical
              ? AppColors.bad.withValues(alpha: 0.6)
              : (isLow ? AppColors.warn.withValues(alpha: 0.5) : AppColors.line),
          width: isCritical ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row: Tank Code, Product, Station, and Percentage
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPms ? AppColors.warnSurface : AppColors.okSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isPms
                            ? AppColors.amber.withValues(alpha: 0.5)
                            : AppColors.emerald.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '$tankCode · $productName',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isCompact ? 13 : 15,
                        color: isPms ? AppColors.warnInk : AppColors.okInk,
                      ),
                    ),
                  ),
                  if (stationName != null)
                    Text(
                      stationName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(fillRatio * 100).toStringAsFixed(1)}% Full',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isCompact ? 12 : 14,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Visual Tank Cylinder Graphic
              _buildTankCylinder(context, fuelGradient),

              const SizedBox(height: 12),

              // Tank Metrics: Physical Dip, Calculated Stock, Ullage, Variance
              if (isCompact) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      CurrencyFormatter.formatLitres(currentLitres),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.ink),
                    ),
                    Text(
                      'Ullage: ${CurrencyFormatter.formatLitres(ullageLitres)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCol(
                        'Physical Dip',
                        CurrencyFormatter.formatLitres(currentLitres),
                        subtitle: 'Capacity: ${CurrencyFormatter.formatLitres(capacityLitres)}',
                      ),
                    ),
                    if (calculatedStockLitres != null)
                      Expanded(
                        child: _buildMetricCol(
                          'Book Stock',
                          CurrencyFormatter.formatLitres(calculatedStockLitres!),
                          subtitle: varianceLitres == 0
                              ? 'Balanced'
                              : (varianceLitres < 0
                                  ? '${CurrencyFormatter.formatLitres(varianceLitres.abs())} deficit'
                                  : '+${CurrencyFormatter.formatLitres(varianceLitres)} surplus'),
                          subtitleColor: varianceLitres < -50
                              ? AppColors.bad
                              : (varianceLitres > 50 ? AppColors.ok : AppColors.muted),
                        ),
                      ),
                    Expanded(
                      child: _buildMetricCol(
                        'Discharge Ullage',
                        CurrencyFormatter.formatLitres(ullageLitres),
                        subtitle: 'Free Tanker Room',
                        highlight: ullageLitres >= 33000,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        statusText,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (lastDipTime != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Dip: ${_formatTime(lastDipTime!)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTankCylinder(BuildContext context, Gradient fuelGradient) {
    final tankHeight = isCompact ? 36.0 : 54.0;

    return Container(
      height: tankHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Dark subterranean vault steel interior
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.5),
        child: Stack(
          children: [
            // Liquid Level Fill (rises from the bottom of the vault)
            FractionallySizedBox(
              heightFactor: fillRatio,
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: fuelGradient,
                  boxShadow: [
                    BoxShadow(
                      color: (isPms ? const Color(0xFFF97316) : const Color(0xFF10B981))
                          .withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),

            // Book Stock Indicator Line (calculated stock marker across the vault)
            if (calculatedStockLitres != null && (calculatedStockLitres! - currentLitres).abs() > 20)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final maxOffset = box.maxHeight > 2 ? box.maxHeight - 2 : 0.0;
                    final markerBottom = (box.maxHeight * bookStockRatio).clamp(0.0, maxOffset);
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Transform.translate(
                        offset: Offset(0, -markerBottom),
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(1),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Ullage (Empty Space) Marker & Volume Indicator
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    // Fuel Type & Level
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_gas_station,
                            size: isCompact ? 14 : 18,
                            color: fillRatio > 0.25 ? Colors.white : Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${CurrencyFormatter.formatLitres(currentLitres)} in Tank',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isCompact ? 12 : 13,
                                fontWeight: FontWeight.bold,
                                shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Ullage Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Ullage: ${CurrencyFormatter.formatLitres(ullageLitres)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, {String? subtitle, Color? subtitleColor, bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: highlight ? AppColors.primary : AppColors.ink,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 1),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: subtitleColor ?? AppColors.muted,
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
