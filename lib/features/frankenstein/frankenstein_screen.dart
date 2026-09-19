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

enum FrankensteinAttribute {
  pace('PAC', 'Pace / Sprint Speed'),
  shooting('SHO', 'Shooting / Finishing'),
  passing('PAS', 'Passing / Vision'),
  dribbling('DRI', 'Dribbling / Ball Control'),
  defending('DEF', 'Defending / Tackling'),
  physicality('PHY', 'Physicality / Stamina & Strength');

  final String code;
  final String label;
  const FrankensteinAttribute(this.code, this.label);
}

class FrankensteinScreen extends ConsumerStatefulWidget {
  const FrankensteinScreen({super.key});

  @override
  ConsumerState<FrankensteinScreen> createState() => _FrankensteinScreenState();
}

class _FrankensteinScreenState extends ConsumerState<FrankensteinScreen> {
  final Map<FrankensteinAttribute, Map<String, dynamic>> _draftedStats = {};
  int _currentStepIndex = 0;
  List<Player> _currentCandidates = [];
  bool _isLoading = true;
  bool _isDraftFinished = false;

  final List<FrankensteinAttribute> _steps = FrankensteinAttribute.values;

  @override
  void initState() {
    super.initState();
    _loadCandidatesForStep();
  }

  Future<void> _loadCandidatesForStep() async {
    setState(() => _isLoading = true);
    final db = await DatabaseService.instance.database;

    // Pick 5 high-profile players for the blind draft round
    final results = await db.rawQuery('''
      SELECT * FROM players
      WHERE overall >= 80
      GROUP BY player_name
      ORDER BY RANDOM()
      LIMIT 5
    ''');

    setState(() {
      _currentCandidates = results.map((r) => Player.fromMap(r)).toList();
      _isLoading = false;
    });
  }

  void _selectPlayer(Player player) {
    SoundService.instance.playClick();
    final currentAttr = _steps[_currentStepIndex];
    final statVal = player.getAttribute(currentAttr.code);

    setState(() {
      _draftedStats[currentAttr] = {
        'value': statVal,
        'playerName': player.name,
        'playerPosition': player.primaryPosition,
        'playerClub': player.teamName,
        'playerNation': player.nationality,
      };
    });

    if (_currentStepIndex < _steps.length - 1) {
      setState(() => _currentStepIndex++);
      _loadCandidatesForStep();
    } else {
      _finishDraft();
    }
  }

  void _finishDraft() {
    SoundService.instance.playGoal();
    int total = 0;
    for (final attr in _steps) {
      total += (_draftedStats[attr]?['value'] as int? ?? 50);
    }
    final compositeOvr = (total / _steps.length).round();
    final coins = max(5, compositeOvr - 75);

    setState(() {
      _isDraftFinished = true;
    });

    final buffer = StringBuffer();
    buffer.writeln('Touchline Frankenstein XI: $compositeOvr OVR Hybrid!');
    for (final attr in _steps) {
      buffer.writeln('${attr.code}: ${_draftedStats[attr]?['value']} (${_draftedStats[attr]?['playerName']})');
    }

    showPuzzleResultSheet(
      context: context,
      ref: ref,
      modeTitle: 'Build-a-Player',
      modeCode: 'FRANKENSTEIN',
      score: compositeOvr,
      maxScore: 99,
      timeSeconds: 60,
      coinsEarned: coins,
      revealedAnswer: '$compositeOvr OVR Hybrid Archetype',
      shareableText: buffer.toString(),
      onPlayAgain: _resetDraft,
    );
  }

  void _resetDraft() {
    setState(() {
      _draftedStats.clear();
      _currentStepIndex = 0;
      _isDraftFinished = false;
    });
    _loadCandidatesForStep();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppPalette.darkInk : AppPalette.lightInk;
    final inkMuted = isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted;
    final border = isDark ? AppPalette.darkBorder : AppPalette.lightBorder;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Build-a-Player')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_isDraftFinished) {
      return _buildGrandRevealScreen(ink, inkMuted, border, isDark);
    }

