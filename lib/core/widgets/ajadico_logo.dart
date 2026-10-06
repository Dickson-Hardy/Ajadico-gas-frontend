import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Renders the official Ajadico Energy emblem and typography.
///
/// Supports 4 presentation modes:
/// - [AjadicoLogo.emblem]: Isolated circular emblem with fuel droplet, gas flame, and energy swoosh.
/// - [AjadicoLogo.stacked]: Vertical emblem + bold brand typography (ideal for login screens).
/// - [AjadicoLogo.horizontal]: Wide lockup for AppBars, dialog headers, and PDF summaries.
/// - [AjadicoLogo.monochrome]: High-contrast 1-bit black/white silhouette for thermal POS receipts.
class AjadicoLogo extends StatelessWidget {
  final double size;
  final bool isHorizontal;
  final bool isMonochrome;
  final bool showSubtitle;
  final Color? textColor;

  const AjadicoLogo({
    super.key,
    this.size = 48,
    this.isHorizontal = false,
    this.isMonochrome = false,
    this.showSubtitle = false,
    this.textColor,
  });

  /// 1:1 circular/shield emblem
  const AjadicoLogo.emblem({
    super.key,
    this.size = 48,
    this.isMonochrome = false,
  })  : isHorizontal = false,
        showSubtitle = false,
        textColor = null;

  /// Stacked emblem with brand text below
  const AjadicoLogo.stacked({
    super.key,
    this.size = 72,
    this.showSubtitle = true,
    this.isMonochrome = false,
    this.textColor,
  }) : isHorizontal = false;

  /// Wide horizontal lockup for AppBars and dialog headers
  const AjadicoLogo.horizontal({
    super.key,
    this.size = 36,
    this.showSubtitle = true,
    this.isMonochrome = false,
    this.textColor,
  }) : isHorizontal = true;

  /// High-contrast 1-bit monochrome style for thermal POS receipt stencils
  const AjadicoLogo.monochrome({
    super.key,
    this.size = 48,
    this.isHorizontal = false,
    this.showSubtitle = false,
  })  : isMonochrome = true,
        textColor = Colors.black;

  @override
  Widget build(BuildContext context) {
    if (isHorizontal) {
      return _buildHorizontalLayout();
    } else if (showSubtitle) {
      return _buildStackedLayout();
    } else {
      return _buildEmblemWidget(size);
    }
  }

  Widget _buildHorizontalLayout() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildEmblemWidget(size),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AJADICO ENERGY',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: size * 0.44,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: textColor ?? (isMonochrome ? Colors.black : AppColors.ink),
                height: 1.1,
              ),
            ),
            if (showSubtitle) ...[
              const SizedBox(height: 1),
              Text(
                'RETAIL PETROLEUM & GAS',
                style: TextStyle(
                  fontSize: size * 0.24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: isMonochrome ? Colors.black87 : AppColors.muted,
                  height: 1.1,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStackedLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildEmblemWidget(size),
        const SizedBox(height: 12),
        Text(
          'AJADICO ENERGY',
          style: TextStyle(
            fontSize: size * 0.28,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: textColor ?? (isMonochrome ? Colors.black : AppColors.ink),
          ),
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 2),
          Text(
            'Retail Petroleum & Gas Stations',
            style: TextStyle(
              fontSize: size * 0.17,
              fontWeight: FontWeight.w600,
              color: isMonochrome ? Colors.black54 : AppColors.muted,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmblemWidget(double s) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: isMonochrome ? Colors.white : AppColors.ink,
        borderRadius: BorderRadius.circular(s * 0.22),
        border: isMonochrome ? Border.all(color: Colors.black, width: 2) : null,
        boxShadow: isMonochrome
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(s * 0.22),
        child: CustomPaint(
          size: Size(s, s),
          painter: _AjadicoEmblemPainter(isMonochrome: isMonochrome),
        ),
      ),
    );
  }
}

/// Custom vector painter creating the exact geometry:
/// - Amber-gold Left Wing of the "A"
/// - Emerald-green Right Flame/Wing of the "A"
/// - Royal-blue Central Fuel Droplet
/// - Dynamic Orbiting Energy Ring
class _AjadicoEmblemPainter extends CustomPainter {
  final bool isMonochrome;

  _AjadicoEmblemPainter({required this.isMonochrome});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Palette
    final goldColor = isMonochrome ? Colors.black : const Color(0xFFEAA023);
    final greenColor = isMonochrome ? Colors.black : const Color(0xFF10A37F);
    final blueColor = isMonochrome ? Colors.black : const Color(0xFF2563EB);
    final swooshColor = isMonochrome ? Colors.black : const Color(0xFFF59E0B);

    final paintGold = Paint()
      ..color = goldColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final paintGreen = Paint()
      ..color = greenColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final paintBlue = Paint()
      ..color = blueColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final paintSwoosh = Paint()
      ..color = swooshColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // 1. Left Wing of "A" (Amber Gold)
    final pathLeft = Path();
    pathLeft.moveTo(w * 0.50, h * 0.22);
    pathLeft.lineTo(w * 0.50, h * 0.38);
    pathLeft.lineTo(w * 0.38, h * 0.65);
    pathLeft.lineTo(w * 0.22, h * 0.78);
    pathLeft.lineTo(w * 0.18, h * 0.68);
    pathLeft.lineTo(w * 0.44, h * 0.22);
    pathLeft.close();
    canvas.drawPath(pathLeft, paintGold);

    // 2. Right Wing & Gas Flame of "A" (Emerald Green)
    final pathRight = Path();
    pathRight.moveTo(w * 0.50, h * 0.22);
    pathRight.lineTo(w * 0.62, h * 0.38);
    // Stylized flame flicks
    pathRight.quadraticBezierTo(w * 0.72, h * 0.28, w * 0.68, h * 0.16);
    pathRight.quadraticBezierTo(w * 0.82, h * 0.32, w * 0.78, h * 0.50);
    pathRight.quadraticBezierTo(w * 0.82, h * 0.60, w * 0.76, h * 0.76);
    pathRight.lineTo(w * 0.62, h * 0.76);
    pathRight.lineTo(w * 0.50, h * 0.48);
    pathRight.close();
    canvas.drawPath(pathRight, paintGreen);

    // 3. Central Petroleum Droplet (Royal Blue)
    final pathDrop = Path();
    pathDrop.moveTo(w * 0.48, h * 0.46);
    pathDrop.quadraticBezierTo(w * 0.38, h * 0.56, w * 0.38, h * 0.66);
    pathDrop.quadraticBezierTo(w * 0.38, h * 0.74, w * 0.48, h * 0.74);
    pathDrop.quadraticBezierTo(w * 0.58, h * 0.74, w * 0.58, h * 0.66);
    pathDrop.quadraticBezierTo(w * 0.58, h * 0.56, w * 0.48, h * 0.46);
    pathDrop.close();
    canvas.drawPath(pathDrop, paintBlue);

    // 4. Orbiting Energy Ring (Swoosh)
    final pathSwoosh = Path();
    pathSwoosh.moveTo(w * 0.18, h * 0.56);
    pathSwoosh.quadraticBezierTo(w * 0.50, h * 0.82, w * 0.82, h * 0.46);
    canvas.drawPath(pathSwoosh, paintSwoosh);
  }

  @override
  bool shouldRepaint(covariant _AjadicoEmblemPainter oldDelegate) {
    return oldDelegate.isMonochrome != isMonochrome;
  }
}
