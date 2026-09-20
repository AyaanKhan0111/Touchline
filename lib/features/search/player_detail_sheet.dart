import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/player.dart';
import '../../domain/services/player_growth_service.dart';
import '../shared/widgets/player_avatar.dart';
import '../shared/widgets/stat_badge.dart';
import '../career/career_screen.dart';

/// Modal bottom sheet displaying a player's full almanac entry.
void showPlayerDetailSheet(
  BuildContext context,
  Player player, {
  bool isCareerMode = false,
  String? careerClubName,
  int? careerSeason,
  int careerAppearances = 0,
  int careerGoals = 0,
  int careerAssists = 0,
  int careerCleanSheets = 0,
  double? careerAverageRating,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => PlayerDetailSheet(
      player: player,
      isCareerMode: isCareerMode,
      careerClubName: careerClubName,
      careerSeason: careerSeason,
      careerAppearances: careerAppearances,
      careerGoals: careerGoals,
      careerAssists: careerAssists,
      careerCleanSheets: careerCleanSheets,
      careerAverageRating: careerAverageRating,
    ),
  );
}

class PlayerDetailSheet extends StatelessWidget {
  final Player player;
  final bool isCareerMode;
  final String? careerClubName;
  final int? careerSeason;
  final int careerAppearances;
  final int careerGoals;
  final int careerAssists;
  final int careerCleanSheets;
  final double? careerAverageRating;

