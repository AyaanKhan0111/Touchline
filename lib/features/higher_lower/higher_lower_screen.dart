import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/db_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/player.dart';
import '../shared/widgets/almanac_card.dart';
import '../shared/widgets/player_avatar.dart';
import '../shared/widgets/puzzle_result_sheet.dart';
import '../shared/widgets/stat_badge.dart';

enum StatCategory {
  careerGoals('Career Goals', 'goals scored throughout senior career'),
  careerAppearances('Career Appearances', 'total match appearances on record'),
  height('Height (cm)', 'official recorded height in centimeters'),
  age('Age', 'age during squad season'),
  marketValue('Market Value (£M)', 'estimated peak transfer valuation');

  final String title;
  final String description;
  const StatCategory(this.title, this.description);
}

class HigherLowerScreen extends ConsumerStatefulWidget {
  const HigherLowerScreen({super.key});

  @override
  ConsumerState<HigherLowerScreen> createState() => _HigherLowerScreenState();
}

class _HigherLowerScreenState extends ConsumerState<HigherLowerScreen> {
  Player? _leftPlayer;
  Player? _rightPlayer;
  StatCategory _currentCategory = StatCategory.careerGoals;
  bool _isLoading = true;

  int _currentStreak = 0;
  int _personalBest = 0;
  bool _revealed = false;
  bool? _lastAnswerCorrect;

  @override
  void initState() {
    super.initState();
    _loadNextPair();
  }

  Future<void> _loadNextPair({bool isInitial = true}) async {
    setState(() {
      _isLoading = true;
      _revealed = false;
      _lastAnswerCorrect = null;
    });

    final db = await DatabaseService.instance.database;
    final rng = Random();

    // Select category (cycling through categories with good data)
    final categories = [
      StatCategory.careerGoals,
      StatCategory.careerAppearances,
      StatCategory.height,
      StatCategory.age,
    ];
    final category = categories[rng.nextInt(categories.length)];

    String condition = 'overall >= 75';
    if (category == StatCategory.careerGoals) {
      condition = 'career_goals IS NOT NULL AND career_goals >= 5';
    } else if (category == StatCategory.careerAppearances) {
      condition = 'career_appearances IS NOT NULL AND career_appearances >= 30';
    } else if (category == StatCategory.height) {
      condition = 'height_cm IS NOT NULL';
    } else if (category == StatCategory.age) {
      condition = 'age IS NOT NULL';
    }

    final p1 = isInitial || _rightPlayer == null
        ? null
        : _rightPlayer!;

    final excludeClause = p1 != null ? "AND player_name != '${p1.name.replaceAll("'", "''")}'" : '';
    final limit = p1 == null ? 2 : 1;

    final results = await db.rawQuery('''
      SELECT * FROM players
      WHERE $condition $excludeClause
      GROUP BY player_name
      ORDER BY RANDOM()
      LIMIT $limit
    ''');

    if ((p1 == null && results.length >= 2) || (p1 != null && results.isNotEmpty)) {
      final left = p1 ?? Player.fromMap(results[0]);
      final right = Player.fromMap(results[p1 == null ? 1 : 0]);

      setState(() {
        _leftPlayer = left;
        _rightPlayer = right;
        _currentCategory = category;
        _isLoading = false;
      });
    }
  }

  double _getStatValue(Player p, StatCategory cat) {
    switch (cat) {
      case StatCategory.careerGoals:
        return p.careerGoals ?? 0.0;
      case StatCategory.careerAppearances:
        return p.careerAppearances ?? 0.0;
      case StatCategory.height:
        return p.heightCm ?? 180.0;
      case StatCategory.age:
        return p.age ?? 25.0;
      case StatCategory.marketValue:
        return p.marketValueMillions ?? 10.0;
    }
  }

  String _formatStat(double val, StatCategory cat) {
    if (cat == StatCategory.height) {
      return '${val.toInt()} cm';
    } else if (cat == StatCategory.marketValue) {
      return '£${val.toStringAsFixed(1)}M';
    } else if (cat == StatCategory.age) {
      return '${val.toInt()} yrs';
    }
    return val.toInt().toString();
  }