    final currentAttr = _steps[_currentStepIndex];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Build-a-Player', style: AppTypography.heading(ink, fontSize: 22)),
            Text('Round ${_currentStepIndex + 1} of 6 • Blind Draft', style: AppTypography.bodySmall(inkMuted)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Target Attribute Card
            AlmanacCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('BLIND DRAFT TARGET', style: AppTypography.sectionHeader(AppPalette.gold)),
                      PositionBadge(position: currentAttr.code, isSmall: true),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(currentAttr.label, style: AppTypography.titleLarge(ink)),
                  const SizedBox(height: 6),
                  Text(
                    'Draft a player to harvest their ${currentAttr.code} attribute. You are drafting blind — player stats and ratings are hidden until the final reveal!',
                    style: AppTypography.bodySmall(inkMuted),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Blind Hybrid Profile Card Preview
            AlmanacCard(
              sectionTitle: 'HYBRID PROFILE (BLIND)',
              trailing: Text(
                '${_draftedStats.length} / 6 slots locked',
                style: AppTypography.caption(AppPalette.gold),
              ),
              child: Row(
                children: _steps.asMap().entries.map((entry) {
                  final index = entry.key;
                  final attr = entry.value;
                  final isDrafted = _draftedStats.containsKey(attr);
                  final isCurrent = index == _currentStepIndex;

                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isDrafted
                            ? AppPalette.gold.withValues(alpha: 0.15)
                            : (isCurrent ? AppPalette.blue.withValues(alpha: 0.12) : Colors.transparent),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDrafted
                              ? AppPalette.gold.withValues(alpha: 0.6)
                              : (isCurrent ? AppPalette.blue : border),
                          width: isCurrent ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            attr.code,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDrafted
                                  ? AppPalette.gold
                                  : (isCurrent ? AppPalette.blue : inkMuted),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            isDrafted
                                ? Icons.lock_rounded
                                : (isCurrent ? Icons.radio_button_checked_rounded : Icons.lock_outline_rounded),
                            size: 13,
                            color: isDrafted
                                ? AppPalette.gold
                                : (isCurrent ? AppPalette.blue : inkMuted.withValues(alpha: 0.4)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isDrafted ? '?' : '—',
                            style: AppTypography.statNumber(
                              isDrafted ? AppPalette.gold : inkMuted,
                              fontSize: 12,
                              weight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            Text('5 CANDIDATE FOOTBALLERS', style: AppTypography.sectionHeader(inkMuted)),
            const SizedBox(height: 8),

            // 5 Candidates — Blind Pick (Name, Position, Nationality ONLY, NO team, NO stat value)
            ..._currentCandidates.map((player) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _selectPlayer(player),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        PlayerAvatar(
                          name: player.name,
                          size: 40,
                          position: player.primaryPosition,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                player.name,
                                style: AppTypography.bodyMedium(ink).copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                player.nationality ?? 'International',
                                style: AppTypography.caption(inkMuted),
                              ),
                            ],
                          ),
                        ),
                        PositionBadge(position: player.primaryPosition),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.touch_app_outlined,
                          size: 18,
                          color: AppPalette.gold,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildGrandRevealScreen(Color ink, Color inkMuted, Color border, bool isDark) {
    int total = 0;
    for (final attr in _steps) {
      total += (_draftedStats[attr]?['value'] as int? ?? 50);
    }
    final compositeOvr = (total / _steps.length).round();

    String tierName = 'SOLID PROFESSIONAL';
    Color tierColor = AppPalette.ratingColor(compositeOvr);
    if (compositeOvr >= 92) {
      tierName = 'LEGENDARY / BALLON D\'OR TIER';
    } else if (compositeOvr >= 88) {
      tierName = 'WORLD CLASS ARCHETYPE';
    } else if (compositeOvr >= 84) {
      tierName = 'ELITE EUROPEAN SQUAD';
    } else if (compositeOvr >= 80) {
      tierName = 'TOP DIVISION REGULAR';
    }

    final formulaString = '(${_steps.map((a) => '${a.code} ${_draftedStats[a]?['value'] ?? 0}').join(' + ')}) ÷ 6 = $compositeOvr OVR';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Build-a-Player', style: AppTypography.heading(ink, fontSize: 22)),
            Text('Grand Reveal • Complete', style: AppTypography.bodySmall(inkMuted)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grand Reveal Hero Card
            AlmanacCard(
              borderColor: tierColor,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('HYBRID ARCHETYPE CREATED', style: AppTypography.sectionHeader(AppPalette.gold)),
                  const SizedBox(height: 12),
                  StatBadge(value: compositeOvr, label: 'OVR', isLarge: true),
                  const SizedBox(height: 10),
                  Text(
                    tierName,
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: tierColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppPalette.darkBg : AppPalette.lightBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      children: [
                        Text('CALCULATION BREAKDOWN', style: AppTypography.caption(inkMuted)),
                        const SizedBox(height: 2),
                        Text(
                          formulaString,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Harvested Attributes Breakdown
            AlmanacCard(
              sectionTitle: 'HARVESTED ATTRIBUTES BREAKDOWN',
              child: Column(
                children: _steps.map((attr) {
                  final data = _draftedStats[attr];
                  final val = data?['value'] as int? ?? 50;
                  final pName = data?['playerName'] as String? ?? 'Unknown';
                  final pPos = data?['playerPosition'] as String? ?? '';
                  final pClub = data?['playerClub'] as String? ?? '';
                  final col = AppPalette.ratingColor(val);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                PositionBadge(position: attr.code, isSmall: true),
                                const SizedBox(width: 8),
                                Text(
                                  attr.label,
                                  style: AppTypography.bodyMedium(ink).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Text(
                              val.toString(),
                              style: AppTypography.statNumber(col, fontSize: 16, weight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            PlayerAvatar(name: pName, size: 20, position: pPos),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$pName • $pClub ($pPos)',
                                style: AppTypography.caption(inkMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (val / 99.0).clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: border,
                            valueColor: AlwaysStoppedAnimation(col),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _resetDraft,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('DRAFT ANOTHER HYBRID'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
