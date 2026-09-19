import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';

/// Shield-shaped Club Badge V2
/// Uses a ClipPath shield silhouette instead of a plain rounded square.
/// Team color from DB (or accent default), monogram inside.
class ClubBadge extends StatelessWidget {
  final String code;
  final Color primaryColor;
  final Color secondaryColor;
  final double size;

  const ClubBadge({
    super.key,
    required this.code,
    this.primaryColor = AppPalette.gold,
    this.secondaryColor = Colors.white,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final cleanCode = code.length > 3 ? code.substring(0, 3) : code;

    return SizedBox(
      width: size,
      height: size * 1.15,
      child: ClipPath(
        clipper: _ShieldClipper(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primaryColor,
                primaryColor.withValues(alpha: 0.7),
              ],
            ),
          ),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              cleanCode.toUpperCase(),
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: size * 0.32,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: secondaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shield/crest shape clipper
class _ShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;

    return Path()
      // Top-left corner with slight curve
      ..moveTo(0, h * 0.08)
      ..quadraticBezierTo(0, 0, w * 0.08, 0)
      // Top edge
      ..lineTo(w * 0.92, 0)
      ..quadraticBezierTo(w, 0, w, h * 0.08)
      // Right edge down to curve point
      ..lineTo(w, h * 0.55)
      // Bottom right curve to point
      ..quadraticBezierTo(w, h * 0.75, w * 0.5, h)
      // Bottom left curve from point
      ..quadraticBezierTo(0, h * 0.75, 0, h * 0.55)
      // Left edge back to start
      ..lineTo(0, h * 0.08)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
