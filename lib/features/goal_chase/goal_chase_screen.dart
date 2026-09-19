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

class GoalChaseScreen extends ConsumerStatefulWidget {
  final int targetGoals;
  final int totalPicks;

  const GoalChaseScreen({
    super.key,
    this.targetGoals = 1000,
    this.totalPicks = 12,
  });

  @override
  ConsumerState<GoalChaseScreen> createState() => _GoalChaseScreenState();
}

class _GoalChaseScreenState extends ConsumerState<GoalChaseScreen> {
  int _currentTotal = 0;
  int _picksRemaining = 12;
  final List<Player> _chosenPlayers = [];
  List<Player>? _currentTrio;
  bool _isLoading = true;
  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();
    _picksRemaining = widget.totalPicks;
    _loadNextTrio();
  }

  Future<void> _loadNextTrio() async {
    setState(() => _isLoading = true);
    final db = await DatabaseService.instance.database;

    // Pick 3 random players with valid career goals data
    final results = await db.rawQuery('''
      SELECT * FROM players
      WHERE career_goals IS NOT NULL AND career_goals >= 5
      GROUP BY player_name
      ORDER BY RANDOM()
      LIMIT 3
    ''');

    if (results.length >= 3) {
      setState(() {
        _currentTrio = results.map((r) => Player.fromMap(r)).toList();
        _isLoading = false;
      });
    }
  }

  void _pickPlayer(Player player) {
    if (_isGameOver) return;
    SoundService.instance.playKick();

    final goals = (player.careerGoals ?? 0).toInt();
    setState(() {
      _currentTotal += goals;
      _picksRemaining--;
      _chosenPlayers.add(player);
    });

    if (_currentTotal >= widget.targetGoals) {
      _finishGame(won: true);
    } else if (_picksRemaining <= 0) {
      _finishGame(won: false);
    } else {
      _loadNextTrio();
    }
  }

  void _finishGame({required bool won}) {
    setState(() => _isGameOver = true);
    if (won) {
      SoundService.instance.playGoal();
    } else {
      SoundService.instance.playWrong();
    }
    final overshoot = max(0, _currentTotal - widget.targetGoals);
    final coins = won ? (5 + (overshoot ~/ 200)) : 0;

    final buffer = StringBuffer();
    buffer.writeln('Touchline Goal Chase: ${won ? "WON" : "LOST"}! ($_currentTotal / ${widget.targetGoals} goals)');
    for (final p in _chosenPlayers) {
      buffer.writeln('${p.name}: ${p.careerGoals?.toInt()} ⚽');
    }

    showPuzzleResultSheet(
      context: context,
      ref: ref,
      modeTitle: 'Goal Chase',
      modeCode: 'GOAL_CHASE',
      score: _currentTotal,
      maxScore: widget.targetGoals,
      timeSeconds: (widget.totalPicks - _picksRemaining) * 5,
      coinsEarned: coins,
      shareableText: buffer.toString(),
      onPlayAgain: () {
        setState(() {
          _currentTotal = 0;
          _picksRemaining = widget.totalPicks;
          _chosenPlayers.clear();
          _isGameOver = false;
        });
        _loadNextTrio();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppPalette.darkInk : AppPalette.lightInk;
    final inkMuted = isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted;
    final border = isDark ? AppPalette.darkBorder : AppPalette.lightBorder;

    final remainingNeeded = max(0, widget.targetGoals - _currentTotal);
    final requiredAvgPerPick = _picksRemaining > 0 ? (remainingNeeded / _picksRemaining).toStringAsFixed(1) : '0';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Goal Chase', style: AppTypography.heading(ink, fontSize: 22)),
            Text('Target: ${widget.targetGoals} goals', style: AppTypography.bodySmall(inkMuted)),
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
                const Icon(Icons.sports_soccer, size: 14, color: AppPalette.gold),
                const SizedBox(width: 6),
                Text(
                  '$_picksRemaining picks left',
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
            // Tension Dashboard Card
            AlmanacCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GOALS REACHED', style: AppTypography.sectionHeader(inkMuted)),
                          const SizedBox(height: 4),
                          Text(
                            '$_currentTotal / ${widget.targetGoals}',
                            style: AppTypography.statNumber(
                              _currentTotal >= widget.targetGoals ? AppPalette.positive : AppPalette.gold,
                              fontSize: 28,
                              weight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('REQUIRED AVG / PICK', style: AppTypography.sectionHeader(AppPalette.warn)),
                          const SizedBox(height: 4),
                          Text(
                            '$requiredAvgPerPick goals',
                            style: AppTypography.statNumber(AppPalette.warn, fontSize: 20, weight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (_currentTotal / widget.targetGoals).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: isDark ? const Color(0xFF2C2F2A) : const Color(0xFFE3E2DD),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _currentTotal >= widget.targetGoals ? AppPalette.positive : AppPalette.darkAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'ROULETTE: PICK ONE FACE-DOWN PLAYER',
              style: AppTypography.sectionHeader(inkMuted),
            ),
            const SizedBox(height: 8),

            // 3 Roulette Cards
            if (_isLoading || _currentTrio == null) ...[
              const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
            ] else ...[
              ...List.generate(3, (index) {
                final player = _currentTrio![index];
                return _buildRouletteCard(player, index + 1, border, ink, inkMuted, isDark);
              }),
            ],

            const SizedBox(height: 20),

            // Selection History Register
            if (_chosenPlayers.isNotEmpty) ...[
              Text('SELECTION HISTORY', style: AppTypography.sectionHeader(inkMuted)),
              const SizedBox(height: 8),
              ..._chosenPlayers.reversed.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    PlayerAvatar(name: p.name, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${p.name} (${p.teamName})',
                        style: AppTypography.bodySmall(ink),
                      ),
                    ),
                    Text(
                      '+${p.careerGoals?.toInt() ?? 0} ⚽',
                      style: AppTypography.statNumber(AppPalette.positive, fontSize: 13, weight: FontWeight.w700),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRouletteCard(
    Player player,
    int slotNumber,
    Color border,
    Color ink,
    Color inkMuted,
    bool isDark,
  ) {
    // Clue visible while card is face-down: e.g. "English Forward • 2010s"
    final decade = '${(player.season ~/ 10) * 10}s';
    final nat = player.nationality ?? 'International';
    final pos = player.primaryPosition;
    final hint = '$nat $pos • $decade';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _pickPlayer(player),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppPalette.darkAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppPalette.darkAccent.withValues(alpha: 0.4)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#$slotNumber',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.darkAccent,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MYSTERY SCORER #$slotNumber',
                      style: AppTypography.sectionHeader(inkMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    Text(
                      'Tap to reveal career goal haul',
                      style: AppTypography.caption(inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PositionBadge(position: player.primaryPosition),
            ],
          ),
        ),
      ),
    );
  }
}
