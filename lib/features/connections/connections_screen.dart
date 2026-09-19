import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../shared/widgets/almanac_card.dart';
import '../shared/widgets/puzzle_result_sheet.dart';

class ConnectionGroup {
  final String title;
  final String description;
  final List<String> players;
  final Color difficultyColor;
  final int tier; // 1 to 4

  const ConnectionGroup({
    required this.title,
    required this.description,
    required this.players,
    required this.difficultyColor,
    required this.tier,
  });
}

class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen> {
  // 4 Groups of 4 (V2 Palette: Sand -> Sage -> Moss -> Deep Green)
  static final List<ConnectionGroup> _groups = [
    const ConnectionGroup(
      title: 'BALLON D\'OR WINNERS',
      description: 'Cristiano Ronaldo, Karim Benzema, Ronaldinho, George Weah',
      players: ['Cristiano Ronaldo', 'Karim Benzema', 'Ronaldinho', 'George Weah'],
      difficultyColor: AppPalette.tonalStep1, // Sand
      tier: 1,
    ),
    const ConnectionGroup(
      title: 'PREMIER LEAGUE 100+ GOAL CLUB',
      description: 'Harry Kane, Wayne Rooney, Alan Shearer, Sergio Agüero',
      players: ['Harry Kane', 'Wayne Rooney', 'Alan Shearer', 'Sergio Agüero'],
      difficultyColor: AppPalette.tonalStep2, // Sage
      tier: 2,
    ),
    const ConnectionGroup(
      title: 'WORLD CUP FINAL SCORERS',
      description: 'Luka Modrić, Zinédine Zidane, Kaká, Pavel Nedvěd',
      players: ['Luka Modrić', 'Zinédine Zidane', 'Kaká', 'Pavel Nedvěd'],
      difficultyColor: AppPalette.tonalStep3, // Moss
      tier: 3,
    ),
    const ConnectionGroup(
      title: 'LEFT-FOOTED GOAL MACHINES',
      description: 'Lionel Messi, Gareth Bale, Rivaldo, Robin van Persie',
      players: ['Lionel Messi', 'Gareth Bale', 'Rivaldo', 'Robin van Persie'],
      difficultyColor: AppPalette.tonalStep4, // Deep green
      tier: 4,
    ),
  ];

