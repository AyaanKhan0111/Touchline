import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';

/// Player Avatar V2 — Circle with a position-coded colored ring.
/// GK = gold ring, DEF = green ring, MID = blue ring, FWD = red ring.
/// Gives instant visual position identification.
class PlayerAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;
  final String? position;

  const PlayerAvatar({
    super.key,
    required this.name,
    this.size = 36,
    this.backgroundColor,
    this.textColor,
    this.position,
  });

  String _getInitials() {
    if (name.isEmpty) return '??';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final s = parts[0];
      return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ?? (isDark ? AppPalette.darkHover : AppPalette.lightHover);
    final fg = textColor ?? (isDark ? AppPalette.darkInk : AppPalette.lightInk);
    final ringColor = position != null
        ? AppPalette.positionColor(position!)
        : (isDark ? AppPalette.darkBorder : AppPalette.lightBorder);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: ringColor,
          width: size > 30 ? 2.5 : 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _getInitials(),
        style: TextStyle(
          fontFamily: AppTypography.bodyFamily,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
