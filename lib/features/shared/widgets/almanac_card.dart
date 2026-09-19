import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';

/// Touchline Card System V2
/// Three distinct card variants replacing the generic bordered AlmanacCard:
///
/// 1. [AlmanacCard] — Default subtle card. Surface-raised background, no border by default.
///    Used for data containers, settings, stat tables.
///
/// 2. [HeroCard] — Gradient-accented card for featured/highlighted content.
///    Used for career banner, daily challenge hero, featured mode.
///
/// 3. [ActionCard] — Accent left-border card for calls-to-action.
///    Used for "play this mode" tiles, transfer actions.
class AlmanacCard extends StatelessWidget {
  final Widget child;
  final String? sectionTitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  const AlmanacCard({
    super.key,
    required this.child,
    this.sectionTitle,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppPalette.darkCard : AppPalette.lightCard;
    final inkMuted = isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted;

    Widget content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sectionTitle != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  sectionTitle!.toUpperCase(),
                  style: AppTypography.sectionHeader(inkMuted),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashFactory: InkSparkle.splashFactory,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1.5)
                : null,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Hero Card — gradient accent background for featured content.
class HeroCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final List<Color>? gradientColors;
  final EdgeInsetsGeometry padding;

  const HeroCard({
    super.key,
    required this.child,
    this.onTap,
    this.gradientColors,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = gradientColors ?? [
      isDark ? const Color(0xFF1A2535) : const Color(0xFFF0EDE5),
      isDark ? const Color(0xFF141820) : const Color(0xFFFFFFFF),
    ];

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashFactory: InkSparkle.splashFactory,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppPalette.darkBorder.withValues(alpha: 0.5)
                  : AppPalette.lightBorder.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Action Card — left accent border for CTAs and playable mode tiles.
class ActionCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color accentColor;
  final EdgeInsetsGeometry padding;

  const ActionCard({
    super.key,
    required this.child,
    this.onTap,
    this.accentColor = AppPalette.gold,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashFactory: InkSparkle.splashFactory,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: accentColor, width: 3),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