  const PlayerDetailSheet({
    super.key,
    required this.player,
    this.isCareerMode = false,
    this.careerClubName,
    this.careerSeason,
    this.careerAppearances = 0,
    this.careerGoals = 0,
    this.careerAssists = 0,
    this.careerCleanSheets = 0,
    this.careerAverageRating,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised;
    final ink = isDark ? AppPalette.darkInk : AppPalette.lightInk;
    final inkMuted = isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted;
    final border = isDark ? AppPalette.darkBorder : AppPalette.lightBorder;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: inkMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Player Header
                  Row(
                    children: [
                      PlayerAvatar(name: player.name, size: 52),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player.name,
                              style: AppTypography.titleMedium(ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isCareerMode
                                  ? '${careerClubName ?? player.teamName} • Season ${careerSeason ?? 1} (${CareerScreen.getSeasonYearLabel(careerSeason ?? 1)})'
                                  : '${player.teamName} • ${player.season}',
                              style: AppTypography.bodySmall(inkMuted),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatBadge(value: player.overall, label: player.primaryPosition, isLarge: true),
                          if (player.potential != null && player.potential! > player.overall) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppPalette.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppPalette.green.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'POT ${player.potential!.round()}',
                                style: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppPalette.green,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  Divider(color: border, height: 1),
                  const SizedBox(height: 16),

                  // Core Attributes Matrix (6 stats)
                  Text(
                    'CORE ATTRIBUTES',
                    style: AppTypography.sectionHeader(inkMuted),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildAttrCell('PAC', player.pace, ink),
                      _buildAttrCell('SHO', player.shooting, ink),
                      _buildAttrCell('PAS', player.passing, ink),
                      _buildAttrCell('DRI', player.dribbling, ink),
                      _buildAttrCell('DEF', player.defending, ink),
                      _buildAttrCell('PHY', player.physicality, ink),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Divider(color: border, height: 1),
                  const SizedBox(height: 16),

                  // Bio & Physical Register
                  Text(
                    'BIOGRAPHICAL REGISTER',
                    style: AppTypography.sectionHeader(inkMuted),
                  ),
                  const SizedBox(height: 8),
                  _buildDataRow('Nationality', player.nationality ?? 'Unknown', ink, inkMuted),
                  _buildDataRow('Preferred Foot', player.preferredFoot ?? 'Unknown', ink, inkMuted),
                  _buildDataRow('Height / Weight', '${player.heightCm?.toStringAsFixed(0) ?? '—'} cm / ${player.weightKg?.toStringAsFixed(0) ?? '—'} kg', ink, inkMuted),
                  _buildDataRow(
                    isCareerMode ? 'Age' : 'Age (Season ${player.season})',
                    player.age != null ? '${player.age!.toInt()} yrs' : '—',
                    ink,
                    inkMuted,
                  ),
                  if (player.potential != null)
                    _buildDataRow('FIFA Potential', '${player.potential!.round()}', ink, inkMuted),
                  _buildDataRow('Development Status', PlayerGrowthService.getPotentialTierDescription(player), ink, inkMuted),
                  _buildDataRow('Shirt Number', player.shirtNumber != null ? '#${player.shirtNumber!.toInt()}' : '—', ink, inkMuted),
                  _buildDataRow('Eligible Positions', player.allPositions, ink, inkMuted),

                  if (isCareerMode) ...[
                    const SizedBox(height: 18),
                    Divider(color: border, height: 1),
                    const SizedBox(height: 16),
                    Text(
                      'CAREER RECORD (THIS SAVE)',
                      style: AppTypography.sectionHeader(inkMuted),
                    ),
                    const SizedBox(height: 8),
                    _buildDataRow('Club', careerClubName ?? player.teamName, ink, inkMuted),
                    _buildDataRow('Matches Played', '$careerAppearances', ink, inkMuted),
                    _buildDataRow('Goals Scored', '$careerGoals', ink, inkMuted),
                    _buildDataRow('Assists', '$careerAssists', ink, inkMuted),
                    if (player.primaryPosition == 'GK' || const ['CB', 'LB', 'RB', 'LWB', 'RWB'].contains(player.primaryPosition))
                      _buildDataRow('Clean Sheets', '$careerCleanSheets', ink, inkMuted),
                    if (careerAverageRating != null && careerAverageRating! > 0)
                      _buildDataRow('Average Rating', '★ ${careerAverageRating!.toStringAsFixed(1)}', ink, inkMuted),
                    _buildDataRow(
                      'Squad Status',
                      player.overall >= 84 ? 'Key Starter' : (player.overall >= 78 ? 'First Team' : 'Rotation Squad'),
                      ink,
                      inkMuted,
                    ),
                    _buildDataRow(
                      'Market Valuation',
                      player.marketValueMillions != null
                          ? '£${player.marketValueMillions!.toStringAsFixed(1)}M'
                          : '£${calculatePlayerValuation(player).toStringAsFixed(1)}M',
                      ink,
                      inkMuted,
                    ),
                  ] else ...[
                    if (player.careerGoals != null || player.careerAppearances != null) ...[
                      const SizedBox(height: 18),
                      Divider(color: border, height: 1),
                      const SizedBox(height: 16),
                      Text(
                        'CAREER STATISTICS (TRANSFERMARKT)',
                        style: AppTypography.sectionHeader(inkMuted),
                      ),
                      const SizedBox(height: 8),
                      _buildDataRow('Career Appearances', '${player.careerAppearances?.toInt() ?? 0}', ink, inkMuted),
                      _buildDataRow('Career Goals', '${player.careerGoals?.toInt() ?? 0}', ink, inkMuted),
                      _buildDataRow('Career Assists', '${player.careerAssists?.toInt() ?? 0}', ink, inkMuted),
                      _buildDataRow('Cards (Yellow / Red)', '${player.careerYellows?.toInt() ?? 0} / ${player.careerReds?.toInt() ?? 0}', ink, inkMuted),
                      _buildDataRow('Total Minutes', '${player.careerMinutes?.toInt() ?? 0}', ink, inkMuted),
                    ],

                    const SizedBox(height: 18),
                    Divider(color: border, height: 1),
                    const SizedBox(height: 16),

                    // Metadata
                    Text(
                      'CATALOG IDENTIFIERS',
                      style: AppTypography.sectionHeader(inkMuted),
                    ),
                    const SizedBox(height: 8),
                    _buildDataRow('Player ID', player.playerId, ink, inkMuted),
                    _buildDataRow('Mode / Context', player.mode, ink, inkMuted),
                    _buildDataRow('Competition', player.competitionName ?? 'Domestic League', ink, inkMuted),
                    _buildDataRow('Market Value', player.marketValueMillions != null ? '£${player.marketValueMillions!.toStringAsFixed(1)}M' : '—', ink, inkMuted),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttrCell(String label, int val, Color ink) {
    final color = AppPalette.ratingColor(val);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              val.toString(),
              style: AppTypography.statNumber(ink, fontSize: 16, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value, Color ink, Color inkMuted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall(inkMuted)),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ink,
              fontFeatures: AppTypography.tabularFeatures,
            ),
          ),
        ],
      ),
    );
  }
}
