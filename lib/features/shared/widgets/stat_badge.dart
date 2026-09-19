import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';

/// Rating Badge V2 — Shield/hex-inspired shape with rating color tier.
/// Replaces the plain pill-shaped badge with a more premium, game-like feel.
class StatBadge extends StatelessWidget {
  final int value;
  final String? label;
  final bool isLarge;

  const StatBadge({
    super.key,
    required this.value,
    this.label,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppPalette.ratingColor(value);
    final size = isLarge ? 48.0 : 36.0;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HexPainter(
          fillColor: color.withValues(alpha: 0.15),
          borderColor: color.withValues(alpha: 0.6),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null)
                Text(
                  label!.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: isLarge ? 8 : 7,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.3,
                    height: 1.0,
                  ),
                ),
              Text(
                value.toString(),
                style: AppTypography.statNumber(
                  color,
                  fontSize: isLarge ? 16 : 13,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Position Badge — clean, themed position chip with color coding.
class PositionBadge extends StatelessWidget {
  final String position;
  final bool isSmall;

  const PositionBadge({
    super.key,
    required this.position,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppPalette.positionColor(position);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 8,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Text(
        position.toUpperCase(),
        style: TextStyle(
          fontFamily: AppTypography.bodyFamily,
          fontSize: isSmall ? 9 : 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}


/// Hexagonal painter for the badge shape
class _HexPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;

  _HexPainter({required this.fillColor, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _hexPath(size);
    canvas.drawPath(
      path,
      Paint()..color = fillColor..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 1.2,
    );
  }

  Path _hexPath(Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = min(w, h) / 2 - 1;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      // Start from top vertex (-90 degrees offset)
      final angle = (pi / 3) * i - pi / 2;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
