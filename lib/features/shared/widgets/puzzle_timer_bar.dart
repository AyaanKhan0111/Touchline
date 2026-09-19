import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';

/// Timer bar V2 — thin progress bar with color transitions.
class PuzzleTimerBar extends StatelessWidget {
  final int remainingSeconds;
  final int totalSeconds;
  final bool isRunning;
  final VoidCallback? onTimeUp;

  const PuzzleTimerBar({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.isRunning = true,
    this.onTimeUp,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppPalette.darkInk : AppPalette.lightInk;
    final inkMuted = isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted;

    final progress = totalSeconds > 0 ? (remainingSeconds / totalSeconds).clamp(0.0, 1.0) : 0.0;

    Color barColor;
    if (progress > 0.4) {
      barColor = AppPalette.green;
    } else if (progress > 0.15) {
      barColor = AppPalette.amber;
    } else {
      barColor = AppPalette.red;
    }

    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final timeFormatted = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Time', style: AppTypography.caption(inkMuted)),
            Text(timeFormatted, style: AppTypography.timerDisplay(ink)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: isDark ? AppPalette.darkBorder : AppPalette.lightBorder,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}
