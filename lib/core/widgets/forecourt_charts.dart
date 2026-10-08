import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';

/// 7-Day Forecourt Sales Trend Chart (PMS & AGO volume and revenue sparkline).
class Forecourt7DaySalesChart extends StatefulWidget {
  final List<DailySalesPoint>? dataPoints;
  final bool isCompact;

  const Forecourt7DaySalesChart({
    super.key,
    this.dataPoints,
    this.isCompact = false,
  });

  @override
  State<Forecourt7DaySalesChart> createState() => _Forecourt7DaySalesChartState();
}

class DailySalesPoint {
  final String dayLabel;
  final double pmsLitres;
  final double agoLitres;
  final double revenue;

  DailySalesPoint({
    required this.dayLabel,
    required this.pmsLitres,
    required this.agoLitres,
    required this.revenue,
  });

  double get totalLitres => pmsLitres + agoLitres;
}

class _Forecourt7DaySalesChartState extends State<Forecourt7DaySalesChart> {
  int? _selectedIndex;

  List<DailySalesPoint> _getEffectiveData() {
    // Zero demo data: only real aggregated sales history is ever rendered.
    return widget.dataPoints ?? const <DailySalesPoint>[];
  }

  @override
  Widget build(BuildContext context) {
    final data = _getEffectiveData();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkLine : AppColors.line),
        ),
        child: Column(
          children: [
            Icon(Icons.show_chart_outlined, size: 36, color: isDark ? AppColors.darkMuted : AppColors.muted),
            const SizedBox(height: 10),
            Text(
              'No sales history yet',
              style: AppTypography.title(
                fontSize: 14,
                color: isDark ? AppColors.darkInk : AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'The 7-day trend fills in automatically from verified shift sales once data is synced from Supabase.',
              style: AppTypography.caption(
                fontSize: 12,
                color: isDark ? AppColors.darkMuted : AppColors.muted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final maxLitres = data.map((d) => d.totalLitres).reduce(math.max);
    final totalWeekRevenue = data.fold(0.0, (sum, d) => sum + d.revenue);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkLine : AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.ok.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.show_chart, size: 18, color: AppColors.ok),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '7-Day Forecourt Sales Trend',
                        style: AppTypography.title(
                          fontSize: 15,
                          color: isDark ? AppColors.darkInk : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '7-day throughput: ${CurrencyFormatter.formatNaira(totalWeekRevenue)}',
                    style: AppTypography.caption(
                      color: isDark ? AppColors.darkMuted : AppColors.muted,
                    ),
                  ),
                ],
              ),
              // Product Legend
              Row(
                children: [
                  _buildLegendIndicator('PMS', AppColors.emerald),
                  const SizedBox(width: 12),
                  _buildLegendIndicator('AGO', AppColors.accent),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Chart Canvas / Interactive Area
          SizedBox(
            height: widget.isCompact ? 120 : 160,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (details) {
                    final width = constraints.maxWidth;
                    final step = width / data.length;
                    final index = (details.localPosition.dx / step).floor().clamp(0, data.length - 1);
                    setState(() {
                      _selectedIndex = _selectedIndex == index ? null : index;
                    });
                  },
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _ForecourtSalesPainter(
                      data: data,
                      maxVal: maxLitres * 1.15,
                      selectedIndex: _selectedIndex,
                      isDark: isDark,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // X-Axis Day Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(data.length, (i) {
              final isSel = _selectedIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = isSel ? null : i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSel ? (isDark ? AppColors.emerald.withValues(alpha: 0.2) : AppColors.okSurface) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: isSel ? Border.all(color: AppColors.ok, width: 1) : null,
                  ),
                  child: Text(
                    data[i].dayLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      color: isSel ? AppColors.ok : (isDark ? AppColors.darkMuted : AppColors.muted),
                    ),
                  ),
                ),
              );
            }),
          ),

          // Active Touch Detail Drawer
          if (_selectedIndex != null && _selectedIndex! < data.length) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141F32) : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? AppColors.darkLine : AppColors.line),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${data[_selectedIndex!].dayLabel} Performance:',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Row(
                    children: [
                      Text(
                        'PMS: ${CurrencyFormatter.formatLitres(data[_selectedIndex!].pmsLitres)}',
                        style: TextStyle(fontSize: 12, color: isDark ? AppColors.emerald : AppColors.okInk, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AGO: ${CurrencyFormatter.formatLitres(data[_selectedIndex!].agoLitres)}',
                        style: TextStyle(fontSize: 12, color: isDark ? AppColors.accent : AppColors.bank, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CurrencyFormatter.formatNaira(data[_selectedIndex!].revenue),
                        style: AppTypography.monoNumeric(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendIndicator(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ForecourtSalesPainter extends CustomPainter {
  final List<DailySalesPoint> data;
  final double maxVal;
  final int? selectedIndex;
  final bool isDark;

  _ForecourtSalesPainter({
    required this.data,
    required this.maxVal,
    required this.selectedIndex,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final pmsPaint = Paint()
      ..color = AppColors.emerald
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final agoPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)
      ..strokeWidth = 1.0;

    // Draw horizontal guidelines
    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final stepX = size.width / (data.length - 1);
    final pmsPath = Path();
    final agoPath = Path();
    final pmsAreaPath = Path();

    final pmsPoints = <Offset>[];
    final agoPoints = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final pmsY = size.height - ((data[i].pmsLitres / maxVal) * size.height);
      final agoY = size.height - ((data[i].agoLitres / maxVal) * size.height);

      final pmsPoint = Offset(x, pmsY);
      final agoPoint = Offset(x, agoY);
      pmsPoints.add(pmsPoint);
      agoPoints.add(agoPoint);

      if (i == 0) {
        pmsPath.moveTo(x, pmsY);
        pmsAreaPath.moveTo(x, size.height);
        pmsAreaPath.lineTo(x, pmsY);
        agoPath.moveTo(x, agoY);
      } else {
        // Smooth Bezier interpolation
        final prevX = (i - 1) * stepX;
        final prevPmsY = size.height - ((data[i - 1].pmsLitres / maxVal) * size.height);
        final prevAgoY = size.height - ((data[i - 1].agoLitres / maxVal) * size.height);

        final ctrlX = (prevX + x) / 2;
        pmsPath.cubicTo(ctrlX, prevPmsY, ctrlX, pmsY, x, pmsY);
        pmsAreaPath.cubicTo(ctrlX, prevPmsY, ctrlX, pmsY, x, pmsY);
        agoPath.cubicTo(ctrlX, prevAgoY, ctrlX, agoY, x, agoY);
      }
    }

    // Complete PMS area gradient
    pmsAreaPath.lineTo(size.width, size.height);
    pmsAreaPath.close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.emerald.withValues(alpha: 0.25),
          AppColors.emerald.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(pmsAreaPath, areaPaint);
    canvas.drawPath(pmsPath, pmsPaint);
    canvas.drawPath(agoPath, agoPaint);

    // Draw active data point markers
    for (int i = 0; i < data.length; i++) {
      final isSel = selectedIndex == i;
      final radius = isSel ? 6.0 : 3.5;

      // Draw PMS dot
      final pmsDotPaint = Paint()
        ..color = isSel ? Colors.white : AppColors.emerald
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pmsPoints[i], radius, pmsDotPaint);
      if (isSel) {
        canvas.drawCircle(
          pmsPoints[i],
          radius,
          Paint()
            ..color = AppColors.emerald
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      // Draw AGO dot
      final agoDotPaint = Paint()
        ..color = isSel ? Colors.white : AppColors.accent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(agoPoints[i], radius, agoDotPaint);
      if (isSel) {
        canvas.drawCircle(
          agoPoints[i],
          radius,
          Paint()
            ..color = AppColors.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ForecourtSalesPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex || oldDelegate.isDark != isDark;
  }
}

/// Underground Fuel Tanks (UST) Depletion Trend & Capacity Visualizer
class TankDepletionTrendCard extends StatelessWidget {
  final String product;
  final String tankCode;
  final double capacity;
  final double physicalDip;
  final double bookStock;
  final double reorderThreshold;

  const TankDepletionTrendCard({
    super.key,
    required this.product,
    required this.tankCode,
    required this.capacity,
    required this.physicalDip,
    required this.bookStock,
    this.reorderThreshold = 0.20,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillRatio = capacity > 0 ? (physicalDip / capacity).clamp(0.0, 1.0) : 0.0;
    final ullage = (capacity - physicalDip).clamp(0.0, capacity);
    final variance = physicalDip - bookStock;
    final isLow = fillRatio <= reorderThreshold;
    final color = product == 'PMS' ? AppColors.emerald : AppColors.accent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkLine : AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$product · $tankCode',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  if (isLow) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.badSurface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.bad),
                      ),
                      child: const Text(
                        'LOW STOCK',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.bad),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '${(fillRatio * 100).toStringAsFixed(1)}%',
                style: AppTypography.monoNumeric(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isLow ? AppColors.bad : (isDark ? AppColors.darkInk : AppColors.ink),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Horizontal Progress Bar with 20% reorder marker
          Stack(
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141F32) : AppColors.background,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fillRatio,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.7), color],
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
              // 20% Reorder threshold needle marker
              Positioned(
                left: null,
                right: null,
                top: 0,
                bottom: 0,
                child: LayoutBuilder(
                  builder: (context, c) {
                    return Container(); // Marker placeholder
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Physical Dip', style: AppTypography.caption(color: isDark ? AppColors.darkMuted : AppColors.muted)),
                  Text(CurrencyFormatter.formatLitres(physicalDip), style: AppTypography.monoNumeric(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tanker Ullage Space', style: AppTypography.caption(color: isDark ? AppColors.darkMuted : AppColors.muted)),
                  Text(CurrencyFormatter.formatLitres(ullage), style: AppTypography.monoNumeric(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ok)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Dip Variance', style: AppTypography.caption(color: isDark ? AppColors.darkMuted : AppColors.muted)),
                  Text(
                    '${variance >= 0 ? "+" : ""}${variance.toStringAsFixed(0)} L',
                    style: AppTypography.monoNumeric(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: variance < -50 ? AppColors.bad : (variance > 50 ? AppColors.ok : AppColors.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