  late List<String> _shuffledGrid;
  final List<ConnectionGroup> _solvedGroups = [];
  final Set<String> _selectedPlayers = {};
  final Set<int> _revealedCategoryHints = {};
  int _mistakesRemaining = 4;
  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();
    _initGrid();
  }

  void _initGrid() {
    final all = <String>[];
    for (final g in _groups) {
      all.addAll(g.players);
    }
    all.shuffle();
    _shuffledGrid = all;
    _revealedCategoryHints.clear();
  }

  void _onPlayerTapped(String name) {
    if (_isGameOver) return;
    setState(() {
      if (_selectedPlayers.contains(name)) {
        _selectedPlayers.remove(name);
      } else {
        if (_selectedPlayers.length < 4) {
          _selectedPlayers.add(name);
        }
      }
    });
  }

  int get _liveSelectionConnectionCount {
    if (_selectedPlayers.length < 2) return 0;
    int maxMatches = 0;
    for (final g in _groups) {
      if (_solvedGroups.contains(g)) continue;
      final m = _selectedPlayers.where((p) => g.players.contains(p)).length;
      if (m > maxMatches) maxMatches = m;
    }
    return maxMatches;
  }

  void _submitGuess() {
    if (_selectedPlayers.length != 4 || _isGameOver) return;

    // Check if matches any unsolved group
    ConnectionGroup? matched;
    for (final group in _groups) {
      if (_solvedGroups.contains(group)) continue;
      if (_selectedPlayers.every((p) => group.players.contains(p))) {
        matched = group;
        break;
      }
    }

    if (matched != null) {
      setState(() {
        _solvedGroups.add(matched!);
        _shuffledGrid.removeWhere((p) => matched!.players.contains(p));
        _selectedPlayers.clear();
      });

      if (_solvedGroups.length == 4) {
        _finishGame(won: true);
      }
    } else {
      // Check progressive match count across unsolved groups (Issue #9)
      int matchCount = 0;
      for (final group in _groups) {
        if (_solvedGroups.contains(group)) continue;
        final count = _selectedPlayers.where((p) => group.players.contains(p)).length;
        if (count > matchCount) {
          matchCount = count;
        }
      }

      setState(() {
        _mistakesRemaining--;
      });

      String feedbackMsg = 'Incorrect group. Try again.';
      if (matchCount == 3) {
        feedbackMsg = 'One away! 3 of these belong together.';
      } else if (matchCount == 2) {
        feedbackMsg = 'Two from the same group! 2 of these belong together.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(feedbackMsg),
          backgroundColor: AppPalette.negative,
          duration: const Duration(seconds: 2),
        ),
      );

      if (_mistakesRemaining <= 0) {
        _finishGame(won: false);
      }
    }
  }

  void _showCategoryHintDialog() {
    // Find next unsolved group whose tier is not yet revealed
    ConnectionGroup? targetGroup;
    for (final g in _groups) {
      if (!_solvedGroups.contains(g) && !_revealedCategoryHints.contains(g.tier)) {
        targetGroup = g;
        break;
      }
    }

    if (targetGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All category hints have already been unlocked!'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _ConnectionsRewardedAdDialog(
        targetGroupTitle: targetGroup!.title,
        onRewardEarned: () {
          setState(() {
            _revealedCategoryHints.add(targetGroup!.tier);
          });
          final groupTitle = targetGroup!.title;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('💡 Category Hint Unlocked: "$groupTitle"'),
              backgroundColor: AppPalette.green,
              duration: const Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }

  void _finishGame({required bool won}) {
    setState(() => _isGameOver = true);
    final flawless = _mistakesRemaining == 4;
    final coins = won ? (8 + (flawless ? 4 : 0)) : 0;

    final buffer = StringBuffer();
    buffer.writeln('Touchline Four by Four: ${won ? "SOLVED" : "FAILED"}');
    for (final g in _solvedGroups) {
      buffer.writeln('🟩 🟩 🟩 🟩 (${g.title})');
    }

    showPuzzleResultSheet(
      context: context,
      ref: ref,
      modeTitle: 'Connections',
      modeCode: 'CONNECTIONS',
      score: _solvedGroups.length,
      maxScore: 4,
      timeSeconds: 120,
      coinsEarned: coins,
      shareableText: buffer.toString(),
      onPlayAgain: () {
        setState(() {
          _solvedGroups.clear();
          _selectedPlayers.clear();
          _mistakesRemaining = 4;
          _isGameOver = false;
        });
        _initGrid();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppPalette.darkInk : AppPalette.lightInk;
    final inkMuted = isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted;
    final border = isDark ? AppPalette.darkBorder : AppPalette.lightBorder;
    final liveMatches = _liveSelectionConnectionCount;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connections', style: AppTypography.heading(ink, fontSize: 22)),
            Text('Find 4 groups of 4', style: AppTypography.bodySmall(inkMuted)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Mistakes: ', style: AppTypography.caption(inkMuted)),
                ...List.generate(4, (i) {
                  final active = i < _mistakesRemaining;
                  return Container(
                    margin: const EdgeInsets.only(left: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? AppPalette.red : (isDark ? AppPalette.darkBorder : AppPalette.lightBorder),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('CREATE FOUR GROUPS OF FOUR PLAYERS', style: AppTypography.sectionHeader(inkMuted)),
            const SizedBox(height: 12),

            // Solved Group Banners (Tonal Colors)
            ..._solvedGroups.map((group) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: group.difficultyColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      group.title,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      group.description,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }),

            // Revealed Ad-Gated Category Hints Banners
            if (_revealedCategoryHints.isNotEmpty) ...[
              for (final tier in _revealedCategoryHints) ...[
                Builder(builder: (context) {
                  final group = _groups.firstWhere((g) => g.tier == tier);
                  if (_solvedGroups.contains(group)) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_rounded, size: 16, color: Color(0xFFFFD700)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'CATEGORY HINT: ${group.title}',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],

            // 4x4 Remaining Tiles Grid
            if (_shuffledGrid.isNotEmpty) ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _shuffledGrid.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemBuilder: (context, index) {
                  final name = _shuffledGrid[index];
                  final isSelected = _selectedPlayers.contains(name);

                  return InkWell(
                    onTap: () => _onPlayerTapped(name),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? const Color(0xFF33382F) : const Color(0xFFD6D4CB))
                            : (isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppPalette.darkAccent : border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(6),
                      alignment: Alignment.center,
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: ink,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Progressive Live Selection Feedback Chip (Issue #9)
              if (liveMatches >= 2 && _selectedPlayers.length <= 3) ...[
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppPalette.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppPalette.green.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flash_on_rounded, size: 14, color: AppPalette.green),
                        const SizedBox(width: 4),
                        Text(
                          '$liveMatches selected share a connection!',
                          style: const TextStyle(
                            color: AppPalette.green,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Action Buttons Bar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _shuffledGrid.shuffle());
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('SHUFFLE', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _selectedPlayers.clear());
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('DESELECT', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Ad-Gated Category Hint Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showCategoryHintDialog,
                      icon: const Icon(Icons.lightbulb_outline, size: 13, color: AppPalette.gold),
                      label: const Text('HINT', style: TextStyle(fontSize: 11, color: AppPalette.gold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: BorderSide(color: AppPalette.gold.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _selectedPlayers.length == 4 ? _submitGuess : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('SUBMIT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            AlmanacCard(
              sectionTitle: 'CONNECTIONS RULES & TONAL DIFFICULTY',
              child: Text(
                '• 16 players in 4 mystery categories of four.\n'
                '• Beware of intentional traps: players that plausibly fit multiple categories.\n'
                '• Category difficulty is graded in tonal pitch steps: Sand (Easy) → Sage → Moss → Deep Green (Brutal).\n'
                '• Watch sponsored messages to unlock category clues!',
                style: AppTypography.caption(inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simulated Rewarded Ad Dialog for unlocking Connections category hints
class _ConnectionsRewardedAdDialog extends StatefulWidget {
  final String targetGroupTitle;
  final VoidCallback onRewardEarned;

  const _ConnectionsRewardedAdDialog({
    required this.targetGroupTitle,
    required this.onRewardEarned,
  });

  @override
  State<_ConnectionsRewardedAdDialog> createState() => _ConnectionsRewardedAdDialogState();
}

class _ConnectionsRewardedAdDialogState extends State<_ConnectionsRewardedAdDialog> {
  int _countdown = 3;
  Timer? _timer;
  bool _canClaim = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        _timer?.cancel();
        setState(() {
          _countdown = 0;
          _canClaim = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkMuted = isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted;
    final bg = isDark ? AppPalette.darkSurface : AppPalette.lightSurface;
    final border = isDark ? AppPalette.darkBorder : AppPalette.lightBorder;

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppPalette.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppPalette.amber.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'SPONSORED REWARD',
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.amber,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: inkMuted,
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B2433) : const Color(0xFFEAEFF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lightbulb_rounded, size: 36, color: Color(0xFFFFD700)),
                    const SizedBox(height: 8),
                    Text(
                      'Touchline Ad Network',
                      style: AppTypography.bodySmall(inkMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _canClaim ? 'Category Hint Ready!' : 'Sponsored message... $_countdown s',
                      style: AppTypography.caption(AppPalette.gold).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _canClaim
                  ? () {
                      Navigator.pop(context);
                      widget.onRewardEarned();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                _canClaim ? 'UNLOCK CATEGORY HINT' : 'WAIT $_countdown SECONDS',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
