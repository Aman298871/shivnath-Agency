import 'package:flutter/material.dart';
import '../theme/brand_colors.dart';

/// The official Shivnath Agency Logo & Brand Mark widget.
///
/// Implements the exact 5 brand colors: White, Blue, Green, Yellow, Red.
/// Supports standard, horizontal, and compact icon-only variants.
class ShivnathLogo extends StatelessWidget {
  final double size;
  final bool showSubtitle;
  final bool isHorizontal;
  final bool isIconOnly;
  final Color? textColor;

  final bool useAssetImage;

  const ShivnathLogo({
    super.key,
    this.size = 56.0,
    this.showSubtitle = true,
    this.isHorizontal = false,
    this.isIconOnly = false,
    this.textColor,
    this.useAssetImage = true,
  });

  const ShivnathLogo.horizontal({
    super.key,
    this.size = 36.0,
    this.showSubtitle = false,
    this.textColor,
    this.useAssetImage = false,
  }) : isHorizontal = true,
       isIconOnly = false;

  const ShivnathLogo.appBar({
    super.key,
    this.size = 28.0,
    this.showSubtitle = false,
    this.textColor,
  }) : isHorizontal = true,
       isIconOnly = false,
       useAssetImage = true;

  const ShivnathLogo.icon({
    super.key,
    this.size = 40.0,
    this.useAssetImage = false,
  }) : showSubtitle = false,
       isHorizontal = false,
       isIconOnly = true,
       textColor = null;

  @override
  Widget build(BuildContext context) {
    if (useAssetImage && !isIconOnly && !isHorizontal) {
      return Image.asset(
        'assets/images/logo.png',
        width: size * 2.2,
        height: size * 2.2,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _buildFallbackVertical(),
      );
    }

    if (isIconOnly) {
      return _buildWaterDropletMark(size);
    }

    if (isHorizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (useAssetImage)
            Image.asset(
              'assets/images/logo.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _buildWaterDropletMark(size),
            )
          else
            _buildWaterDropletMark(size),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Water Wala',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: size * 0.58,
                    fontWeight: FontWeight.w800,
                    color: textColor ?? BrandColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                if (showSubtitle) ...[
                  const SizedBox(height: 1),
                  Text(
                    'Water Business Management',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: size * 0.28,
                      fontWeight: FontWeight.w600,
                      color: textColor ?? BrandColors.textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return _buildFallbackVertical();
  }

  Widget _buildFallbackVertical() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildWaterDropletMark(size),
        SizedBox(height: size * 0.22),
        _buildBrandText(fontSize: size * 0.38),
        if (showSubtitle) ...[
          SizedBox(height: size * 0.1),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 1.5,
                color: BrandColors.primaryBlue.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Text(
                'Water Business Management',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? BrandColors.textSecondary,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 18,
                height: 1.5,
                color: BrandColors.primaryBlue.withValues(alpha: 0.5),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Multi-color brand typography: "Water Wala"
  Widget _buildBrandText({required double fontSize}) {
    if (textColor != null) {
      return Text(
        'Water Wala',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: textColor,
          letterSpacing: -0.3,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
        ),
        children: const [
          TextSpan(
            text: 'Water',
            style: TextStyle(color: BrandColors.primaryBlue),
          ),
          TextSpan(
            text: 'Wala',
            style: TextStyle(color: BrandColors.greenDark),
          ),
        ],
      ),
    );
  }

  /// Clean vector water droplet emblem with brand gradient waves
  Widget _buildWaterDropletMark(double dimension) {
    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: BrandColors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: BrandColors.primaryBlue.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(dimension * 0.72, dimension * 0.72),
          painter: _ShivnathDropletPainter(),
        ),
      ),
    );
  }
}

/// Custom painter for the layered water droplet emblem
class _ShivnathDropletPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Outer droplet silhouette path
    final dropPath = Path();
    dropPath.moveTo(w * 0.5, 0);
    dropPath.cubicTo(w * 0.75, h * 0.35, w, h * 0.65, w * 0.5, h);
    dropPath.cubicTo(0, h * 0.65, w * 0.25, h * 0.35, w * 0.5, 0);
    dropPath.close();

    // Clip to droplet
    canvas.save();
    canvas.clipPath(dropPath);

    // 1. Base Blue Layer
    final bluePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          BrandColors.waterBlue,
          BrandColors.primaryBlue,
          BrandColors.blueDark,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bluePaint);

    // 2. Green Flowing Wave Layer
    final greenPath = Path();
    greenPath.moveTo(0, h * 0.45);
    greenPath.cubicTo(w * 0.3, h * 0.35, w * 0.6, h * 0.6, 0, h * 0.85);
    greenPath.close();

    final greenPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [BrandColors.green, BrandColors.greenDark],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(greenPath, greenPaint);

    // 3. Central White Wave Divider
    final whiteWave = Path();
    whiteWave.moveTo(w * 0.5, 0);
    whiteWave.cubicTo(w * 0.2, h * 0.3, w * 0.8, h * 0.7, w * 0.5, h);
    whiteWave.lineTo(w * 0.58, h);
    whiteWave.cubicTo(w * 0.88, h * 0.7, w * 0.28, h * 0.3, w * 0.5, 0);
    whiteWave.close();

    final whitePaint = Paint()..color = Colors.white.withValues(alpha: 0.95);
    canvas.drawPath(whiteWave, whitePaint);

    // 4. Subtle Specular Highlight on Top
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.2, -0.6),
        radius: 0.4,
        colors: [
          Colors.white.withValues(alpha: 0.7),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), highlightPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