  void _makeGuess({required bool pickedHigher}) {
    if (_revealed || _leftPlayer == null || _rightPlayer == null) return;

    final valLeft = _getStatValue(_leftPlayer!, _currentCategory);
    final valRight = _getStatValue(_rightPlayer!, _currentCategory);

    final isCorrect = pickedHigher
        ? (valRight >= valLeft)
        : (valRight <= valLeft);

    setState(() {
      _revealed = true;
      _lastAnswerCorrect = isCorrect;
    });

    if (isCorrect) {
      SoundService.instance.playCorrect();
      setState(() {
        _currentStreak++;
        if (_currentStreak > _personalBest) {
          _personalBest = _currentStreak;
        }
      });
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) _loadNextPair(isInitial: false);
      });
    } else {
      SoundService.instance.playWrong();
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) _finishGame();
      });
    }
  }

  void _finishGame() {
    final coins = _currentStreak ~/ 3;
    final buffer = StringBuffer();
    buffer.writeln('Touchline Over/Under: $_currentStreak streak!');
    for (int i = 0; i < min(_currentStreak, 8); i++) {
      buffer.write('🟩');
    }
    buffer.write('🟥');

    showPuzzleResultSheet(
      context: context,
      ref: ref,
      modeTitle: 'Higher or Lower',
      modeCode: 'HIGHER_LOWER',
      score: _currentStreak,
      maxScore: max(_personalBest, _currentStreak),
      timeSeconds: _currentStreak * 6,
      coinsEarned: coins,
      shareableText: buffer.toString(),
      onPlayAgain: () {
        setState(() {
          _currentStreak = 0;
          _revealed = false;
        });
        _loadNextPair(isInitial: true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppPalette.darkInk : AppPalette.lightInk;
    final inkMuted = isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted;
    final border = isDark ? AppPalette.darkBorder : AppPalette.lightBorder;

    if (_isLoading || _leftPlayer == null || _rightPlayer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Higher or Lower')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final leftVal = _getStatValue(_leftPlayer!, _currentCategory);
    final rightVal = _getStatValue(_rightPlayer!, _currentCategory);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Higher or Lower', style: AppTypography.heading(ink, fontSize: 22)),
            Text(_currentCategory.title, style: AppTypography.bodySmall(inkMuted)),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppPalette.darkBorder : AppPalette.lightBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, size: 14, color: AppPalette.gold),
                const SizedBox(width: 6),
                Text(
                  'Streak: $_currentStreak',
                  style: AppTypography.statNumber(ink, fontSize: 12, weight: FontWeight.w600),
                ),
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
            // Category Banner
            AlmanacCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('COMPARISON STAT', style: AppTypography.sectionHeader(AppPalette.darkAccent)),
                      Text(_currentCategory.title, style: AppTypography.titleMedium(ink)),
                    ],
                  ),
                  Text('PB: $_personalBest', style: AppTypography.caption(inkMuted)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Left Player (Known Stat)
            AlmanacCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      PlayerAvatar(name: _leftPlayer!.name, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_leftPlayer!.name, style: AppTypography.titleMedium(ink)),
                            Text('${_leftPlayer!.teamName} • ${_leftPlayer!.season}', style: AppTypography.bodySmall(inkMuted)),
                          ],
                        ),
                      ),
                      PositionBadge(position: _leftPlayer!.primaryPosition),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: border, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('HAS RECORDED', style: AppTypography.sectionHeader(inkMuted)),
                      Text(
                        _formatStat(leftVal, _currentCategory),
                        style: AppTypography.statNumber(AppPalette.darkAccent, fontSize: 24, weight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // VS Divider
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Text('VS', style: AppTypography.caption(inkMuted)),
              ),
            ),

            const SizedBox(height: 12),

            // Right Player (Guess Higher or Lower)
            AlmanacCard(
              borderColor: _revealed
                  ? (_lastAnswerCorrect == true ? AppPalette.positive : AppPalette.negative)
                  : null,
              child: Column(
                children: [
                  Row(
                    children: [
                      PlayerAvatar(name: _rightPlayer!.name, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_rightPlayer!.name, style: AppTypography.titleMedium(ink)),
                            Text('${_rightPlayer!.teamName} • ${_rightPlayer!.season}', style: AppTypography.bodySmall(inkMuted)),
                          ],
                        ),
                      ),
                      PositionBadge(position: _rightPlayer!.primaryPosition),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: border, height: 1),
                  const SizedBox(height: 14),
                  if (_revealed) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ACTUAL RECORD', style: AppTypography.sectionHeader(inkMuted)),
                        Text(
                          _formatStat(rightVal, _currentCategory),
                          style: AppTypography.statNumber(
                            _lastAnswerCorrect == true ? AppPalette.positive : AppPalette.negative,
                            fontSize: 24,
                            weight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _makeGuess(pickedHigher: true),
                            icon: const Icon(Icons.arrow_upward, size: 18),
                            label: const Text('HIGHER'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.positive,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _makeGuess(pickedHigher: false),
                            icon: const Icon(Icons.arrow_downward, size: 18),
                            label: const Text('LOWER'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.negative,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
