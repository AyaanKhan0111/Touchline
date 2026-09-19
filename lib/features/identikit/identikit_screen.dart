import 'dart:async';
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
import '../shared/widgets/player_search_field.dart';
import '../shared/widgets/puzzle_result_sheet.dart';
import '../shared/widgets/stat_badge.dart';

enum IdentikitDifficulty { easy, medium, hard }

class IdentikitScreen extends ConsumerStatefulWidget {
  final IdentikitDifficulty difficulty;
  const IdentikitScreen({super.key, this.difficulty = IdentikitDifficulty.medium});

  @override
  ConsumerState<IdentikitScreen> createState() => _IdentikitScreenState();
}

class _IdentikitScreenState extends ConsumerState<IdentikitScreen> {
  Player? _targetPlayer;
  bool _isLoading = true;

  final List<Player> _guesses = [];
  int _revealedClues = 1; // Start with clue 1 revealed
  int _freeSkipsUsed = 0; // Max 2 free skips before rewarded ad
  bool _isGameOver = false;
  bool _won = false;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _pickTargetPlayer();
  }

  Future<void> _pickTargetPlayer() async {
    setState(() => _isLoading = true);
    final db = await DatabaseService.instance.database;

    int minOvr = 84;
    if (widget.difficulty == IdentikitDifficulty.easy) {
      minOvr = 87;
    } else if (widget.difficulty == IdentikitDifficulty.hard) {
      minOvr = 78;
    }

    final results = await db.rawQuery('''
      SELECT * FROM players
      WHERE overall >= ? AND nationality IS NOT NULL AND preferred_foot IS NOT NULL AND age IS NOT NULL
      GROUP BY player_name
      ORDER BY RANDOM()
      LIMIT 1
    ''', [minOvr]);

    if (results.isNotEmpty) {
      setState(() {
        _targetPlayer = Player.fromMap(results.first);
        _isLoading = false;
      });
    }
  }

  void _submitGuess(Player guess) {
    if (_isGameOver || _targetPlayer == null) return;

    setState(() {
      _guesses.add(guess);
    });

    final isCorrect = guess.playerId == _targetPlayer!.playerId ||
        (guess.name.toLowerCase() == _targetPlayer!.name.toLowerCase());

    if (isCorrect) {
      SoundService.instance.playGoal();
      _finishGame(won: true);
    } else {
      SoundService.instance.playWrong();
      if (_revealedClues < 6) {
        setState(() => _revealedClues++);
      }
      if (_guesses.length >= 6) {
        _finishGame(won: false);
      }
    }
  }

  void _skipClue() {
    if (_isGameOver || _revealedClues >= 6) return;
    SoundService.instance.playClick();
    if (_freeSkipsUsed < 2) {
      setState(() {
        _freeSkipsUsed++;
        _revealedClues++;
      });
      final remaining = 2 - _freeSkipsUsed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            remaining > 0
                ? 'Clue revealed ($remaining free skip remaining)'
                : 'Clue revealed (Free skips used up — next requires a sponsored ad)',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      _showRewardedAdDialog();
    }
  }

  Future<void> _showRewardedAdDialog() async {
    if (_isGameOver || _revealedClues >= 6) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _MockRewardedAdDialog(
        targetClueNumber: _revealedClues + 1,
        onRewardEarned: () {
          if (mounted) {
            setState(() {
              _revealedClues++;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Clue $_revealedClues unlocked via sponsored ad!'),
                backgroundColor: AppPalette.positive,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  void _finishGame({required bool won}) {
    setState(() {
      _isGameOver = true;
      _won = won;
    });
    final guessesUsed = _guesses.length;
    final coinsEarned = won ? max(1, 10 - (2 * (guessesUsed - 1))) : 0;

    final buffer = StringBuffer();
    buffer.writeln('Touchline Identikit: ${won ? '$guessesUsed/6' : 'X/6'}');
    for (final g in _guesses) {
      final sameNat = g.nationality == _targetPlayer!.nationality ? '🟩' : '⬜';
      final samePos = g.primaryPosition == _targetPlayer!.primaryPosition ? '🟩' : '⬜';
      final ratCmp = g.overall == _targetPlayer!.overall ? '🟩' : (g.overall > _targetPlayer!.overall ? '⬇️' : '⬆️');
      buffer.writeln('$sameNat$samePos$ratCmp');
    }

    showPuzzleResultSheet(
      context: context,
      ref: ref,
      modeTitle: 'Guess the Player',
      modeCode: 'IDENTIKIT',
      score: won ? (7 - guessesUsed) : 0,
      maxScore: 6,
      timeSeconds: _secondsElapsed,
      coinsEarned: coinsEarned,
      revealedAnswer: '${_targetPlayer!.name} (${_targetPlayer!.teamName})',
      shareableText: buffer.toString(),
      onPlayAgain: () {
        setState(() {
          _guesses.clear();
          _revealedClues = 1;
          _freeSkipsUsed = 0;
          _isGameOver = false;
          _won = false;
          _secondsElapsed = 0;
        });
        _pickTargetPlayer();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppPalette.darkInk : AppPalette.lightInk;
    final inkMuted = isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted;
    final border = isDark ? AppPalette.darkBorder : AppPalette.lightBorder;

    if (_isLoading || _targetPlayer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Guess the Player')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Guess the Player', style: AppTypography.heading(ink, fontSize: 22)),
            Text('6 clues to identify him', style: AppTypography.bodySmall(inkMuted)),
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
                const Icon(Icons.help_outline_rounded, size: 14, color: AppPalette.gold),
                const SizedBox(width: 6),
                Text(
                  '${6 - _guesses.length} tries left',
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
            // Drip Clues Card (6 Clues)
            AlmanacCard(
              sectionTitle: 'CLUES REVEALED ($_revealedClues / 6)',
              trailing: _revealedClues < 6 && !_isGameOver
                  ? InkWell(
                      onTap: _skipClue,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _freeSkipsUsed < 2
                              ? AppPalette.gold.withValues(alpha: 0.12)
                              : AppPalette.amber.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _freeSkipsUsed < 2
                                ? AppPalette.gold.withValues(alpha: 0.4)
                                : AppPalette.amber,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _freeSkipsUsed < 2 ? Icons.skip_next_rounded : Icons.play_circle_fill_rounded,
                              size: 13,
                              color: _freeSkipsUsed < 2 ? AppPalette.gold : AppPalette.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _freeSkipsUsed < 2
                                  ? 'Next clue (${2 - _freeSkipsUsed} free)'
                                  : 'Watch Ad for Clue',
                              style: TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _freeSkipsUsed < 2 ? AppPalette.gold : AppPalette.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : null,
              child: Column(
                children: [
                  _clueRow(1, 'Position & Foot', '${_targetPlayer!.primaryPosition} • ${_targetPlayer!.preferredFoot ?? 'Right'} footed', _revealedClues >= 1, ink, inkMuted),
                  Divider(color: border, height: 1),
                  _clueRow(2, 'Nationality', _targetPlayer!.nationality ?? 'Unknown', _revealedClues >= 2, ink, inkMuted),
                  Divider(color: border, height: 1),
                  _clueRow(3, 'League Context', _targetPlayer!.mode, _revealedClues >= 3, ink, inkMuted),
                  Divider(color: border, height: 1),
                  _clueRow(4, 'Age Band', _getAgeBand(_targetPlayer!.age), _revealedClues >= 4, ink, inkMuted),
                  Divider(color: border, height: 1),
                  _clueRow(5, 'Career Milestone', _getMilestoneClue(_targetPlayer!), _revealedClues >= 5, ink, inkMuted),
                  Divider(color: border, height: 1),
                  _clueRow(6, 'Club / Squad', _targetPlayer!.teamName, _revealedClues >= 6, ink, inkMuted),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Guess Input Field
            if (!_isGameOver) ...[
              PlayerSearchField(
                hintText: 'Enter your guess for the mystery player...',
                onPlayerSelected: _submitGuess,
              ),
              const SizedBox(height: 18),
            ],

            // Wordle-Style Deduction Feedback
            if (_guesses.isNotEmpty) ...[
              Text(
                'PREVIOUS GUESSES',
                style: AppTypography.sectionHeader(inkMuted),
              ),
              const SizedBox(height: 8),
              ..._guesses.reversed.map((guess) => _buildGuessCard(guess, _targetPlayer!, ink, inkMuted, border, isDark)),
            ],

            if (_isGameOver) ...[
              const SizedBox(height: 18),
              AlmanacCard(
                borderColor: _won ? AppPalette.positive : AppPalette.negative,
                child: Column(
                  children: [
                    Row(
                      children: [
                        PlayerAvatar(
                          name: _targetPlayer!.name,
                          size: 48,
                          position: _targetPlayer!.primaryPosition,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _won ? 'PLAYER IDENTIFIED!' : 'MYSTERY PLAYER WAS:',
                                style: AppTypography.sectionHeader(
                                  _won ? AppPalette.positive : AppPalette.negative,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _targetPlayer!.name,
                                style: AppTypography.titleLarge(ink),
                              ),
                              Text(
                                '${_targetPlayer!.teamName} • ${_targetPlayer!.primaryPosition} • ${_targetPlayer!.nationality ?? ''}',
                                style: AppTypography.bodySmall(inkMuted),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _won ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: _won ? AppPalette.positive : AppPalette.negative,
                          size: 32,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(color: border, height: 1),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _guesses.clear();
                            _revealedClues = 1;
                            _freeSkipsUsed = 0;
                            _isGameOver = false;
                            _won = false;
                            _secondsElapsed = 0;
                          });
                          _pickTargetPlayer();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('PLAY NEXT MYSTERY PLAYER'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _clueRow(int num, String label, String value, bool isRevealed, Color ink, Color inkMuted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isRevealed ? AppPalette.darkAccent.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isRevealed ? AppPalette.darkAccent : inkMuted.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              '$num',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isRevealed ? AppPalette.darkAccent : inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: AppTypography.bodySmall(inkMuted)),
          const Spacer(),
          Text(
            isRevealed ? value : '••••••••••••',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isRevealed ? ink : inkMuted.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuessCard(Player guess, Player target, Color ink, Color inkMuted, Color border, bool isDark) {
    final sameNat = guess.nationality == target.nationality;
    final samePos = guess.primaryPosition == target.primaryPosition;
    final sameClub = guess.teamName == target.teamName;

    // Age comparison
    String ageArrow = '=';
    if (guess.age != null && target.age != null) {
      final ageDiff = guess.age! - target.age!;
      if (ageDiff > 0) {
        ageArrow = '↓ YOUNGER';
      } else if (ageDiff < 0) {
        ageArrow = '↑ OLDER';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlayerAvatar(name: guess.name, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  guess.name,
                  style: AppTypography.bodyMedium(ink).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              PositionBadge(position: guess.primaryPosition),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: border, height: 1),
          const SizedBox(height: 8),
          // Wordle feedback pills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _feedbackPill('NATION', guess.nationality ?? '?', sameNat),
              _feedbackPill('POSITION', guess.primaryPosition, samePos),
              _feedbackPill('CLUB', guess.teamName, sameClub),
              _statComparisonPill('AGE', ageArrow, ageArrow == '=' ? AppPalette.positive : AppPalette.warn),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feedbackPill(String label, String val, bool match) {
    final col = match ? AppPalette.positive : AppPalette.negative;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: col.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label: $val ${match ? '✓' : '✗'}',
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: col,
        ),
      ),
    );
  }

  Widget _statComparisonPill(String label, String arrow, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label: $arrow',
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  static String _getAgeBand(double? age) {
    if (age == null) return 'Unknown';
    if (age < 21) return 'Under 21';
    if (age <= 25) return '21 – 25 years';
    if (age <= 29) return '26 – 29 years';
    if (age <= 34) return '30 – 34 years';
    return '35+ years (Veteran)';
  }

  static String _getMilestoneClue(Player p) {
    if (p.careerGoals != null && p.careerGoals! >= 20) {
      return '${p.careerGoals}+ career senior goals';
    } else if (p.careerAppearances != null && p.careerAppearances! >= 50) {
      return '${p.careerAppearances}+ senior matches';
    } else if (p.heightCm != null) {
      return '${p.heightCm} cm tall';
    }
    return '${p.primaryPosition} role';
  }
}

/// Simulated Rewarded Ad Dialog for unlocking clues after free skips are exhausted.
class _MockRewardedAdDialog extends StatefulWidget {
  final int targetClueNumber;
  final VoidCallback onRewardEarned;

  const _MockRewardedAdDialog({
    required this.targetClueNumber,
    required this.onRewardEarned,
  });

  @override
  State<_MockRewardedAdDialog> createState() => _MockRewardedAdDialogState();
}

class _MockRewardedAdDialogState extends State<_MockRewardedAdDialog> {
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
    final ink = isDark ? AppPalette.darkInk : AppPalette.lightInk;
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
            const SizedBox(height: 14),
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E3C72).withValues(alpha: 0.8),
                    const Color(0xFF2A5298).withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.movie_creation_rounded, size: 36, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      'Touchline Ad Network',
                      style: AppTypography.bodyMedium(Colors.white).copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _canClaim ? 'Reward Ready!' : 'Sponsored message... $_countdown s',
                      style: AppTypography.caption(Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unlock Clue #${widget.targetClueNumber}',
              style: AppTypography.titleMedium(ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Watch this short partner sponsor to reveal the next mystery player clue.',
              style: AppTypography.bodySmall(inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _canClaim
                  ? () {
                      Navigator.pop(context);
                      widget.onRewardEarned();
                    }
                  : null,
              icon: Icon(_canClaim ? Icons.check_circle_rounded : Icons.timer_outlined, size: 18),
              label: Text(_canClaim ? 'CLAIM CLUE REWARD' : 'WATCHING ($_countdown s)'),
            ),
          ],
        ),
      ),
    );
  }
}


