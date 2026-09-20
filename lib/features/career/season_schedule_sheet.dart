import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/services/sim_engine.dart';
import '../shared/widgets/club_badge.dart';
import 'career_screen.dart';
import 'match_detail_sheet.dart';

/// Editorial Season Fixture Calendar Sheet (Issue #12)
/// Allows managers to inspect the complete 38-match / 18-match schedule,
/// review historical scorelines, identify upcoming opponents, and track transfer window deadlines.
class SeasonScheduleSheet extends StatefulWidget {
  final String userClub;
  final String userClubCode;
  final String leagueName;
  final String leagueId;
  final int currentGameweek;
  final int totalGameweeks;
  final int currentSeason;
  final List<List<ScheduledFixture>> schedule;
  final Map<int, List<MatchResult>> seasonResultsArchive;

  const SeasonScheduleSheet({
    super.key,
    required this.userClub,
    required this.userClubCode,
    required this.leagueName,
    required this.leagueId,
    required this.currentGameweek,
    required this.totalGameweeks,
    this.currentSeason = 1,
    required this.schedule,
    required this.seasonResultsArchive,
  });

  @override
  State<SeasonScheduleSheet> createState() => _SeasonScheduleSheetState();
}

class _SeasonScheduleSheetState extends State<SeasonScheduleSheet> {
  int _selectedTab = 0; // 0: My Fixtures, 1: League-Wide Rounds
  late int _browsedGameweek;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _browsedGameweek = widget.currentGameweek.clamp(1, widget.totalGameweeks);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _resolveClubCode(String clubName) {
    for (final l in kAvailableLeagues) {
      if (l.clubCodes.containsKey(clubName)) {
        return l.clubCodes[clubName]!;
      }
    }
    return clubName.length >= 3 ? clubName.substring(0, 3).toUpperCase() : clubName.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink = theme.colorScheme.onSurface;
    final inkMuted = ink.withValues(alpha: 0.65);
    final border = theme.dividerColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: inkMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                ClubBadge(code: widget.userClubCode, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FIXTURE CALENDAR',
                        style: AppTypography.sectionHeader(AppPalette.gold),
                      ),
                      Text(
                        '${widget.leagueName} ${CareerScreen.getSeasonYearLabel(widget.currentSeason)}',
                        style: AppTypography.titleMedium(ink).copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppPalette.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppPalette.gold.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'GW ${widget.currentGameweek}/${widget.totalGameweeks}',
                    style: AppTypography.caption(AppPalette.gold).copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // View Selector Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      title: '${widget.userClubCode} FIXTURES',
                      icon: Icons.shield_outlined,
                      isSelected: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      title: 'LEAGUE ROUNDS',
                      icon: Icons.format_list_bulleted_rounded,
                      isSelected: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Main View Content
          Expanded(
            child: _selectedTab == 0 ? _buildMyFixturesView() : _buildLeagueRoundsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppPalette.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.black : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.black : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 1: MY CLUB FIXTURES
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildMyFixturesView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: widget.totalGameweeks,
      itemBuilder: (context, index) {
        final gw = index + 1;
        if (index >= widget.schedule.length) return const SizedBox.shrink();

        final roundMatches = widget.schedule[index];
        final userFixture = roundMatches.firstWhere(
          (f) => f.homeClub == widget.userClub || f.awayClub == widget.userClub,
          orElse: () => roundMatches.first,
        );

        final isHome = userFixture.homeClub == widget.userClub;
        final opponent = isHome ? userFixture.awayClub : userFixture.homeClub;
        final opponentCode = _resolveClubCode(opponent);

        // Milestone markers
        Widget? milestoneMarker;
        final summerDeadline = widget.totalGameweeks == 18 ? 3 : 4;
        final winterStart = widget.totalGameweeks == 18 ? 9 : 19;
        final winterDeadline = widget.totalGameweeks == 18 ? 11 : 23;

        if (gw == summerDeadline + 1) {
          milestoneMarker = _buildMilestoneBanner(
            title: 'SUMMER TRANSFER WINDOW CLOSED',
            subtitle: 'Squads locked for autumn fixtures • Reopens in January',
            icon: Icons.lock_outline_rounded,
            color: Colors.amber.shade700,
          );
        } else if (gw == winterStart) {
          milestoneMarker = _buildMilestoneBanner(
            title: 'WINTER TRANSFER WINDOW OPEN',
            subtitle: 'Mid-season market active • +£10.0M Board War Chest Injection',
            icon: Icons.ac_unit_rounded,
            color: Colors.lightBlueAccent,
          );
        } else if (gw == winterDeadline + 1) {
          milestoneMarker = _buildMilestoneBanner(
            title: 'WINTER TRANSFER WINDOW CLOSED',
            subtitle: 'Final run-in rosters locked until the end of the campaign',
            icon: Icons.lock_clock_rounded,
            color: Colors.amber.shade800,
          );
        }

        // Result lookup if past match
        MatchResult? userResult;
        if (gw < widget.currentGameweek && widget.seasonResultsArchive.containsKey(gw)) {
          final results = widget.seasonResultsArchive[gw]!;
          userResult = results.firstWhere(
            (r) => r.homeClub == widget.userClub || r.awayClub == widget.userClub,
            orElse: () => results.first,
          );
        }

        return Column(
          children: [
            ?milestoneMarker,
            _buildMyFixtureCard(
              gameweek: gw,
              isHome: isHome,
              opponent: opponent,
              opponentCode: opponentCode,
              isCurrent: gw == widget.currentGameweek,
              isPast: gw < widget.currentGameweek,
              result: userResult,
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildMilestoneBanner({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyFixtureCard({
    required int gameweek,
    required bool isHome,
    required String opponent,
    required String opponentCode,
    required bool isCurrent,
    required bool isPast,
    MatchResult? result,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink = theme.colorScheme.onSurface;

    Color borderColor = theme.dividerColor;
    Color bgColor = isDark ? AppPalette.darkCard : AppPalette.lightCard;

    if (isCurrent) {
      borderColor = AppPalette.gold;
      bgColor = AppPalette.gold.withValues(alpha: 0.08);
    }

    String statusText = 'UPCOMING';
    Color statusColor = ink.withValues(alpha: 0.6);
    Widget? scoreWidget;

    if (isCurrent) {
      statusText = 'NEXT FIXTURE';
      statusColor = AppPalette.gold;
    } else if (isPast && result != null) {
      final userGoals = isHome ? result.homeGoals : result.awayGoals;
      final oppGoals = isHome ? result.awayGoals : result.homeGoals;
      final won = userGoals > oppGoals;
      final drawn = userGoals == oppGoals;

      final outcomeLabel = won ? 'W' : (drawn ? 'D' : 'L');
      final outcomeColor = won ? AppPalette.green : (drawn ? Colors.amber : AppPalette.red);

      scoreWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: outcomeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: outcomeColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              outcomeLabel,
              style: TextStyle(fontWeight: FontWeight.w900, color: outcomeColor, fontSize: 12),
            ),
            const SizedBox(width: 6),
            Text(
              '$userGoals - $oppGoals',
              style: AppTypography.statNumber(outcomeColor, fontSize: 13, weight: FontWeight.w800),
            ),
          ],
        ),
      );
    }

    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isCurrent ? 1.5 : 1),
      ),
      child: Row(
        children: [
          // Gameweek indicator
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppPalette.gold
                  : (isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'GW',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isCurrent ? Colors.black : ink.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  '$gameweek',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isCurrent ? Colors.black : ink,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Home/Away Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isHome ? AppPalette.green.withValues(alpha: 0.15) : AppPalette.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isHome ? 'HOME' : 'AWAY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isHome ? AppPalette.green : AppPalette.blue,
                letterSpacing: 0.4,
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Opponent Club Badge & Name
          ClubBadge(code: opponentCode, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opponent,
                  style: AppTypography.bodyLarge(ink).copyWith(
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isHome ? 'vs $opponent' : '@ $opponent',
                  style: AppTypography.caption(ink.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),

          // Scoreline or Status Badge
          if (scoreWidget != null)
            scoreWidget
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );

    if (isPast && result != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => MatchDetailSheet.show(context, result, competitionName: widget.leagueName),
          child: card,
        ),
      );
    }

    return card;
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 2: LEAGUE-WIDE ROUNDS BROWSER
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildLeagueRoundsView() {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final roundIdx = _browsedGameweek - 1;
    final fixtures = (roundIdx >= 0 && roundIdx < widget.schedule.length)
        ? widget.schedule[roundIdx]
        : const <ScheduledFixture>[];

    final isPast = _browsedGameweek < widget.currentGameweek;
    final results = widget.seasonResultsArchive[_browsedGameweek];

    return Column(
      children: [
        // Gameweek Selector Carousel
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.totalGameweeks,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final gw = index + 1;
              final isSelected = gw == _browsedGameweek;
              final isCurrent = gw == widget.currentGameweek;
              final isGwPast = gw < widget.currentGameweek;

              Color pillColor = Theme.of(context).dividerColor.withValues(alpha: 0.15);
              Color textColor = ink.withValues(alpha: 0.7);

              if (isSelected) {
                pillColor = AppPalette.gold;
                textColor = Colors.black;
              } else if (isCurrent) {
                pillColor = AppPalette.gold.withValues(alpha: 0.2);
                textColor = AppPalette.gold;
              }

              return InkWell(
                onTap: () => setState(() => _browsedGameweek = gw),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppPalette.gold : (isCurrent ? AppPalette.gold : Colors.transparent),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'GW $gw',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      if (isGwPast) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.check, size: 12, color: textColor),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // Round summary header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GAMEWEEK $_browsedGameweek FIXTURES',
                style: AppTypography.caption(AppPalette.gold).copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                isPast
                    ? 'Round Completed'
                    : (_browsedGameweek == widget.currentGameweek ? 'Active Round' : 'Scheduled'),
                style: AppTypography.caption(ink.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Fixture match cards for this gameweek
        Expanded(
          child: fixtures.isEmpty
              ? const Center(child: Text('No fixtures scheduled for this round.'))
              : Builder(
                  builder: (context) {
                    // Ensure User Club match is placed at index 0 (Fix 23 / User Fix 1)
                    final sortedFixtures = List<ScheduledFixture>.from(fixtures)..sort((a, b) {
                      final aUser = a.homeClub == widget.userClub || a.awayClub == widget.userClub;
                      final bUser = b.homeClub == widget.userClub || b.awayClub == widget.userClub;
                      if (aUser && !bUser) return -1;
                      if (!aUser && bUser) return 1;
                      return 0;
                    });

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: sortedFixtures.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final f = sortedFixtures[index];
                        final homeCode = _resolveClubCode(f.homeClub);
                        final awayCode = _resolveClubCode(f.awayClub);
                        final isUserClubMatch = f.homeClub == widget.userClub || f.awayClub == widget.userClub;

                        MatchResult? matchResult;
                        if (results != null) {
                          matchResult = results.firstWhere(
                            (r) => r.homeClub == f.homeClub && r.awayClub == f.awayClub,
                            orElse: () => results.first,
                          );
                        }

                        return _buildLeagueMatchCard(
                          homeClub: f.homeClub,
                          homeCode: homeCode,
                          awayClub: f.awayClub,
                          awayCode: awayCode,
                          isUserClubMatch: isUserClubMatch,
                          isPast: isPast,
                          result: matchResult,
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLeagueMatchCard({
    required String homeClub,
    required String homeCode,
    required String awayClub,
    required String awayCode,
    required bool isUserClubMatch,
    required bool isPast,
    MatchResult? result,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink = theme.colorScheme.onSurface;

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isUserClubMatch
            ? AppPalette.gold.withValues(alpha: 0.08)
            : (isDark ? AppPalette.darkCard : AppPalette.lightCard),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUserClubMatch ? AppPalette.gold : theme.dividerColor,
          width: isUserClubMatch ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Home Team
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    homeClub,
                    style: AppTypography.bodyMedium(ink).copyWith(
                      fontWeight: homeClub == widget.userClub ? FontWeight.w800 : FontWeight.w600,
                      color: homeClub == widget.userClub ? AppPalette.gold : ink,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ClubBadge(code: homeCode, size: 26),
              ],
            ),
          ),

          // Score / VS Pill
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: isPast && result != null
                ? Text(
                    '${result.homeGoals} - ${result.awayGoals}',
                    style: AppTypography.statNumber(
                      isUserClubMatch ? AppPalette.gold : ink,
                      fontSize: 13,
                      weight: FontWeight.w800,
                    ),
                  )
                : Text(
                    'VS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: ink.withValues(alpha: 0.5),
                    ),
                  ),
          ),

          // Away Team
          Expanded(
            child: Row(
              children: [
                ClubBadge(code: awayCode, size: 26),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    awayClub,
                    style: AppTypography.bodyMedium(ink).copyWith(
                      fontWeight: awayClub == widget.userClub ? FontWeight.w800 : FontWeight.w600,
                      color: awayClub == widget.userClub ? AppPalette.gold : ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isPast && result != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => MatchDetailSheet.show(context, result, competitionName: widget.leagueName),
          child: card,
        ),
      );
    }

    return card;
  }
}
