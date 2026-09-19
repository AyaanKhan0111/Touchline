import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/services/sim_engine.dart';
import '../shared/widgets/club_badge.dart';
import '../shared/widgets/stat_badge.dart';

String _getClubCode(String name) {
  final clean = name.trim();
  if (clean.contains(' ')) {
    final parts = clean.split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return (parts[0][0] + parts[1].substring(0, min(2, parts[1].length))).toUpperCase();
    }
  }
  return clean.length >= 3 ? clean.substring(0, 3).toUpperCase() : clean.toUpperCase();
}

/// Modal bottom sheet showing rich post-match report including scorers, assists,
/// substitutions, player ratings, MOTM, and team match statistics.
class MatchDetailSheet extends StatelessWidget {
  final MatchResult match;
  final String competitionName;

  const MatchDetailSheet({
    super.key,
    required this.match,
    this.competitionName = 'PREMIER LEAGUE',
  });

  static void show(BuildContext context, MatchResult match, {String competitionName = 'PREMIER LEAGUE'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MatchDetailSheet(
        match: match,
        competitionName: competitionName,
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 8.0) return const Color(0xFFFFD700); // Gold
    if (rating >= 7.0) return AppPalette.green;
    if (rating >= 6.0) return AppPalette.amber;
    return AppPalette.red;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C1319) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Scrollable match report content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // 1. MATCH HEADER & SCOREBOARD
                _buildScoreboard(context, isDark),

                const SizedBox(height: 16),

                // 2. MAN OF THE MATCH (MOTM) HIGHLIGHT
                if (match.motm.isNotEmpty) _buildMotmCard(isDark),

                const SizedBox(height: 16),

                // 3. GOALS TIMELINE
                _buildSectionHeader('MATCH TIMELINE & GOALS', Icons.sports_soccer),
                const SizedBox(height: 8),
                _buildGoalsTimeline(isDark),

                const SizedBox(height: 16),

                // 4. SUBSTITUTIONS
                if (match.homeSubstitutions.isNotEmpty || match.awaySubstitutions.isNotEmpty) ...[
                  _buildSectionHeader('TACTICAL SUBSTITUTIONS', Icons.swap_horiz),
                  const SizedBox(height: 8),
                  _buildSubstitutionsTimeline(isDark),
                  const SizedBox(height: 16),
                ],

                // 5. MATCH STATISTICS (POSSESSION, SHOTS, CORNERS)
                _buildSectionHeader('MATCH STATISTICS', Icons.analytics_outlined),
                const SizedBox(height: 8),
                _buildStatsComparison(isDark),

                const SizedBox(height: 16),

                // 6. PLAYER PERFORMANCE RATINGS
                _buildSectionHeader('PLAYER RATINGS', Icons.grade_outlined),
                const SizedBox(height: 8),
                _buildPlayerRatings(isDark),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppPalette.gold),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: AppPalette.gold,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreboard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13202C) : const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          // Competition banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppPalette.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              competitionName.toUpperCase(),
              style: const TextStyle(
                color: AppPalette.gold,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Teams & Scoreline
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Home Club
              Expanded(
                child: Column(
                  children: [
                    ClubBadge(code: _getClubCode(match.homeClub), size: 48),
                    const SizedBox(height: 6),
                    Text(
                      match.homeClub,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Score Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF091016) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppPalette.gold.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${match.homeGoals} – ${match.awayGoals}',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),

              // Away Club
              Expanded(
                child: Column(
                  children: [
                    ClubBadge(code: _getClubCode(match.awayClub), size: 48),
                    const SizedBox(height: 6),
                    Text(
                      match.awayClub,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Text(
            'Full-Time • Attendance: ${match.attendance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotmCard(bool isDark) {
    final motmRating = match.homePlayerRatings[match.motm] ?? match.awayPlayerRatings[match.motm] ?? 8.5;
    final isHomePlayer = match.homePlayerRatings.containsKey(match.motm);
    final motmClub = isHomePlayer ? match.homeClub : match.awayClub;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MAN OF THE MATCH',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  '${match.motm} ($motmClub)',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              motmRating.toStringAsFixed(1),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsTimeline(bool isDark) {
    final allEvents = <Map<String, dynamic>>[];
    for (final e in match.homeGoalEvents) {
      allEvents.add({'event': e, 'isHome': true, 'club': match.homeClub});
    }
    for (final e in match.awayGoalEvents) {
      allEvents.add({'event': e, 'isHome': false, 'club': match.awayClub});
    }

    if (allEvents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13202C) : const Color(0xFFF4F6F8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No goals scored in this match (0–0 Draw)',
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12),
          ),
        ),
      );
    }

    allEvents.sort((a, b) => (a['event'] as GoalEvent).minute.compareTo((b['event'] as GoalEvent).minute));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13202C) : const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: allEvents.map((item) {
          final event = item['event'] as GoalEvent;
          final club = item['club'] as String;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // Minute marker
                Container(
                  width: 36,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: AppPalette.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppPalette.green.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    "${event.minute}'",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppPalette.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.sports_soccer, size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            event.scorerName,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (event.isPenalty) ...[
                            const SizedBox(width: 4),
                            _buildTag('PEN', AppPalette.amber),
                          ],
                          if (event.isOwnGoal) ...[
                            const SizedBox(width: 4),
                            _buildTag('OG', AppPalette.red),
                          ],
                          const SizedBox(width: 6),
                          Text(
                            '($club)',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      if (event.assisterName != null && event.assisterName!.isNotEmpty)
                        Text(
                          'Assist: ${event.assisterName}',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                ClubBadge(code: _getClubCode(club), size: 20),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubstitutionsTimeline(bool isDark) {
    final allSubs = <Map<String, dynamic>>[];
    for (final s in match.homeSubstitutions) {
      allSubs.add({'sub': s, 'club': match.homeClub});
    }
    for (final s in match.awaySubstitutions) {
      allSubs.add({'sub': s, 'club': match.awayClub});
    }

    allSubs.sort((a, b) => (a['sub'] as SubstitutionEvent).minute.compareTo((b['sub'] as SubstitutionEvent).minute));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13202C) : const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: allSubs.map((item) {
          final sub = item['sub'] as SubstitutionEvent;
          final club = item['club'] as String;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // Minute marker
                Container(
                  width: 36,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    "${sub.minute}'",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_upward_rounded, size: 14, color: AppPalette.green),
                const SizedBox(width: 4),
                Text(
                  sub.playerIn,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_downward_rounded, size: 14, color: AppPalette.red),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    sub.playerOut,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  '($club)',
                  style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsComparison(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13202C) : const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildStatRow('Possession', '${match.homeStats.possession}%', '${match.awayStats.possession}%',
              match.homeStats.possession / 100, isDark),
          const SizedBox(height: 10),
          _buildStatRow('Total Shots', '${match.homeStats.shots}', '${match.awayStats.shots}',
              match.homeStats.shots / (match.homeStats.shots + match.awayStats.shots + 0.1), isDark),
          const SizedBox(height: 10),
          _buildStatRow('Shots on Target', '${match.homeStats.shotsOnTarget}', '${match.awayStats.shotsOnTarget}',
              match.homeStats.shotsOnTarget / (match.homeStats.shotsOnTarget + match.awayStats.shotsOnTarget + 0.1), isDark),
          const SizedBox(height: 10),
          _buildStatRow('Corners', '${match.homeStats.corners}', '${match.awayStats.corners}',
              match.homeStats.corners / (match.homeStats.corners + match.awayStats.corners + 0.1), isDark),
          const SizedBox(height: 10),
          _buildStatRow('Fouls', '${match.homeStats.fouls}', '${match.awayStats.fouls}',
              match.homeStats.fouls / (match.homeStats.fouls + match.awayStats.fouls + 0.1), isDark),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String homeVal, String awayVal, double ratio, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              homeVal,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 11,
              ),
            ),
            Text(
              awayVal,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Row(
            children: [
              Expanded(
                flex: (ratio.clamp(0.05, 0.95) * 100).round(),
                child: Container(height: 6, color: AppPalette.green),
              ),
              Expanded(
                flex: ((1.0 - ratio.clamp(0.05, 0.95)) * 100).round(),
                child: Container(height: 6, color: Colors.blueAccent),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerRatings(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13202C) : const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Home Player Ratings
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClubBadge(code: _getClubCode(match.homeClub), size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        match.homeClub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 12),
                ...match.homePlayerRatings.entries.map((e) =>
                    _buildRatingItem(e.key, e.value, match.homePlayerPositions[e.key], isDark)),
              ],
            ),
          ),
          Container(width: 1, height: 260, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 6)),
          // Away Player Ratings
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClubBadge(code: _getClubCode(match.awayClub), size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        match.awayClub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 12),
                ...match.awayPlayerRatings.entries.map((e) =>
                    _buildRatingItem(e.key, e.value, match.awayPlayerPositions[e.key], isDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingItem(String name, double rating, String? position, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          if (position != null && position.isNotEmpty) ...[
            PositionBadge(position: position, isSmall: true),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 10.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: _getRatingColor(rating).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _getRatingColor(rating).withValues(alpha: 0.4)),
            ),
            child: Text(
              rating.toStringAsFixed(1),
              style: TextStyle(
                color: _getRatingColor(rating),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}
