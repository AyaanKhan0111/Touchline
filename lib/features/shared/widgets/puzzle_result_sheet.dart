import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';

/// Modal result sheet V2 — premium editorial finish screen.
void showPuzzleResultSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String modeTitle,
  required String modeCode,
  required int score,
  required int maxScore,
  required int timeSeconds,
  required int coinsEarned,
  double? rarityScore,
  String? revealedAnswer,
  required String shareableText,
  required VoidCallback onPlayAgain,
  VoidCallback? onHome,
}) {
  final date = DateTime.now().toIso8601String().substring(0, 10);
  ref.read(saveServiceProvider).recordPuzzleResult(
    mode: modeTitle,
    date: date,
    score: score,
    rarity: rarityScore,
    timeSeconds: timeSeconds,
  );
  if (coinsEarned > 0) {
    ref.read(coinsProvider.notifier).add(coinsEarned, '$modeTitle completion reward');
  }

  showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) => _PuzzleResultSheetWidget(
      modeTitle: modeTitle,
      modeCode: modeCode,
      score: score,
      maxScore: maxScore,
      timeSeconds: timeSeconds,
      coinsEarned: coinsEarned,
      rarityScore: rarityScore,
      revealedAnswer: revealedAnswer,
      shareableText: shareableText,
      onPlayAgain: onPlayAgain,
      onHome: onHome,
    ),
  );
}

class _PuzzleResultSheetWidget extends StatefulWidget {
  final String modeTitle;
  final String modeCode;
  final int score;
  final int maxScore;
  final int timeSeconds;
  final int coinsEarned;
  final double? rarityScore;
  final String? revealedAnswer;
  final String shareableText;
  final VoidCallback onPlayAgain;
  final VoidCallback? onHome;

  const _PuzzleResultSheetWidget({
    required this.modeTitle,
    required this.modeCode,
    required this.score,
    required this.maxScore,
    required this.timeSeconds,
    required this.coinsEarned,
    this.rarityScore,
    this.revealedAnswer,
    required this.shareableText,
    required this.onPlayAgain,
    this.onHome,
  });

  @override
  State<_PuzzleResultSheetWidget> createState() => _PuzzleResultSheetWidgetState();
}

class _PuzzleResultSheetWidgetState extends State<_PuzzleResultSheetWidget> {
  bool _copied = false;

  void _copyShareable() {
    Clipboard.setData(ClipboardData(text: widget.shareableText));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppPalette.darkSurface : AppPalette.lightSurface;
    final ink = isDark ? AppPalette.darkInk : AppPalette.lightInk;
    final inkMuted = isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted;

    final minutes = widget.timeSeconds ~/ 60;
    final seconds = widget.timeSeconds % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final isPerfect = widget.score == widget.maxScore;
    final scorePercent = widget.maxScore > 0 ? widget.score / widget.maxScore : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppPalette.darkBorder : AppPalette.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Mode title + perfect badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.modeTitle,
                      style: AppTypography.heading(ink, fontSize: 22),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Session Complete',
                      style: AppTypography.bodySmall(inkMuted),
                    ),
                  ],
                ),
              ),
              if (isPerfect)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppPalette.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'PERFECT',
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.gold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),

          if (widget.revealedAnswer != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (widget.score > 0 ? AppPalette.green : AppPalette.red).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (widget.score > 0 ? AppPalette.green : AppPalette.red).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.score > 0 ? Icons.check_circle_rounded : Icons.person_rounded,
                    color: widget.score > 0 ? AppPalette.green : AppPalette.red,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.score > 0 ? 'IDENTIFIED PLAYER' : 'MYSTERY PLAYER WAS',
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: widget.score > 0 ? AppPalette.green : AppPalette.red,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.revealedAnswer!,
                          style: AppTypography.titleMedium(ink),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Score ring + stats row
          Row(
            children: [
              // Circular score indicator
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: scorePercent,
                        strokeWidth: 4,
                        backgroundColor: isDark ? AppPalette.darkBorder : AppPalette.lightBorder,
                        valueColor: AlwaysStoppedAnimation(
                          scorePercent >= 1.0 ? AppPalette.gold : AppPalette.green,
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.score}',
                          style: AppTypography.statNumber(ink, fontSize: 22, weight: FontWeight.w800),
                        ),
                        Text(
                          '/ ${widget.maxScore}',
                          style: AppTypography.caption(inkMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Stats column
              Expanded(
                child: Column(
                  children: [
                    _statRow('Time', timeStr, ink, inkMuted),
                    const SizedBox(height: 8),
                    if (widget.rarityScore != null)
                      _statRow('Rarity', '${widget.rarityScore!.toStringAsFixed(0)}%', AppPalette.blue, inkMuted),
                    if (widget.rarityScore != null) const SizedBox(height: 8),
                    _statRow('Earned', '+${widget.coinsEarned} coins', AppPalette.gold, inkMuted),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Share row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.shareableText.split('\n').take(3).join('\n'),
                    style: AppTypography.bodySmall(ink),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _copyShareable,
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.share_rounded,
                    size: 20,
                    color: _copied ? AppPalette.green : inkMuted,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? AppPalette.darkHover : AppPalette.lightHover,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (widget.onHome != null) {
                      widget.onHome!();
                    } else {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                  child: const Text('Back to Hub'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onPlayAgain();
                  },
                  child: const Text('Play Again'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, Color valueColor, Color labelColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodySmall(labelColor)),
        Text(value, style: AppTypography.statNumber(valueColor, fontSize: 14, weight: FontWeight.w700)),
      ],
    );
  }
}
