import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/db_service.dart';
import '../../core/database/save_service.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sound_service.dart';
import '../../core/storage/prefs_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/player.dart';
import '../../domain/services/sim_engine.dart';
import '../search/player_detail_sheet.dart';
import '../shared/widgets/almanac_card.dart';
import '../shared/widgets/club_badge.dart';
import '../shared/widgets/player_avatar.dart';
import '../shared/widgets/stat_badge.dart';
import 'transfer_market_sheet.dart';
import 'season_schedule_sheet.dart';
import 'formation_editor.dart';
import 'match_detail_sheet.dart';
import '../../domain/services/ucl_engine.dart';
import '../../domain/services/cup_engine.dart';
import '../../domain/services/player_growth_service.dart';
import '../../domain/models/transfer_offer.dart';
import '../../domain/services/transfer_offer_service.dart';
import 'inbound_offers_sheet.dart';
import '../../domain/models/squad_event.dart';
import '../../domain/services/squad_event_service.dart';
import '../../domain/services/transfer_market_service.dart';

class LeagueDefinition {
  final String id;
  final String name;
  final String country;
  final String divisionTitle;
  final List<String> clubs;
  final Map<String, String> clubCodes;

  const LeagueDefinition({
    required this.id,
    required this.name,
    required this.country,
    required this.divisionTitle,
    required this.clubs,
    required this.clubCodes,
  });
}

const List<LeagueDefinition> kAvailableLeagues = [
  LeagueDefinition(
    id: 'premier_league',
    name: 'Premier League',
    country: 'England',
    divisionTitle: 'England First Division',
    clubs: [
      'Arsenal', 'Aston Villa', 'AFC Bournemouth', 'Brentford',
      'Brighton & Hove Albion', 'Chelsea', 'Crystal Palace', 'Everton',
      'Fulham', 'Ipswich Town', 'Leicester City', 'Liverpool',
      'Manchester City', 'Manchester United', 'Newcastle United',
      'Nottingham Forest', 'Tottenham Hotspur', 'West Ham United',
      'Wolverhampton Wanderers', 'Southampton'
    ],
    clubCodes: {
      'Arsenal': 'ARS', 'Aston Villa': 'AVL', 'AFC Bournemouth': 'BOU',
      'Brentford': 'BRE', 'Brighton & Hove Albion': 'BHA', 'Chelsea': 'CHE',
      'Crystal Palace': 'CRY', 'Everton': 'EVE', 'Fulham': 'FUL',
      'Ipswich Town': 'IPS', 'Leicester City': 'LEI', 'Liverpool': 'LIV',
      'Manchester City': 'MCI', 'Manchester United': 'MUN', 'Newcastle United': 'NEW',
      'Nottingham Forest': 'NFO', 'Tottenham Hotspur': 'TOT', 'West Ham United': 'WHU',
      'Wolverhampton Wanderers': 'WOL', 'Southampton': 'SOU'
    },
  ),
  LeagueDefinition(
    id: 'continental_elite',
    name: 'Continental Elite',
    country: 'Europe',
    divisionTitle: 'European Champions League',
    clubs: [
      'Real Madrid', 'Manchester City', 'Bayern Munich', 'Paris Saint-Germain',
      'Liverpool', 'Barcelona', 'Arsenal', 'Inter Milan',
      'Juventus', 'Borussia Dortmund'
    ],
    clubCodes: {
      'Real Madrid': 'RMA', 'Manchester City': 'MCI', 'Bayern Munich': 'BAY',
      'Paris Saint-Germain': 'PSG', 'Liverpool': 'LIV', 'Barcelona': 'BAR',
      'Arsenal': 'ARS', 'Inter Milan': 'INT', 'Juventus': 'JUV',
      'Borussia Dortmund': 'DOR'
    },
  ),
  LeagueDefinition(
    id: 'champions_invitational',
    name: 'Champions Invitational',
    country: 'Europe',
    divisionTitle: 'European Super Division',
    clubs: [
      'AC Milan', 'Atlético Madrid', 'Bayer Leverkusen', 'Chelsea',
      'Manchester United', 'Napoli', 'Sporting CP', 'Sevilla',
      'Benfica', 'Ajax'
    ],
    clubCodes: {
      'AC Milan': 'MIL', 'Atlético Madrid': 'ATM', 'Bayer Leverkusen': 'B04',
      'Chelsea': 'CHE', 'Manchester United': 'MUN', 'Napoli': 'NAP',
      'Sporting CP': 'SCP', 'Sevilla': 'SEV', 'Benfica': 'BEN', 'Ajax': 'AJX'
    },
  ),
  LeagueDefinition(
    id: 'english_championship',
    name: 'English Championship',
    country: 'England',
    divisionTitle: 'England Second Division',
    clubs: [
      'Wolverhampton Wanderers', 'Crystal Palace', 'Fulham', 'AFC Bournemouth',
      'Nottingham Forest', 'Leeds United', 'Burnley', 'Brentford',
      'Sunderland', 'Ipswich Town'
    ],
    clubCodes: {
      'Wolverhampton Wanderers': 'WOL', 'Crystal Palace': 'CRY', 'Fulham': 'FUL',
      'AFC Bournemouth': 'BOU', 'Nottingham Forest': 'NFO', 'Leeds United': 'LEE',
      'Burnley': 'BUR', 'Brentford': 'BRE', 'Sunderland': 'SUN',
      'Ipswich Town': 'IPS'
    },
  ),
  LeagueDefinition(
    id: 'european_heritage',
    name: 'European Heritage',
    country: 'Europe',
    divisionTitle: 'Continental Prestige League',
    clubs: [
      'Porto', 'PSV Eindhoven', 'Marseille', 'Monaco',
      'Celtic', 'Valencia', 'RB Leipzig', 'Leicester City',
      'Southampton', 'Everton'
    ],
    clubCodes: {
      'Porto': 'POR', 'PSV Eindhoven': 'PSV', 'Marseille': 'OM',
      'Monaco': 'ASM', 'Celtic': 'CEL', 'Valencia': 'VAL',
      'RB Leipzig': 'RBL', 'Leicester City': 'LEI', 'Southampton': 'SOU',
      'Everton': 'EVE'
    },
  ),
];

/// Authentic starting transfer war chest in £ millions based on club prestige & real-world financial scale (Issue #12).
double getClubStartingBudget(String clubName) {
  final name = clubName.toLowerCase().trim();

  // Tier 1 — Global Financial Superpowers & High Rollers (£140M - £180M)
  if (name.contains('manchester city') || name == 'man city') return 175.0;
  if (name.contains('real madrid')) return 180.0;
  if (name.contains('paris saint-germain') || name.contains('psg')) return 170.0;
  if (name.contains('chelsea')) return 165.0;
  if (name.contains('manchester united') || name == 'man utd' || name == 'man united') return 160.0;
  if (name.contains('bayern munich') || name.contains('bayern')) return 150.0;
  if (name.contains('arsenal')) return 145.0;
  if (name.contains('liverpool')) return 140.0;

  // Tier 2 — European Contenders & Wealthy Challengers (£85M - £115M)
  if (name.contains('newcastle')) return 115.0;
  if (name.contains('tottenham') || name.contains('spurs')) return 110.0;
  if (name.contains('aston villa')) return 95.0;
  if (name.contains('barcelona')) return 90.0;
  if (name.contains('atlético') || name.contains('atletico')) return 90.0;
  if (name.contains('juventus')) return 90.0;
  if (name.contains('borussia dortmund') || name.contains('dortmund')) return 85.0;
  if (name.contains('inter milan') || name == 'inter') return 85.0;
  if (name.contains('leverkusen')) return 85.0;

  // Tier 3 — Upper Mid-Table & Continental Staples (£55M - £75M)
  if (name.contains('west ham')) return 75.0;
  if (name.contains('milan') && !name.contains('inter')) return 75.0;
  if (name.contains('brighton')) return 70.0;
  if (name.contains('napoli')) return 70.0;
  if (name.contains('bournemouth')) return 65.0;
  if (name.contains('crystal palace')) return 65.0;
  if (name.contains('fulham')) return 60.0;
  if (name.contains('sporting')) return 60.0;
  if (name.contains('benfica')) return 60.0;
  if (name.contains('porto')) return 55.0;
  if (name.contains('everton')) return 55.0;
  if (name.contains('wolverhampton') || name.contains('wolves')) return 55.0;
  if (name.contains('roma')) return 60.0;
  if (name.contains('lazio')) return 55.0;
  if (name.contains('marseille') || name.contains('monaco')) return 60.0;
  if (name.contains('sevilla')) return 55.0;
  if (name.contains('ajax')) return 55.0;
  if (name.contains('psv')) return 55.0;
  if (name.contains('leipzig')) return 65.0;

  // Tier 4 — Relegation Battlers & Promoted Teams (£30M - £45M)
  if (name.contains('brentford')) return 45.0;
  if (name.contains('nottingham') || name.contains('forest')) return 45.0;
  if (name.contains('leicester')) return 40.0;
  if (name.contains('southampton')) return 35.0;
  if (name.contains('burnley')) return 35.0;
  if (name.contains('ipswich')) return 30.0;
  if (name.contains('luton')) return 25.0;
  if (name.contains('sheffield')) return 25.0;
  if (name.contains('leeds')) return 35.0;
  if (name.contains('celtic') || name.contains('galatasaray')) return 45.0;

  // Default baseline for custom / unlisted clubs
  return 65.0;
}

/// Computes authentic end-of-season merit prize money in £ millions based on league finishing position (Issue #12).
/// 1st place: £40.0M down to last place: £5.0M.
double calculateLeagueMeritPrizeMoney(int position, int totalTeams) {
  if (totalTeams <= 1) return 25.0;
  final clampedPos = position.clamp(1, totalTeams);
  final fraction = (clampedPos - 1) / (totalTeams - 1);
  final prize = 40.0 - (fraction * 35.0);
  return double.parse(prize.toStringAsFixed(1));
}

/// Computes UEFA Champions League progression prize money in £ millions (Issue #12).
double calculateUclPrizeMoney(UclTournament? ucl, String clubName) {
  if (ucl == null) return 0.0;
  if (ucl.champion == clubName) return 30.0;
  if (ucl.finalTie != null && (ucl.finalTie!.clubA == clubName || ucl.finalTie!.clubB == clubName)) {
    return 18.0;
  }
  if (ucl.semiFinals.any((t) => t.clubA == clubName || t.clubB == clubName)) {
    return 12.0;
  }
  if (ucl.quarterFinals.any((t) => t.clubA == clubName || t.clubB == clubName)) {
    return 8.0;
  }
  if (ucl.participants.contains(clubName)) {
    return 5.0;
  }
  return 0.0;
}

/// Represents cumulative team performance statistics across the season (Issue #7 & Fix 22).
class ClubTeamStats {
  final String clubName;
  final String clubCode;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int cleanSheets;
  final double avgRating;
  final int points;

  const ClubTeamStats({
    required this.clubName,
    required this.clubCode,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.cleanSheets,
    required this.avgRating,
    required this.points,
  });
}

class ScheduledFixture {
  final String homeClub;
  final String awayClub;

  const ScheduledFixture({
    required this.homeClub,
    required this.awayClub,
  });

  Map<String, dynamic> toMap() => {
    'homeClub': homeClub,
    'awayClub': awayClub,
  };

  factory ScheduledFixture.fromMap(Map<String, dynamic> map) {
    return ScheduledFixture(
      homeClub: map['homeClub'] as String? ?? '',
      awayClub: map['awayClub'] as String? ?? '',
    );
  }
}

List<List<ScheduledFixture>> generateSeasonSchedule(List<String> clubs, {int totalGameweeks = 38}) {
  if (clubs.length < 2) return [];
  final n = clubs.length;
  final rounds = <List<ScheduledFixture>>[];
  final t = List<String>.from(clubs);
  final baseRounds = <List<ScheduledFixture>>[];

  // Berger circle method for single round-robin (n - 1 rounds)
  for (int r = 0; r < n - 1; r++) {
    final roundMatches = <ScheduledFixture>[];
    for (int i = 0; i < n ~/ 2; i++) {
      final t1 = t[i];
      final t2 = t[n - 1 - i];
      if (i == 0 && r % 2 == 1) {
        roundMatches.add(ScheduledFixture(homeClub: t2, awayClub: t1));
      } else {
        roundMatches.add(ScheduledFixture(homeClub: t1, awayClub: t2));
      }
    }
    baseRounds.add(roundMatches);
    final last = t.removeLast();
    t.insert(1, last);
  }

  // Extend to totalGameweeks (e.g. 38 or 18)
  final cycleLength = n - 1;
  final fullDoubleCycles = (totalGameweeks ~/ (cycleLength * 2)) * (cycleLength * 2);

  for (int gw = 0; gw < totalGameweeks; gw++) {
    if (gw < fullDoubleCycles) {
      final cycle = (gw ~/ cycleLength) % 2;
      final baseIdx = gw % cycleLength;
      if (cycle == 0) {
        rounds.add(baseRounds[baseIdx]);
      } else {
        // Reverse home and away for the return fixtures
        rounds.add(
          baseRounds[baseIdx]
              .map((f) => ScheduledFixture(homeClub: f.awayClub, awayClub: f.homeClub))
              .toList(),
        );
      }
    } else {
      // Remaining showcase rounds (e.g. GW 37 & 38)
      final rem = gw - fullDoubleCycles;
      final baseIdx = (rem ~/ 2) % cycleLength;
      if (rem % 2 == 0) {
        rounds.add(baseRounds[baseIdx]);
      } else {
        // Reverse venue to guarantee 19H / 19A balance for all clubs
        rounds.add(
          baseRounds[baseIdx]
              .map((f) => ScheduledFixture(homeClub: f.awayClub, awayClub: f.homeClub))
              .toList(),
        );
      }
    }
  }

  return rounds;
}

enum TransferWindowType { summer, winter, closed }

class TransferWindowState {
  final TransferWindowType type;
  final String title;
  final String subtitle;
  final String deadlineText;
  final bool isOpen;

  const TransferWindowState({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.deadlineText,
    required this.isOpen,
  });

  static TransferWindowState compute({required int gameweek, required int totalGameweeks}) {
    if (totalGameweeks == 18) {
      // Sprint mode (18 GWs): Summer GW 1-3, Winter GW 10-11 (2 weeks after 9 matches)
      if (gameweek <= 3) {
        return const TransferWindowState(
          type: TransferWindowType.summer,
          title: 'SUMMER TRANSFER WINDOW OPEN',
          subtitle: 'Pre-season squad building & signings active.',
          deadlineText: 'Deadline: Gameweek 3',
          isOpen: true,
        );
      } else if (gameweek >= 10 && gameweek <= 11) {
        return const TransferWindowState(
          type: TransferWindowType.winter,
          title: 'WINTER TRANSFER WINDOW OPEN',
          subtitle: 'January market active (2 weeks) • Board budget injection active.',
          deadlineText: 'Deadline: Gameweek 11',
          isOpen: true,
        );
      } else if (gameweek < 10) {
        return const TransferWindowState(
          type: TransferWindowType.closed,
          title: 'TRANSFER WINDOW CLOSED',
          subtitle: 'Autumn fixtures underway • Market closed until mid-season.',
          deadlineText: 'Opens: Gameweek 10',
          isOpen: false,
        );
      } else {
        return const TransferWindowState(
          type: TransferWindowType.closed,
          title: 'TRANSFER WINDOW CLOSED',
          subtitle: 'Sprint run-in • Roster locked for the final fixtures.',
          deadlineText: 'Locked until end of season',
          isOpen: false,
        );
      }
    } else {
      // Full Marathon (38 GWs): Summer GW 1-4, Winter GW 20-21 (2 weeks after 19 matches)
      if (gameweek <= 4) {
        return const TransferWindowState(
          type: TransferWindowType.summer,
          title: 'SUMMER TRANSFER WINDOW OPEN',
          subtitle: 'Pre-season squad construction & recruitment active.',
          deadlineText: 'Deadline: Gameweek 4',
          isOpen: true,
        );
      } else if (gameweek >= 20 && gameweek <= 21) {
        return const TransferWindowState(
          type: TransferWindowType.winter,
          title: 'WINTER TRANSFER WINDOW OPEN',
          subtitle: 'January transfer window active (2 weeks) • £10.0M injection granted.',
          deadlineText: 'Deadline: Gameweek 21',
          isOpen: true,
        );
      } else if (gameweek < 20) {
        return const TransferWindowState(
          type: TransferWindowType.closed,
          title: 'TRANSFER WINDOW CLOSED',
          subtitle: 'Autumn fixtures underway • Roster locked until January.',
          deadlineText: 'Opens: Gameweek 20 (January)',
          isOpen: false,
        );
      } else {
        return const TransferWindowState(
          type: TransferWindowType.closed,
          title: 'TRANSFER WINDOW CLOSED',
          subtitle: 'Championship run-in • Roster locked for the final fixtures.',
          deadlineText: 'Locked until season review',
          isOpen: false,
        );
      }
    }
  }
}

/// Calculates realistic market valuation in millions (£M) based on OVR rating and age (Issue #9)
double calculatePlayerValuation(Player player) {
  final ovr = player.overall;
  final diff = max(0, ovr - 65);
  final ovrFactor = pow(diff, 2.1) * 0.045;

  double ageFactor = 1.0;
  final age = player.age?.toInt() ?? 26;
  if (age <= 23) {
    ageFactor = 1.2; // Young prospect premium
  } else if (age >= 32) {
    ageFactor = max(0.45, 1.0 - (age - 31) * 0.1); // Veteran discount
  }

  double val = ovrFactor * ageFactor;
  if (val < 0.5) val = 0.5; // Minimum valuation of £0.5M
  return double.parse(val.toStringAsFixed(1));
}

/// Calculates sale proceeds in millions (£M) awarded to manager upon selling (90% of valuation)
double calculatePlayerSalePrice(Player player) {
  final val = calculatePlayerValuation(player);
  return double.parse((val * 0.9).clamp(0.5, 999.0).toStringAsFixed(1));
}

class CareerScreen extends ConsumerStatefulWidget {
  const CareerScreen({super.key});

  @override
  ConsumerState<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends ConsumerState<CareerScreen> {
  bool _isLoading = true;
  bool _isConfigured = false;
  Map<String, dynamic>? _existingSaveData;

  // Active Career state
  String _leagueId = 'premier_league';
  String _userClub = 'Manchester United';
  String _userClubCode = 'MUN';
  bool _isCustomClub = false;
  String _squadMode = 'current'; // 'current' or 'random'
  int _currentSeason = 1;
  int _currentGameweek = 1;
  int _totalGameweeks = 38;
  bool _winterBudgetAwarded = false;
  double _budgetMillions = 85.0;
  double _careerPrizeMoneyEarned = 0.0;
  final List<TransferOffer> _pendingTransferOffers = [];
  final List<SquadEvent> _activeSquadEvents = [];
  final Map<String, int> _playerContracts = {};

  List<String> _leagueClubs = [];
  List<Player> _userSquad = [];
  final List<TableEntry> _leagueTable = [];
  final List<MatchResult> _recentResults = [];
  final Map<int, List<MatchResult>> _seasonResultsArchive = {};
  final Map<String, List<String>> _aiClubSquads = {};
  final Map<String, List<SimPlayer>> _aiClubPlayers = {};
  List<List<ScheduledFixture>> _seasonSchedule = [];

  // Formation & Tactics (Issue #4 & Fix 31)
  String _formationId = '4-3-3';
  final Map<String, List<PitchSlot>> _customFormationSlots = {};

  // UCL Tournament Competition (Issue #3)
  UclTournament? _uclTournament;
  final List<MatchResult> _recentUclResults = [];

  // Domestic Cup Competitions: FA Cup & Carabao Cup (Fix 26 / User Fix 4)
  CupTournament? _faCupTournament;
  CupTournament? _carabaoCupTournament;
  final List<MatchResult> _recentFaCupResults = [];
  final List<MatchResult> _recentCarabaoResults = [];
  int _cupSelectedId = 0; // 0: FA Cup, 1: Carabao Cup
  int _cupViewTab = 0; // 0: Brackets, 1: Scorelines, 2: Scorers, 3: Assists, 4: Clean Sheets

  // Career save specific player statistics (Issue #7, #8 & #11)
  final Map<String, int> _playerAppearances = {};
  final Map<String, int> _playerGoals = {};
  final Map<String, int> _playerAssists = {};
  final Map<String, int> _playerCleanSheets = {};
  final Map<String, double> _playerRatingsTotal = {};
  final Map<String, int> _playerRatingsCount = {};

  // League-wide player statistics for Golden Boot, Assists & Clean Sheets (Issue #7 & #8)
  final Map<String, int> _leaguePlayerGoals = {};
  final Map<String, String> _leaguePlayerClubs = {};
  final Map<String, int> _leaguePlayerAssists = {};
  final Map<String, String> _leagueAssistClubs = {};
  final Map<String, int> _leagueClubCleanSheets = {};
  // Cumulative league-wide team match ratings across season (Issue #7 & Fix 22)
  final Map<String, double> _leagueClubRatingTotals = {};
  final Map<String, int> _leagueClubRatingCounts = {};
  int _teamStatsSortIndex = 0; // 0: Attack (GF), 1: Defense (GA), 2: Clean Sheets (CS), 3: Rating (AVG), 4: Goal Diff (GD)
  int _standingsTab = 0; // 0: League Table, 1: Team Stats, 2: Golden Boot, 3: Assists, 4: Clean Sheets, 5: UCL, 6: Domestic Cups
  int _uclViewTab = 0; // 0: Groups, 1: Knockouts, 2: Scorers, 3: Assists, 4: Clean Sheets, 5: All Scorelines
  int _resultsCompTab = 0; // 0: Domestic League, 1: UCL Midweek, 2: FA Cup, 3: Carabao Cup

  late SimEngine _sim;

  // Setup Wizard draft state
  String _setupLeagueId = 'premier_league';
  bool _setupIsCustom = false;
  String _setupSelectedRealClub = 'Manchester United';
  final TextEditingController _customClubNameController = TextEditingController(text: 'Ayaan FC');
  final TextEditingController _customClubCodeController = TextEditingController(text: 'AYN');
  String _setupReplacedClub = 'West Ham United';
  String _setupSquadMode = 'current'; // 'current' or 'random'
  int _setupTotalGameweeks = 38;
  List<Player> _draftedRandomSquad = [];
  int _draftSwapsRemaining = 3;
  bool _isDrafting = false;

  @override
  void initState() {
    super.initState();
    _sim = SimEngine();
    _initSeason();
  }

  @override
  void dispose() {
    _customClubNameController.dispose();
    _customClubCodeController.dispose();
    super.dispose();
  }

  /// Returns the cumulative team match rating across the season (Issue #7 & Fix 22).
  double getClubAverageRating(String club) {
    final count = _leagueClubRatingCounts[club] ?? 0;
    if (count > 0) {
      return double.parse(((_leagueClubRatingTotals[club] ?? 0.0) / count).toStringAsFixed(2));
    }
    double sum = 0.0;
    int matches = 0;
    for (final round in _seasonResultsArchive.values) {
      for (final m in round) {
        if (m.homeClub == club && m.homePlayerRatings.isNotEmpty) {
          sum += m.homePlayerRatings.values.reduce((a, b) => a + b) / m.homePlayerRatings.length;
          matches++;
        } else if (m.awayClub == club && m.awayPlayerRatings.isNotEmpty) {
          sum += m.awayPlayerRatings.values.reduce((a, b) => a + b) / m.awayPlayerRatings.length;
          matches++;
        }
      }
    }
    if (matches > 0) {
      return double.parse((sum / matches).toStringAsFixed(2));
    }
    return 6.80;
  }

  Future<void> _initSeason() async {
    setState(() => _isLoading = true);

    Map<String, dynamic>? saved = await PrefsService.instance.getCareerConfig();
    if (saved == null) {
      // Fallback: Check SQLite touchline_save.db career_save table (Issue #10)
      final sqliteSave = await SaveService.instance.loadCareerState('active_career');
      if (sqliteSave != null) {
        saved = sqliteSave;
      }
    }

    if (saved == null) {
      // No active campaign: show career setup wizard
      setState(() {
        _existingSaveData = null;
        _isConfigured = false;
        _isLoading = false;
      });
      return;
    }

    _existingSaveData = saved;

    _leagueId = saved['leagueId'] as String? ?? 'premier_league';
    _userClub = saved['clubName'] as String? ?? 'Manchester United';
    _userClubCode = saved['clubCode'] as String? ?? 'MUN';
    _isCustomClub = saved['isCustomClub'] as bool? ?? false;
    _squadMode = saved['squadMode'] as String? ?? 'current';
    _budgetMillions = (saved['budget'] as num?)?.toDouble() ?? getClubStartingBudget(_userClub);
    _careerPrizeMoneyEarned = (saved['prizeMoney'] as num?)?.toDouble() ?? 0.0;
    _currentSeason = (saved['season'] as num?)?.toInt() ?? 1;
    _currentGameweek = (saved['gameweek'] as num?)?.toInt() ?? 1;
    _totalGameweeks = (saved['totalGameweeks'] as num?)?.toInt() ?? 38;
    _winterBudgetAwarded = saved['winterBudgetAwarded'] as bool? ?? false;
    _formationId = saved['formationId'] as String? ?? '4-3-3';
    _customFormationSlots.clear();
    if (saved['customFormationSlots'] != null) {
      try {
        final rawMap = saved['customFormationSlots'] as Map<String, dynamic>;
        rawMap.forEach((formId, slotsList) {
          final list = (slotsList as List)
              .map((item) => PitchSlot.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
          _customFormationSlots[formId] = list;
        });
      } catch (_) {}
    }
    final squadIds = List<String>.from((saved['squadIds'] as List?) ?? []);

    // Restore or create UCL Tournament (Issue #3)
    if (saved['uclTournament'] != null) {
      try {
        _uclTournament = UclTournament.fromMap(Map<String, dynamic>.from(saved['uclTournament'] as Map));
      } catch (_) {}
    }
    _uclTournament ??= UclTournament.create(userClub: _userClub);

    // Restore save-specific player statistics (Issue #8 & #11)
    _playerAppearances.clear();
    _playerGoals.clear();
    _playerAssists.clear();
    _playerCleanSheets.clear();
    _playerRatingsTotal.clear();
    _playerRatingsCount.clear();

    final savedStats = saved['playerStats'] as Map<String, dynamic>? ?? {};
    savedStats.forEach((name, stats) {
      if (stats is Map) {
        _playerAppearances[name] = (stats['apps'] as num?)?.toInt() ?? 0;
        _playerGoals[name] = (stats['goals'] as num?)?.toInt() ?? 0;
        _playerCleanSheets[name] = (stats['cleanSheets'] as num?)?.toInt() ?? 0;
      }
    });

    final savedAssists = saved['playerAssists'] as Map<dynamic, dynamic>? ?? {};
    savedAssists.forEach((name, val) {
      _playerAssists[name.toString()] = (val as num).toInt();
    });

    final savedRatingsTotal = saved['playerRatingsTotal'] as Map<dynamic, dynamic>? ?? {};
    savedRatingsTotal.forEach((name, val) {
      _playerRatingsTotal[name.toString()] = (val as num).toDouble();
    });
    final savedRatingsCount = saved['playerRatingsCount'] as Map<dynamic, dynamic>? ?? {};
    savedRatingsCount.forEach((name, val) {
      _playerRatingsCount[name.toString()] = (val as num).toInt();
    });

    // Restore league-wide scorers for Golden Boot race (Issue #8)
    _leaguePlayerGoals.clear();
    _leaguePlayerClubs.clear();
    final savedScorers = saved['leagueScorers'] as Map<String, dynamic>? ?? {};
    savedScorers.forEach((name, data) {
      if (data is Map) {
        _leaguePlayerGoals[name] = (data['goals'] as num?)?.toInt() ?? 0;
        _leaguePlayerClubs[name] = data['club'] as String? ?? '';
      }
    });

    // Restore league-wide assists and clean sheets
    _leaguePlayerAssists.clear();
    _leagueAssistClubs.clear();
    final savedLeagueAssists = saved['leagueAssists'] as Map<dynamic, dynamic>? ?? {};
    savedLeagueAssists.forEach((name, val) {
      _leaguePlayerAssists[name.toString()] = (val as num).toInt();
    });
    final savedLeagueAssistClubs = saved['leagueAssistClubs'] as Map<dynamic, dynamic>? ?? {};
    savedLeagueAssistClubs.forEach((name, val) {
      _leagueAssistClubs[name.toString()] = val.toString();
    });

    _leagueClubCleanSheets.clear();
    final savedCleanSheets = saved['leagueCleanSheets'] as Map<dynamic, dynamic>? ?? {};
    savedCleanSheets.forEach((club, val) {
      _leagueClubCleanSheets[club.toString()] = (val as num).toInt();
    });

    _leagueClubRatingTotals.clear();
    final savedRatingTotals = saved['leagueClubRatingTotals'] as Map<dynamic, dynamic>? ?? {};
    savedRatingTotals.forEach((club, val) {
      _leagueClubRatingTotals[club.toString()] = (val as num).toDouble();
    });

    _leagueClubRatingCounts.clear();
    final savedRatingCounts = saved['leagueClubRatingCounts'] as Map<dynamic, dynamic>? ?? {};
    savedRatingCounts.forEach((club, val) {
      _leagueClubRatingCounts[club.toString()] = (val as num).toInt();
    });

    final league = kAvailableLeagues.firstWhere(
      (l) => l.id == _leagueId,
      orElse: () => kAvailableLeagues.first,
    );

    _leagueClubs = List<String>.from(league.clubs);
    if (_isCustomClub && !_leagueClubs.contains(_userClub)) {
      _leagueClubs.removeLast();
      _leagueClubs.add(_userClub);
    }

    // Restore or create Domestic Cup Tournaments (Fix 26 / User Fix 4)
    final cupClubs = List<String>.from(_leagueClubs);
    for (final c in CupTournament.kDefaultEnglishCupClubs) {
      if (!cupClubs.contains(c)) cupClubs.add(c);
    }
    if (saved['faCupTournament'] != null) {
      try {
        _faCupTournament = CupTournament.fromMap(Map<String, dynamic>.from(saved['faCupTournament'] as Map));
      } catch (_) {}
    }
    _faCupTournament ??= CupTournament.create(id: 'fa_cup', userClub: _userClub, poolClubs: cupClubs);

    if (saved['carabaoCupTournament'] != null) {
      try {
        _carabaoCupTournament = CupTournament.fromMap(Map<String, dynamic>.from(saved['carabaoCupTournament'] as Map));
      } catch (_) {}
    }
    _carabaoCupTournament ??= CupTournament.create(id: 'carabao_cup', userClub: _userClub, poolClubs: cupClubs);

    final db = await DatabaseService.instance.database;

    // Load saved squad players
    if (squadIds.isNotEmpty) {
      final placeholders = List.filled(squadIds.length, '?').join(',');
      final squadRows = await db.rawQuery('''
        SELECT * FROM players
        WHERE player_name IN ($placeholders) OR player_id IN ($placeholders)
        ORDER BY overall DESC, season DESC
      ''', [...squadIds, ...squadIds]);

      final Map<String, Player> playerByName = {};
      for (final r in squadRows) {
        final p = Player.fromMap(r);
        playerByName.putIfAbsent(p.name.trim().toLowerCase(), () => p);
        playerByName.putIfAbsent(p.playerId.trim().toLowerCase(), () => p);
      }

      final List<Player> orderedList = [];
      final Set<String> seen = {};
      for (final id in squadIds) {
        final key = id.trim().toLowerCase();
        final p = playerByName[key];
        if (p != null && !seen.contains(key)) {
          seen.add(key);
          orderedList.add(p);
        }
      }
      for (final p in playerByName.values) {
        final key = p.name.trim().toLowerCase();
        if (!seen.contains(key)) {
          seen.add(key);
          orderedList.add(p);
        }
      }
      _userSquad = orderedList;
    }

    // If squad empty or corrupted, load/generate fresh
    if (_userSquad.length < 11) {
      _userSquad.clear();
      if (_squadMode == 'random') {
        _userSquad = await _generateRandomSquad(db);
      } else {
        final base = _isCustomClub ? league.clubs.first : _userClub;
        _userSquad = await _loadRealSquad(db, base);
      }
      _userSquad = _sortSquadTactically(_userSquad);
      await _persistCareerState();
    }

    // Apply dynamic career growth and aging overrides (Fix 27 / User Fix 5)
    final savedPlayerRatings = saved['playerRatingsOverride'] as Map<dynamic, dynamic>? ?? {};
    final savedPlayerAges = saved['playerAgesOverride'] as Map<dynamic, dynamic>? ?? {};
    if (savedPlayerRatings.isNotEmpty || savedPlayerAges.isNotEmpty) {
      _userSquad = _userSquad.map((p) {
        final keyLower = p.name.trim().toLowerCase();
        int? dynamicRating;
        int? dynamicAge;
        for (final entry in savedPlayerRatings.entries) {
          if (entry.key.toString().trim().toLowerCase() == keyLower) {
            dynamicRating = (entry.value as num?)?.toInt();
            break;
          }
        }
        for (final entry in savedPlayerAges.entries) {
          if (entry.key.toString().trim().toLowerCase() == keyLower) {
            dynamicAge = (entry.value as num?)?.toInt();
            break;
          }
        }
        if (dynamicRating != null || dynamicAge != null) {
          int finalOvr = dynamicRating ?? p.overall;
          final effectiveAge = dynamicAge?.toDouble() ?? p.age ?? 25.0;
          // Fix 33: Non-veterans (age < 33) never decline below their peak canonical rating.
          // Automatically heal any legacy save corruption (e.g. Saka showing 65 instead of 88).
          if (effectiveAge < 33 && finalOvr < p.overall) {
            finalOvr = p.overall;
          }
          return p.copyWith(
            overall: finalOvr,
            age: dynamicAge?.toDouble() ?? p.age,
          );
        }
        return p;
      }).toList();
    }

    // Restore recent matchday results (Issue #7 & Fix 23)
    _recentResults.clear();
    final savedResults = saved['recentResults'] as List<dynamic>? ?? [];
    for (final r in savedResults) {
      try {
        _recentResults.add(MatchResult.fromMap(Map<String, dynamic>.from(r as Map)));
      } catch (_) {}
    }
    // Ensure User Club match is placed at index 0 (Fix 23 / User Fix 1)
    _recentResults.sort((a, b) {
      final aUser = a.homeClub == _userClub || a.awayClub == _userClub;
      final bUser = b.homeClub == _userClub || b.awayClub == _userClub;
      if (aUser && !bUser) return -1;
      if (!aUser && bUser) return 1;
      return 0;
    });

    // Restore recent UCL matchday results (Fix 24 / User Fix 2)
    _recentUclResults.clear();
    final savedUcl = saved['recentUclResults'] as List<dynamic>? ?? [];
    for (final r in savedUcl) {
      try {
        _recentUclResults.add(MatchResult.fromMap(Map<String, dynamic>.from(r as Map)));
      } catch (_) {}
    }
    _recentUclResults.sort((a, b) {
      final aUser = a.homeClub == _userClub || a.awayClub == _userClub;
      final bUser = b.homeClub == _userClub || b.awayClub == _userClub;
      if (aUser && !bUser) return -1;
      if (!aUser && bUser) return 1;
      return 0;
    });

    // Restore recent FA Cup results (Fix 26 / User Fix 4)
    _recentFaCupResults.clear();
    final savedFa = saved['recentFaCupResults'] as List<dynamic>? ?? [];
    for (final r in savedFa) {
      try {
        _recentFaCupResults.add(MatchResult.fromMap(Map<String, dynamic>.from(r as Map)));
      } catch (_) {}
    }
    _recentFaCupResults.sort((a, b) {
      final aUser = a.homeClub == _userClub || a.awayClub == _userClub;
      final bUser = b.homeClub == _userClub || b.awayClub == _userClub;
      if (aUser && !bUser) return -1;
      if (!aUser && bUser) return 1;
      return 0;
    });

    // Restore recent Carabao Cup results (Fix 26 / User Fix 4)
    _recentCarabaoResults.clear();
    final savedCarabao = saved['recentCarabaoResults'] as List<dynamic>? ?? [];
    for (final r in savedCarabao) {
      try {
        _recentCarabaoResults.add(MatchResult.fromMap(Map<String, dynamic>.from(r as Map)));
      } catch (_) {}
    }
    _recentCarabaoResults.sort((a, b) {
      final aUser = a.homeClub == _userClub || a.awayClub == _userClub;
      final bUser = b.homeClub == _userClub || b.awayClub == _userClub;
      if (aUser && !bUser) return -1;
      if (!aUser && bUser) return 1;
      return 0;
    });

    // Restore Season Results Archive (Issue #12)
    _seasonResultsArchive.clear();
    final savedArchive = saved['seasonResults'] as Map<dynamic, dynamic>? ?? {};
    savedArchive.forEach((gwKey, matches) {
      final gwInt = int.tryParse(gwKey.toString());
      if (gwInt != null && matches is List) {
        final list = <MatchResult>[];
        for (final m in matches) {
          try {
            list.add(MatchResult.fromMap(Map<String, dynamic>.from(m as Map)));
          } catch (_) {}
        }
        _seasonResultsArchive[gwInt] = list;
      }
    });

    // Restore League Table state (Issue #10)
    _leagueTable.clear();
    final savedTable = saved['leagueTable'] as List<dynamic>? ?? [];
    if (savedTable.isNotEmpty) {
      for (final item in savedTable) {
        try {
          _leagueTable.add(TableEntry.fromMap(Map<String, dynamic>.from(item as Map)));
        } catch (_) {}
      }
      _leagueTable.sort((a, b) {
        if (b.points != a.points) return b.points.compareTo(a.points);
        if (b.goalDifference != a.goalDifference) return b.goalDifference.compareTo(a.goalDifference);
        return b.goalsFor.compareTo(a.goalsFor);
      });
    }

    // Ensure all league clubs are present in the table
    for (final club in _leagueClubs) {
      if (!_leagueTable.any((t) => t.clubName == club)) {
        _leagueTable.add(TableEntry(clubName: club));
      }
    }

    // Generate balanced round-robin fixture calendar (Issue #12)
    _seasonSchedule = generateSeasonSchedule(_leagueClubs, totalGameweeks: _totalGameweeks);

    // Restore pending inbound transfer offers (Fix 28 / User Fix 6)
    _pendingTransferOffers.clear();
    final savedOffers = saved['pendingTransferOffers'] as List<dynamic>? ?? [];
    for (final o in savedOffers) {
      try {
        if (o is Map) {
          _pendingTransferOffers.add(TransferOffer.fromMap(Map<String, dynamic>.from(o)));
        }
      } catch (_) {}
    }

    // Restore active squad events (injuries, leave, international duty) (Fix 29 / User Fix 7)
    _activeSquadEvents.clear();
    final savedEvents = saved['activeSquadEvents'] as List<dynamic>? ?? [];
    for (final e in savedEvents) {
      try {
        if (e is Map) {
          _activeSquadEvents.add(SquadEvent.fromMap(Map<String, dynamic>.from(e)));
        }
      } catch (_) {}
    }

    // Restore player contract season counters (Fix 30 / User Fix 8)
    _playerContracts.clear();
    final savedContracts = saved['playerContracts'] as Map<dynamic, dynamic>? ?? {};
    for (final entry in savedContracts.entries) {
      _playerContracts[entry.key.toString()] = (entry.value as num).toInt();
    }
    for (final p in _userSquad) {
      _playerContracts[p.name] ??= TransferMarketService.computePlayerContract(p.name, _currentSeason).seasonsRemaining.clamp(2, 5);
    }

    // Pre-cache authentic AI club squads for realistic match reports
    await _cacheLeagueClubSquads(db);

    setState(() {
      _isConfigured = true;
      _isLoading = false;
    });
  }

  Future<void> _cacheLeagueClubSquads(Database db) async {
    final allClubsToCache = Set<String>.from(_leagueClubs);
    if (_uclTournament != null) {
      allClubsToCache.addAll(_uclTournament!.participants);
    } else {
      allClubsToCache.addAll(UclTournament.kDefaultUclClubs);
    }

    for (final club in allClubsToCache) {
      if (club == _userClub) continue;
      if (_aiClubPlayers.containsKey(club) && _aiClubPlayers[club]!.isNotEmpty) continue;

      final queryClub = club == 'Inter Milan' ? 'Inter' : (club == 'Paris Saint-Germain' ? 'Paris' : club);
      final rows = await db.rawQuery('''
        SELECT player_name, primary_position, overall
        FROM players
        WHERE team_name LIKE ?
        ORDER BY overall DESC, season DESC
      ''', ['%$queryClub%']);

      final seenNames = <String>{};
      final distinctRows = <Map<String, dynamic>>[];
      for (final r in rows) {
        final name = (r['player_name'] as String).trim().toLowerCase();
        if (seenNames.add(name)) {
          distinctRows.add(r);
          if (distinctRows.length == 25) break;
        }
      }

      if (distinctRows.isNotEmpty) {
        final rawSimPlayers = distinctRows.map((r) => SimPlayer(
          name: r['player_name'] as String,
          position: r['primary_position'] as String? ?? 'CM',
          overall: (r['overall'] as num?)?.toInt() ?? 78,
          isStarter: false,
        )).toList();

        final tacticalAiSquad = SimEngine.normalizeSquadRoles(rawSimPlayers);
        _aiClubSquads[club] = tacticalAiSquad.map((p) => p.name).toList();
        _aiClubPlayers[club] = tacticalAiSquad;
      } else {
        final fallback = [
          SimPlayer(name: '$club Goalkeeper', position: 'GK', overall: 81, isStarter: true),
          SimPlayer(name: '$club Left Back', position: 'LB', overall: 78, isStarter: true),
          SimPlayer(name: '$club Center Back 1', position: 'CB', overall: 80, isStarter: true),
          SimPlayer(name: '$club Center Back 2', position: 'CB', overall: 79, isStarter: true),
          SimPlayer(name: '$club Right Back', position: 'RB', overall: 78, isStarter: true),
          SimPlayer(name: '$club Holding Mid', position: 'CDM', overall: 78, isStarter: true),
          SimPlayer(name: '$club Central Mid', position: 'CM', overall: 79, isStarter: true),
          SimPlayer(name: '$club Playmaker', position: 'CAM', overall: 80, isStarter: true),
          SimPlayer(name: '$club Left Wing', position: 'LW', overall: 80, isStarter: true),
          SimPlayer(name: '$club Right Wing', position: 'RW', overall: 80, isStarter: true),
          SimPlayer(name: '$club Striker', position: 'ST', overall: 81, isStarter: true),
          // Bench
          SimPlayer(name: '$club Sub GK', position: 'GK', overall: 74, isStarter: false),
          SimPlayer(name: '$club Sub DEF', position: 'CB', overall: 75, isStarter: false),
          SimPlayer(name: '$club Sub MID', position: 'CM', overall: 75, isStarter: false),
          SimPlayer(name: '$club Sub FWD', position: 'ST', overall: 76, isStarter: false),
        ];
        _aiClubSquads[club] = fallback.map((p) => p.name).toList();
        _aiClubPlayers[club] = fallback;
      }
    }
  }

  /// Tactically sorts squad so:
  /// - Index 0 is strictly the 1st Goalkeeper (Starting GK)
  /// - Indices 1..10 are 10 Outfield Starters (4 DEF, 4 MID, 2 FWD)
  /// - Index 11 is strictly the 2nd Goalkeeper (Bench GK)
  /// - Indices 12..17 are Outfield Reserves (Fix 25 / User Fix 3)
  List<Player> _sortSquadTactically(List<Player> squad) {
    if (squad.isEmpty) return squad;

    final gks = squad.where((p) => p.isGoalkeeper || p.primaryPosition == 'GK').toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    final defs = squad.where((p) => !p.isGoalkeeper && const ['CB', 'LB', 'RB', 'LWB', 'RWB'].contains(p.primaryPosition)).toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    final mids = squad.where((p) => !p.isGoalkeeper && const ['CM', 'CAM', 'CDM', 'LM', 'RM'].contains(p.primaryPosition)).toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    final fwds = squad.where((p) => !p.isGoalkeeper && const ['ST', 'CF', 'LW', 'RW'].contains(p.primaryPosition)).toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    final otherOutfield = squad.where((p) => !p.isGoalkeeper && p.primaryPosition != 'GK' &&
        !const ['CB', 'LB', 'RB', 'LWB', 'RWB', 'CM', 'CAM', 'CDM', 'LM', 'RM', 'ST', 'CF', 'LW', 'RW'].contains(p.primaryPosition)).toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));

    // Starters (11 players)
    final starterGk = gks.isNotEmpty ? [gks.first] : <Player>[];
    final starterDefs = defs.take(4).toList();
    final remainingDefs = defs.skip(4).toList();

    final starterMids = mids.take(4).toList();
    final remainingMids = mids.skip(4).toList();

    final starterFwds = fwds.take(2).toList();
    final remainingFwds = fwds.skip(2).toList();

    final starters = <Player>[
      ...starterGk,
      ...starterDefs,
      ...starterMids,
      ...starterFwds,
    ];

    // Outfield pool for filling any incomplete positions
    final poolOutfield = [
      ...remainingDefs,
      ...remainingMids,
      ...remainingFwds,
      ...otherOutfield,
    ]..sort((a, b) => b.overall.compareTo(a.overall));

    while (starters.length < 11 && poolOutfield.isNotEmpty) {
      starters.add(poolOutfield.removeAt(0));
    }

    // Bench (indices 11 to 17):
    // Reserve GK at index 11
    final benchGk = gks.length > 1 ? [gks[1]] : <Player>[];
    final extraGks = gks.length > 2 ? gks.skip(2).toList() : <Player>[];

    final bench = <Player>[
      ...benchGk,
      ...poolOutfield,
      ...extraGks,
    ];

    return [...starters, ...bench];
  }

  Future<List<Player>> _loadRealSquad(Database db, String clubName) async {
    final queryClub = clubName == 'Inter Milan' ? 'Inter' : clubName;

    // 1. Determine latest era for this club in the database
    final seasonResult = await db.rawQuery(
      'SELECT MAX(season) as max_s FROM players WHERE team_name LIKE ?',
      ['%$queryClub%'],
    );
    final int maxSeason = (seasonResult.first['max_s'] as num?)?.toInt() ?? 2026;
    final int minSeason = maxSeason - 3; // Modern era window

    final List<Player> squad = [];
    final Set<String> usedNames = {};

    Future<int> pickPositions({
      required String positionCondition,
      required int count,
    }) async {
      // Step A: Target modern era players
      var rows = await db.rawQuery('''
        SELECT *
        FROM players
        WHERE team_name LIKE ? AND season >= ? AND ($positionCondition)
        ORDER BY overall DESC, season DESC
      ''', ['%$queryClub%', minSeason]);

      // Step B: Fall back to all club records if position needs more depth
      if (rows.length < count) {
        rows = await db.rawQuery('''
          SELECT *
          FROM players
          WHERE team_name LIKE ? AND ($positionCondition)
          ORDER BY overall DESC, season DESC
        ''', ['%$queryClub%']);
      }

      int picked = 0;
      for (final r in rows) {
        final p = Player.fromMap(r);
        final normName = p.name.trim().toLowerCase();
        if (!usedNames.contains(normName)) {
          usedNames.add(normName);
          squad.add(p);
          picked++;
          if (picked == count) break;
        }
      }
      return picked;
    }

    // 2 Goalkeepers
    await pickPositions(positionCondition: "primary_position = 'GK'", count: 2);
    // 6 Defenders
    await pickPositions(
      positionCondition: "primary_position IN ('CB', 'LB', 'RB', 'LWB', 'RWB')",
      count: 6,
    );
    // 6 Midfielders
    await pickPositions(
      positionCondition: "primary_position IN ('CM', 'CAM', 'CDM', 'LM', 'RM')",
      count: 6,
    );
    // 4 Forwards
    await pickPositions(
      positionCondition: "primary_position IN ('ST', 'CF', 'LW', 'RW')",
      count: 4,
    );

    // Fallback: If still under 18 players, fill remaining spots with highest rated remaining club players
    if (squad.length < 18) {
      final extraRows = await db.rawQuery('''
        SELECT *
        FROM players
        WHERE team_name LIKE ?
        ORDER BY overall DESC, season DESC
      ''', ['%$queryClub%']);

      for (final r in extraRows) {
        final p = Player.fromMap(r);
        final normName = p.name.trim().toLowerCase();
        if (!usedNames.contains(normName)) {
          usedNames.add(normName);
          squad.add(p);
          if (squad.length == 18) break;
        }
      }
    }

    return squad;
  }

  Future<List<Player>> _generateRandomSquad(Database db) async {
    final List<Player> squad = [];
    final Set<String> usedNames = {};

    Future<void> pick({
      required String positionCondition,
      required int minOvr,
      required int maxOvr,
      required int count,
    }) async {
      // Prioritize modern active players (season >= 2022)
      var rows = await db.rawQuery('''
        SELECT *
        FROM players
        WHERE season >= 2022 AND ($positionCondition) AND overall BETWEEN ? AND ?
        ORDER BY overall DESC, season DESC
      ''', [minOvr, maxOvr]);

      // Fallback to all eras if needed
      if (rows.length < count) {
        rows = await db.rawQuery('''
          SELECT *
          FROM players
          WHERE ($positionCondition) AND overall BETWEEN ? AND ?
          ORDER BY overall DESC, season DESC
        ''', [minOvr - 4, maxOvr + 4]);
      }

      final pool = <Player>[];
      final seenCands = <String>{};
      for (final r in rows) {
        final p = Player.fromMap(r);
        final normName = p.name.trim().toLowerCase();
        if (seenCands.add(normName) && !usedNames.contains(normName)) {
          pool.add(p);
        }
      }
      pool.shuffle();

      int picked = 0;
      for (final p in pool) {
        final normName = p.name.trim().toLowerCase();
        usedNames.add(normName);
        squad.add(p);
        picked++;
        if (picked == count) break;
      }
    }

    // 2 Goalkeepers: 1 starter (80-87), 1 backup (74-80)
    await pick(positionCondition: "primary_position = 'GK'", minOvr: 80, maxOvr: 87, count: 1);
    await pick(positionCondition: "primary_position = 'GK'", minOvr: 74, maxOvr: 80, count: 1);

    // 6 Defenders: 2 stars (81-88), 4 solid starters (75-81)
    await pick(positionCondition: "primary_position IN ('CB', 'LB', 'RB', 'LWB', 'RWB')", minOvr: 81, maxOvr: 88, count: 2);
    await pick(positionCondition: "primary_position IN ('CB', 'LB', 'RB', 'LWB', 'RWB')", minOvr: 75, maxOvr: 81, count: 4);

    // 6 Midfielders: 2 stars (81-88), 4 solid starters (75-81)
    await pick(positionCondition: "primary_position IN ('CM', 'CAM', 'CDM', 'LM', 'RM')", minOvr: 81, maxOvr: 88, count: 2);
    await pick(positionCondition: "primary_position IN ('CM', 'CAM', 'CDM', 'LM', 'RM')", minOvr: 75, maxOvr: 81, count: 4);

    // 4 Forwards: 1 star (82-89), 3 solid attackers (75-82)
    await pick(positionCondition: "primary_position IN ('ST', 'CF', 'LW', 'RW')", minOvr: 82, maxOvr: 89, count: 1);
    await pick(positionCondition: "primary_position IN ('ST', 'CF', 'LW', 'RW')", minOvr: 75, maxOvr: 82, count: 3);

    return squad;
  }

  /// Generates or re-rolls an 18-player random draft squad for preview in setup wizard (Issue #13)
  Future<void> _generateDraftSquad() async {
    setState(() => _isDrafting = true);
    final db = await DatabaseService.instance.database;
    final squad = await _generateRandomSquad(db);
    if (!mounted) return;
    setState(() {
      _draftedRandomSquad = _sortSquadTactically(squad);
      _draftSwapsRemaining = 3;
      _isDrafting = false;
    });
  }

  /// Swaps a drafted player with a random 80+ rated modern star in the same position group (Issue #13)
  Future<void> _swapDraftPlayer(int index) async {
    if (_draftSwapsRemaining <= 0) return;
    if (index < 0 || index >= _draftedRandomSquad.length) return;

    final oldPlayer = _draftedRandomSquad[index];
    final db = await DatabaseService.instance.database;

    String posCond;
    if (oldPlayer.primaryPosition == 'GK') {
      posCond = "primary_position = 'GK'";
    } else if (const ['CB', 'LB', 'RB', 'LWB', 'RWB'].contains(oldPlayer.primaryPosition)) {
      posCond = "primary_position IN ('CB', 'LB', 'RB', 'LWB', 'RWB')";
    } else if (const ['CM', 'CAM', 'CDM', 'LM', 'RM'].contains(oldPlayer.primaryPosition)) {
      posCond = "primary_position IN ('CM', 'CAM', 'CDM', 'LM', 'RM')";
    } else {
      posCond = "primary_position IN ('ST', 'CF', 'LW', 'RW')";
    }

    final existingNames = _draftedRandomSquad.map((p) => p.name.trim().toLowerCase()).toSet();

    // Query random 80+ players in this position group (modern era first)
    var rows = await db.rawQuery('''
      SELECT *
      FROM players
      WHERE overall >= 80 AND season >= 2022 AND ($posCond)
      ORDER BY overall DESC, season DESC
    ''');

    if (rows.isEmpty) {
      rows = await db.rawQuery('''
        SELECT *
        FROM players
        WHERE overall >= 80 AND ($posCond)
        ORDER BY overall DESC, season DESC
      ''');
    }

    final pool = <Player>[];
    final seenCands = <String>{};
    for (final r in rows) {
      final cand = Player.fromMap(r);
      final norm = cand.name.trim().toLowerCase();
      if (seenCands.add(norm) && !existingNames.contains(norm)) {
        pool.add(cand);
      }
    }
    pool.shuffle();
    final Player? replacement = pool.isNotEmpty ? pool.first : null;

    if (replacement != null && mounted) {
      SoundService.instance.playCorrect();
      setState(() {
        _draftedRandomSquad[index] = replacement;
        _draftedRandomSquad = _sortSquadTactically(_draftedRandomSquad);
        _draftSwapsRemaining--;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.gold,
          content: Text(
            'Star Swap: ${oldPlayer.name} (${oldPlayer.overall}) ➔ ${replacement.name} (${replacement.overall} OVR)! ($_draftSwapsRemaining swaps remaining)',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ),
      );
    }
  }

  Future<void> _launchCareer() async {
    setState(() => _isLoading = true);

    final league = kAvailableLeagues.firstWhere((l) => l.id == _setupLeagueId);
    String clubName;
    String clubCode;

    if (_setupIsCustom) {
      clubName = _customClubNameController.text.trim().isEmpty
          ? 'Custom FC'
          : _customClubNameController.text.trim();
      clubCode = _customClubCodeController.text.trim().isEmpty
          ? clubName.substring(0, min(3, clubName.length)).toUpperCase()
          : _customClubCodeController.text.trim().toUpperCase();
    } else {
      clubName = _setupSelectedRealClub;
      clubCode = league.clubCodes[clubName] ?? clubName.substring(0, min(3, clubName.length)).toUpperCase();
    }

    _leagueClubs = List<String>.from(league.clubs);
    if (_setupIsCustom) {
      final replaceIdx = _leagueClubs.indexOf(_setupReplacedClub);
      if (replaceIdx != -1) {
        _leagueClubs[replaceIdx] = clubName;
      } else {
        _leagueClubs.removeLast();
        _leagueClubs.add(clubName);
      }
    }

    final db = await DatabaseService.instance.database;
    if (_setupSquadMode == 'random') {
      if (_draftedRandomSquad.length >= 11) {
        _userSquad = List<Player>.from(_draftedRandomSquad);
      } else {
        _userSquad = await _generateRandomSquad(db);
      }
      _draftedRandomSquad.clear();
      _draftSwapsRemaining = 3;
    } else {
      final baseClub = _setupIsCustom ? _setupReplacedClub : clubName;
      _userSquad = await _loadRealSquad(db, baseClub);
      if (_userSquad.length < 11) {
        _userSquad = await _generateRandomSquad(db);
      }
    }
    _userSquad = _sortSquadTactically(_userSquad);

    _leagueId = _setupLeagueId;
    _userClub = clubName;
    _userClubCode = clubCode;
    _isCustomClub = _setupIsCustom;
    _squadMode = _setupSquadMode;
    _budgetMillions = _setupIsCustom
        ? getClubStartingBudget(_setupReplacedClub)
        : getClubStartingBudget(clubName);
    _currentSeason = 1;
    _currentGameweek = 1;
    _totalGameweeks = _setupTotalGameweeks;
    _winterBudgetAwarded = false;
    _careerPrizeMoneyEarned = 0.0;
    _formationId = '4-3-3';
    _customFormationSlots.clear();
    _uclTournament = UclTournament.create(userClub: clubName);

    // Initialize Domestic Cups (Fix 26 / User Fix 4)
    final cupPool = List<String>.from(_leagueClubs);
    for (final c in CupTournament.kDefaultEnglishCupClubs) {
      if (!cupPool.contains(c)) cupPool.add(c);
    }
    _faCupTournament = CupTournament.create(id: 'fa_cup', userClub: clubName, poolClubs: cupPool);
    _carabaoCupTournament = CupTournament.create(id: 'carabao_cup', userClub: clubName, poolClubs: cupPool);
    _recentResults.clear();
    _recentUclResults.clear();
    _recentFaCupResults.clear();
    _recentCarabaoResults.clear();
    _pendingTransferOffers.clear();
    _activeSquadEvents.clear();
    _playerContracts.clear();
    for (final p in _userSquad) {
      _playerContracts[p.name] = TransferMarketService.computePlayerContract(p.name, _currentSeason).seasonsRemaining.clamp(2, 5);
    }
    _playerAppearances.clear();
    _playerGoals.clear();
    _playerAssists.clear();
    _playerCleanSheets.clear();
    _playerRatingsTotal.clear();
    _playerRatingsCount.clear();
    _leaguePlayerGoals.clear();
    _leaguePlayerClubs.clear();
    _leaguePlayerAssists.clear();
    _leagueAssistClubs.clear();
    _leagueClubCleanSheets.clear();
    _leagueClubRatingTotals.clear();
    _leagueClubRatingCounts.clear();
    _teamStatsSortIndex = 0;
    _standingsTab = 0;
    _uclViewTab = 0;

    _leagueTable.clear();
    for (final club in _leagueClubs) {
      _leagueTable.add(TableEntry(clubName: club));
    }

    _seasonSchedule = generateSeasonSchedule(_leagueClubs, totalGameweeks: _totalGameweeks);

    await _cacheLeagueClubSquads(db);

    await _persistCareerState();

    setState(() {
      _isConfigured = true;
      _isLoading = false;
    });
  }

  void _promptNewCampaign() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Setup Wizard / New Career', style: AppTypography.titleMedium(Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'Switch to the Career Setup Wizard? Your current $_userClub campaign (Season $_currentSeason, GW $_currentGameweek) will remain safely saved and can be resumed at any time.',
          style: AppTypography.bodySmall(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.gold),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isConfigured = false;
              });
            },
            child: const Text('Setup Wizard', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _simMatchday() async {
    if (_currentGameweek > _totalGameweeks) {
      _advanceSeason();
      return;
    }
    SoundService.instance.playWhistle();

    if (_seasonSchedule.isEmpty || _seasonSchedule.length < _totalGameweeks) {
      _seasonSchedule = generateSeasonSchedule(_leagueClubs, totalGameweeks: _totalGameweeks);
    }

    final roundFixtures = _seasonSchedule[_currentGameweek - 1];
    final resultsThisWeek = <MatchResult>[];

    // Auto-replace any unavailable starters before matchday simulation (Fix 29 / User Fix 7)
    final autoReplacedSquad = SquadEventService.autoReplaceUnavailableStarters(
      squad: _userSquad,
      activeEvents: _activeSquadEvents,
    );
    bool startersChanged = false;
    for (int i = 0; i < min(11, _userSquad.length); i++) {
      if (_userSquad[i].name != autoReplacedSquad[i].name) {
        startersChanged = true;
        break;
      }
    }
    if (startersChanged) {
      _userSquad = autoReplacedSquad;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 3),
            backgroundColor: Color(0xFF3E2723),
            content: Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: Colors.orangeAccent, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Squad Rotation: Unavailable starters replaced with bench players.',
                    style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // Compute user club avg rating
    double userAvg = 82.0;
    if (_userSquad.isNotEmpty) {
      final top11 = _userSquad.take(11);
      userAvg = top11.map((p) => p.overall).reduce((a, b) => a + b) / 11.0;
    }

    final userSimPlayers = _userSquad.asMap().entries.map((entry) {
      final idx = entry.key;
      final p = entry.value;
      return SimPlayer(
        name: p.name,
        position: p.primaryPosition,
        overall: p.overall,
        isStarter: idx < 11,
      );
    }).toList();

    // Simulate deterministic round fixtures
    for (final fixture in roundFixtures) {
      final home = fixture.homeClub;
      final away = fixture.awayClub;

      final homeRating = (home == _userClub) ? userAvg : (79.0 + (Random().nextDouble() * 6.0));
      final awayRating = (away == _userClub) ? userAvg : (78.0 + (Random().nextDouble() * 6.0));

      final homeSquad = home == _userClub
          ? _userSquad.take(11).map((p) => p.name).toList()
          : (_aiClubSquads[home] ?? const <String>[]);
      final awaySquad = away == _userClub
          ? _userSquad.take(11).map((p) => p.name).toList()
          : (_aiClubSquads[away] ?? const <String>[]);

      final homePlayers = home == _userClub ? userSimPlayers : (_aiClubPlayers[home] ?? const <SimPlayer>[]);
      final awayPlayers = away == _userClub ? userSimPlayers : (_aiClubPlayers[away] ?? const <SimPlayer>[]);

      final res = _sim.simulateMatch(
        homeClub: home,
        homeRating: homeRating,
        awayClub: away,
        awayRating: awayRating,
        homeSquad: homeSquad,
        awaySquad: awaySquad,
        homePlayers: homePlayers,
        awayPlayers: awayPlayers,
      );

      resultsThisWeek.add(res);

      // Track league-wide club average match ratings across season (Issue #7 & Fix 22)
      if (res.homePlayerRatings.isNotEmpty) {
        final homeAvg = res.homePlayerRatings.values.reduce((a, b) => a + b) / res.homePlayerRatings.length;
        _leagueClubRatingTotals[home] = (_leagueClubRatingTotals[home] ?? 0.0) + homeAvg;
        _leagueClubRatingCounts[home] = (_leagueClubRatingCounts[home] ?? 0) + 1;
      }
      if (res.awayPlayerRatings.isNotEmpty) {
        final awayAvg = res.awayPlayerRatings.values.reduce((a, b) => a + b) / res.awayPlayerRatings.length;
        _leagueClubRatingTotals[away] = (_leagueClubRatingTotals[away] ?? 0.0) + awayAvg;
        _leagueClubRatingCounts[away] = (_leagueClubRatingCounts[away] ?? 0) + 1;
      }

      // Update table
      final homeEntry = _leagueTable.firstWhere((t) => t.clubName == home);
      final awayEntry = _leagueTable.firstWhere((t) => t.clubName == away);

      homeEntry.recordResult(scored: res.homeGoals, conceded: res.awayGoals);
      awayEntry.recordResult(scored: res.awayGoals, conceded: res.homeGoals);
    }

    // Ensure User Club match is placed at index 0 (Fix 23 / User Fix 1)
    resultsThisWeek.sort((a, b) {
      final aUser = a.homeClub == _userClub || a.awayClub == _userClub;
      final bUser = b.homeClub == _userClub || b.awayClub == _userClub;
      if (aUser && !bUser) return -1;
      if (!aUser && bUser) return 1;
      return 0;
    });

    // Track league-wide goal events, assists & clean sheets (Issue #7 & #8)
    for (final m in resultsThisWeek) {
      for (final g in m.homeGoalEvents) {
        _leaguePlayerGoals[g.scorerName] = (_leaguePlayerGoals[g.scorerName] ?? 0) + 1;
        _leaguePlayerClubs[g.scorerName] = m.homeClub;
        if (g.assisterName != null && g.assisterName!.isNotEmpty) {
          _leaguePlayerAssists[g.assisterName!] = (_leaguePlayerAssists[g.assisterName!] ?? 0) + 1;
          _leagueAssistClubs[g.assisterName!] = m.homeClub;
        }
      }
      for (final g in m.awayGoalEvents) {
        _leaguePlayerGoals[g.scorerName] = (_leaguePlayerGoals[g.scorerName] ?? 0) + 1;
        _leaguePlayerClubs[g.scorerName] = m.awayClub;
        if (g.assisterName != null && g.assisterName!.isNotEmpty) {
          _leaguePlayerAssists[g.assisterName!] = (_leaguePlayerAssists[g.assisterName!] ?? 0) + 1;
          _leagueAssistClubs[g.assisterName!] = m.awayClub;
        }
      }
      if (m.awayGoals == 0) {
        _leagueClubCleanSheets[m.homeClub] = (_leagueClubCleanSheets[m.homeClub] ?? 0) + 1;
      }
      if (m.homeGoals == 0) {
        _leagueClubCleanSheets[m.awayClub] = (_leagueClubCleanSheets[m.awayClub] ?? 0) + 1;
      }
    }

    // Track player appearances for active 11
    if (_userSquad.isNotEmpty) {
      for (final p in _userSquad.take(11)) {
        _playerAppearances[p.name] = (_playerAppearances[p.name] ?? 0) + 1;
      }
    }

    // Track goals & assists scored by user squad players in user match
    final userMatch = resultsThisWeek.firstWhere(
      (m) => m.homeClub == _userClub || m.awayClub == _userClub,
      orElse: () => resultsThisWeek.first,
    );
    final isHome = userMatch.homeClub == _userClub;
    final userGoalEvents = isHome ? userMatch.homeGoalEvents : userMatch.awayGoalEvents;
    for (final event in userGoalEvents) {
      _playerGoals[event.scorerName] = (_playerGoals[event.scorerName] ?? 0) + 1;
      if (event.assisterName != null && event.assisterName!.isNotEmpty) {
        _playerAssists[event.assisterName!] = (_playerAssists[event.assisterName!] ?? 0) + 1;
      }
    }

    // Track user player match ratings
    final userRatings = isHome ? userMatch.homePlayerRatings : userMatch.awayPlayerRatings;
    userRatings.forEach((playerName, rating) {
      _playerRatingsTotal[playerName] = (_playerRatingsTotal[playerName] ?? 0.0) + rating;
      _playerRatingsCount[playerName] = (_playerRatingsCount[playerName] ?? 0) + 1;
    });

    // Track clean sheets for starting GK and DEF if user conceded 0 goals
    final userConceded = isHome ? userMatch.awayGoals : userMatch.homeGoals;
    if (userConceded == 0 && _userSquad.isNotEmpty) {
      for (final p in _userSquad.take(11)) {
        if (p.primaryPosition == 'GK' || const ['CB', 'LB', 'RB', 'LWB', 'RWB'].contains(p.primaryPosition)) {
          _playerCleanSheets[p.name] = (_playerCleanSheets[p.name] ?? 0) + 1;
        }
      }
    }

    // Midweek UEFA Champions League Simulation (Issue #3 & Fix 24)
    final uclMd = UclTournament.getUclMatchdayForLeagueGw(_currentGameweek, totalGameweeks: _totalGameweeks);
    if (uclMd != null && _uclTournament != null) {
      _recentUclResults.clear();
      final pendingFixtures = <UclFixture>[];
      if (uclMd <= 6) {
        pendingFixtures.addAll(_uclTournament!.groupFixtures.where((f) => f.matchday == uclMd && !f.isPlayed));
      } else if (uclMd == 7) {
        _uclTournament!.checkAndAdvanceStages();
        pendingFixtures.addAll(_uclTournament!.quarterFinals.map((t) => t.leg1).where((f) => !f.isPlayed));
      } else if (uclMd == 8) {
        pendingFixtures.addAll(_uclTournament!.quarterFinals.map((t) => t.leg2!).where((f) => !f.isPlayed));
      } else if (uclMd == 9) {
        _uclTournament!.checkAndAdvanceStages();
        pendingFixtures.addAll(_uclTournament!.semiFinals.map((t) => t.leg1).where((f) => !f.isPlayed));
      } else if (uclMd == 10) {
        pendingFixtures.addAll(_uclTournament!.semiFinals.map((t) => t.leg2!).where((f) => !f.isPlayed));
      } else if (uclMd == 11) {
        _uclTournament!.checkAndAdvanceStages();
        if (_uclTournament!.finalTie != null && !_uclTournament!.finalTie!.leg1.isPlayed) {
          pendingFixtures.add(_uclTournament!.finalTie!.leg1);
        }
      }

      for (final uFix in pendingFixtures) {
        final uHome = uFix.homeClub;
        final uAway = uFix.awayClub;
        final uHomeRating = (uHome == _userClub) ? userAvg : (82.0 + (Random().nextDouble() * 5.0));
        final uAwayRating = (uAway == _userClub) ? userAvg : (82.0 + (Random().nextDouble() * 5.0));
        final uHomeSquad = uHome == _userClub ? _userSquad.take(11).map((p) => p.name).toList() : (_aiClubSquads[uHome] ?? const <String>[]);
        final uAwaySquad = uAway == _userClub ? _userSquad.take(11).map((p) => p.name).toList() : (_aiClubSquads[uAway] ?? const <String>[]);
        final uHomePlayers = uHome == _userClub ? userSimPlayers : (_aiClubPlayers[uHome] ?? const <SimPlayer>[]);
        final uAwayPlayers = uAway == _userClub ? userSimPlayers : (_aiClubPlayers[uAway] ?? const <SimPlayer>[]);

        final uRes = _sim.simulateMatch(
          homeClub: uHome,
          homeRating: uHomeRating,
          awayClub: uAway,
          awayRating: uAwayRating,
          homeSquad: uHomeSquad,
          awaySquad: uAwaySquad,
          homePlayers: uHomePlayers,
          awayPlayers: uAwayPlayers,
        );

        _uclTournament!.recordFixtureResult(uFix, uRes);
        _recentUclResults.add(uRes);
      }

      // Ensure User Club UCL match is placed at index 0 in _recentUclResults (Fix 23 / User Fix 1)
      _recentUclResults.sort((a, b) {
        final aUser = a.homeClub == _userClub || a.awayClub == _userClub;
        final bUser = b.homeClub == _userClub || b.awayClub == _userClub;
        if (aUser && !bUser) return -1;
        if (!aUser && bUser) return 1;
        return 0;
      });
    } else {
      _recentUclResults.clear();
    }

    // Carabao Cup Simulation (Fix 26 / User Fix 4)
    final carabaoRd = CupTournament.getCarabaoRoundForLeagueGw(_currentGameweek, totalGameweeks: _totalGameweeks);
    if (carabaoRd != null && _carabaoCupTournament != null) {
      _recentCarabaoResults.clear();
      final cResults = _carabaoCupTournament!.simulateRound(
        carabaoRd,
        simEngine: _sim,
        clubPlayers: _aiClubPlayers,
        totalGameweeks: _totalGameweeks,
      );
      _recentCarabaoResults.addAll(cResults);
      _recentCarabaoResults.sort((a, b) {
        final aUser = a.homeClub == _userClub || a.awayClub == _userClub;
        final bUser = b.homeClub == _userClub || b.awayClub == _userClub;
        if (aUser && !bUser) return -1;
        if (!aUser && bUser) return 1;
        return 0;
      });

      // Track user player appearances and stats for Carabao Cup
      final userCarabaoMatch = _recentCarabaoResults.where((m) => m.homeClub == _userClub || m.awayClub == _userClub).firstOrNull;
      if (userCarabaoMatch != null) {
        final isHomeC = userCarabaoMatch.homeClub == _userClub;
        final cUserGoals = isHomeC ? userCarabaoMatch.homeGoalEvents : userCarabaoMatch.awayGoalEvents;
        for (final ev in cUserGoals) {
          _playerGoals[ev.scorerName] = (_playerGoals[ev.scorerName] ?? 0) + 1;
          if (ev.assisterName != null && ev.assisterName!.isNotEmpty) {
            _playerAssists[ev.assisterName!] = (_playerAssists[ev.assisterName!] ?? 0) + 1;
          }
        }
        final cRatings = isHomeC ? userCarabaoMatch.homePlayerRatings : userCarabaoMatch.awayPlayerRatings;
        cRatings.forEach((pName, rating) {
          _playerRatingsTotal[pName] = (_playerRatingsTotal[pName] ?? 0.0) + rating;
          _playerRatingsCount[pName] = (_playerRatingsCount[pName] ?? 0) + 1;
        });
        final cConceded = isHomeC ? userCarabaoMatch.awayGoals : userCarabaoMatch.homeGoals;
        if (cConceded == 0 && _userSquad.isNotEmpty) {
          for (final p in _userSquad.take(11)) {
            if (p.primaryPosition == 'GK' || const ['CB', 'LB', 'RB', 'LWB', 'RWB'].contains(p.primaryPosition)) {
              _playerCleanSheets[p.name] = (_playerCleanSheets[p.name] ?? 0) + 1;
            }
          }
        }
      }
    } else {
      _recentCarabaoResults.clear();
    }

    // FA Cup Simulation (Fix 26 / User Fix 4)
    final faRd = CupTournament.getFaCupRoundForLeagueGw(_currentGameweek, totalGameweeks: _totalGameweeks);
    if (faRd != null && _faCupTournament != null) {
      _recentFaCupResults.clear();
      final fResults = _faCupTournament!.simulateRound(
        faRd,
        simEngine: _sim,
        clubPlayers: _aiClubPlayers,
        totalGameweeks: _totalGameweeks,
      );
      _recentFaCupResults.addAll(fResults);
      _recentFaCupResults.sort((a, b) {
        final aUser = a.homeClub == _userClub || a.awayClub == _userClub;
        final bUser = b.homeClub == _userClub || b.awayClub == _userClub;
        if (aUser && !bUser) return -1;
        if (!aUser && bUser) return 1;
        return 0;
      });

      // Track user player appearances and stats for FA Cup
      final userFaMatch = _recentFaCupResults.where((m) => m.homeClub == _userClub || m.awayClub == _userClub).firstOrNull;
      if (userFaMatch != null) {
        final isHomeF = userFaMatch.homeClub == _userClub;
        final fUserGoals = isHomeF ? userFaMatch.homeGoalEvents : userFaMatch.awayGoalEvents;
        for (final ev in fUserGoals) {
          _playerGoals[ev.scorerName] = (_playerGoals[ev.scorerName] ?? 0) + 1;
          if (ev.assisterName != null && ev.assisterName!.isNotEmpty) {
            _playerAssists[ev.assisterName!] = (_playerAssists[ev.assisterName!] ?? 0) + 1;
          }
        }
        final fRatings = isHomeF ? userFaMatch.homePlayerRatings : userFaMatch.awayPlayerRatings;
        fRatings.forEach((pName, rating) {
          _playerRatingsTotal[pName] = (_playerRatingsTotal[pName] ?? 0.0) + rating;
          _playerRatingsCount[pName] = (_playerRatingsCount[pName] ?? 0) + 1;
        });
        final fConceded = isHomeF ? userFaMatch.awayGoals : userFaMatch.homeGoals;
        if (fConceded == 0 && _userSquad.isNotEmpty) {
          for (final p in _userSquad.take(11)) {
            if (p.primaryPosition == 'GK' || const ['CB', 'LB', 'RB', 'LWB', 'RWB'].contains(p.primaryPosition)) {
              _playerCleanSheets[p.name] = (_playerCleanSheets[p.name] ?? 0) + 1;
            }
          }
        }
      }
    } else {
      _recentFaCupResults.clear();
    }

    if (_recentUclResults.isEmpty && _recentFaCupResults.isEmpty && _recentCarabaoResults.isEmpty) {
      _resultsCompTab = 0;
    }

    // Sort table by points then goal difference
    _leagueTable.sort((a, b) {
      if (b.points != a.points) return b.points.compareTo(a.points);
      if (b.goalDifference != a.goalDifference) return b.goalDifference.compareTo(a.goalDifference);
      return b.goalsFor.compareTo(a.goalsFor);
    });

    final nextGw = _currentGameweek + 1;
    final winterStart = _totalGameweeks == 18 ? 10 : 20;
    bool justUnlockedWinter = false;
    if (nextGw == winterStart && !_winterBudgetAwarded) {
      _budgetMillions += 10.0;
      _winterBudgetAwarded = true;
      justUnlockedWinter = true;
    }

    // Performance-based matchday prize money (Issue #12 & Fix 26)
    final userWon = (userMatch.homeClub == _userClub && userMatch.homeGoals > userMatch.awayGoals) ||
        (userMatch.awayClub == _userClub && userMatch.awayGoals > userMatch.homeGoals);
    final userDrew = (userMatch.homeClub == _userClub || userMatch.awayClub == _userClub) &&
        (userMatch.homeGoals == userMatch.awayGoals);

    final userUclMatches = _recentUclResults.where(
      (m) => m.homeClub == _userClub || m.awayClub == _userClub,
    );
    final userUclMatch = userUclMatches.isNotEmpty ? userUclMatches.first : null;
    final userWonUcl = userUclMatch != null &&
        ((userUclMatch.homeClub == _userClub && userUclMatch.homeGoals > userUclMatch.awayGoals) ||
            (userUclMatch.awayClub == _userClub && userUclMatch.awayGoals > userUclMatch.homeGoals));
    final userDrewUcl = userUclMatch != null && (userUclMatch.homeGoals == userUclMatch.awayGoals);

    // Carabao Cup win bonus
    final userCarabaoMatches = _recentCarabaoResults.where((m) => m.homeClub == _userClub || m.awayClub == _userClub);
    final userCarabaoMatch = userCarabaoMatches.isNotEmpty ? userCarabaoMatches.first : null;
    final userWonCarabao = userCarabaoMatch != null &&
        ((userCarabaoMatch.homeClub == _userClub && userCarabaoMatch.homeGoals > userCarabaoMatch.awayGoals) ||
            (userCarabaoMatch.awayClub == _userClub && userCarabaoMatch.awayGoals > userCarabaoMatch.homeGoals));

    // FA Cup win bonus
    final userFaMatches = _recentFaCupResults.where((m) => m.homeClub == _userClub || m.awayClub == _userClub);
    final userFaMatch = userFaMatches.isNotEmpty ? userFaMatches.first : null;
    final userWonFa = userFaMatch != null &&
        ((userFaMatch.homeClub == _userClub && userFaMatch.homeGoals > userFaMatch.awayGoals) ||
            (userFaMatch.awayClub == _userClub && userFaMatch.awayGoals > userFaMatch.homeGoals));

    double matchBonus = 0.0;
    final bonusReasons = <String>[];
    if (userWon) {
      matchBonus += 1.2;
      bonusReasons.add('League Win (+£1.2M)');
    } else if (userDrew) {
      matchBonus += 0.5;
      bonusReasons.add('League Draw (+£0.5M)');
    }

    if (userWonUcl) {
      matchBonus += 2.5;
      bonusReasons.add('UCL Win (+£2.5M)');
    } else if (userDrewUcl) {
      matchBonus += 1.0;
      bonusReasons.add('UCL Draw (+£1.0M)');
    }

    if (userWonCarabao) {
      matchBonus += 1.0;
      bonusReasons.add('Carabao Cup Win (+£1.0M)');
    }

    if (userWonFa) {
      matchBonus += 1.5;
      bonusReasons.add('FA Cup Win (+£1.5M)');
    }

    if (matchBonus > 0) {
      _budgetMillions += matchBonus;
      _careerPrizeMoneyEarned += matchBonus;
    }

    // Evaluate inbound transfer offers if window is open (Fix 28 / User Fix 6)
    final windowState = TransferWindowState.compute(
      gameweek: _currentGameweek,
      totalGameweeks: _totalGameweeks,
    );
    final newInboundBids = TransferOfferService.evaluateMatchdayInboundBids(
      userSquad: _userSquad,
      userClub: _userClub,
      season: _currentSeason,
      gameweek: _currentGameweek,
      isWindowOpen: windowState.isOpen,
      currentPendingOffers: _pendingTransferOffers,
      valuationCalculator: calculatePlayerValuation,
    );

    // Evaluate dynamic squad events (Fix 29 / User Fix 7)
    final squadEventResult = SquadEventService.evaluateMatchdaySquadEvents(
      userSquad: _userSquad,
      currentActiveEvents: _activeSquadEvents,
      season: _currentSeason,
      gameweek: _currentGameweek,
      totalGameweeks: _totalGameweeks,
    );

    setState(() {
      _seasonResultsArchive[_currentGameweek] = List<MatchResult>.from(resultsThisWeek);
      _currentGameweek = nextGw;
      _recentResults.clear();
      _recentResults.addAll(resultsThisWeek);
      _activeSquadEvents.clear();
      _activeSquadEvents.addAll(squadEventResult.activeEvents);
      if (newInboundBids.isNotEmpty) {
        _pendingTransferOffers.addAll(newInboundBids);
      }
    });

    // Persist gameweek, table, player statistics, clean sheets, and league scorers (Issue #7, #8, #11, #12)
    await _persistCareerState();

    // Reward coins for winning
    if (userWon) {
      ref.read(coinsProvider.notifier).add(3, 'Career mode matchday win');
      SoundService.instance.playGoal();
    } else {
      final userGoalsScored = isHome ? userMatch.homeGoals : userMatch.awayGoals;
      if (userGoalsScored > 0) {
        SoundService.instance.playKick();
      }
    }

    if (matchBonus > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF1B2A1E),
          content: Row(
            children: [
              const Icon(Icons.monetization_on, color: AppPalette.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Prize Money: +£${matchBonus.toStringAsFixed(1)}M (${bonusReasons.join(', ')})',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (newInboundBids.isNotEmpty && mounted) {
      final firstBid = newInboundBids.first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          backgroundColor: AppPalette.gold,
          content: Row(
            children: [
              const Icon(Icons.mark_email_unread_rounded, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'INBOUND BID: ${firstBid.buyingClub} offered £${firstBid.offeredFeeMillions.toStringAsFixed(1)}M for ${firstBid.playerName}!',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 12.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'REVIEW',
            textColor: Colors.black,
            backgroundColor: Colors.white,
            onPressed: _openInboundOffersSheet,
          ),
        ),
      );
    }

    // Dynamic squad event toasts: recoveries & new alerts (Fix 29 / User Fix 7)
    if (squadEventResult.recoveredEvents.isNotEmpty && mounted) {
      final names = squadEventResult.recoveredEvents.map((e) => e.playerName).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFF1B5E20),
          content: Row(
            children: [
              const Icon(Icons.health_and_safety_rounded, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'FIT TO PLAY: $names has fully recovered and rejoined the squad!',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (squadEventResult.newEvents.isNotEmpty && mounted) {
      for (final event in squadEventResult.newEvents) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            backgroundColor: event.badgeColor.withValues(alpha: 0.95),
            content: Row(
              children: [
                Icon(event.iconData, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SQUAD ALERT: ${event.playerName} • ${event.title} (${event.remainingGameweeks} GWs)',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (justUnlockedWinter && mounted) {
      _showWinterBudgetDialog();
    }
  }

  Future<void> _persistCareerState() async {
    final statsMap = <String, Map<String, int>>{};
    for (final p in _userSquad) {
      statsMap[p.name] = {
        'apps': _playerAppearances[p.name] ?? 0,
        'goals': _playerGoals[p.name] ?? 0,
        'cleanSheets': _playerCleanSheets[p.name] ?? 0,
      };
    }
    final leagueScorersMap = <String, Map<String, dynamic>>{};
    _leaguePlayerGoals.forEach((player, goals) {
      leagueScorersMap[player] = {
        'club': _leaguePlayerClubs[player] ?? '',
        'goals': goals,
      };
    });

    final tableList = _leagueTable.map((t) => t.toMap()).toList();
    final recentList = _recentResults.map((m) => m.toMap()).toList();
    final recentUclList = _recentUclResults.map((m) => m.toMap()).toList();
    final recentFaList = _recentFaCupResults.map((m) => m.toMap()).toList();
    final recentCarabaoList = _recentCarabaoResults.map((m) => m.toMap()).toList();
    final squadNames = _userSquad.map((p) => p.name).toList();
    final archiveMap = _seasonResultsArchive.map(
      (k, v) => MapEntry(k, v.map((m) => m.toMap()).toList()),
    );

    final ratingsOverride = <String, int>{};
    final agesOverride = <String, int>{};
    for (final p in _userSquad) {
      ratingsOverride[p.name] = p.overall;
      if (p.age != null) {
        agesOverride[p.name] = p.age!.round();
      }
    }

    final pendingOffersList = _pendingTransferOffers.map((o) => o.toMap()).toList();
    final activeEventsList = _activeSquadEvents.map((e) => e.toMap()).toList();

    // 1. Save to SharedPreferences (fast local cache)
    await PrefsService.instance.saveCareerConfig(
      leagueId: _leagueId,
      clubName: _userClub,
      clubCode: _userClubCode,
      isCustomClub: _isCustomClub,
      squadMode: _squadMode,
      budget: _budgetMillions,
      season: _currentSeason,
      gameweek: _currentGameweek,
      totalGameweeks: _totalGameweeks,
      winterBudgetAwarded: _winterBudgetAwarded,
      squadIds: squadNames,
      playerStats: statsMap,
      recentResults: recentList,
      recentUclResults: recentUclList,
      recentFaCupResults: recentFaList,
      recentCarabaoResults: recentCarabaoList,
      leagueScorers: leagueScorersMap,
      leagueTable: tableList,
      seasonResults: archiveMap,
      formationId: _formationId,
      uclTournament: _uclTournament?.toMap(),
      faCupTournament: _faCupTournament?.toMap(),
      carabaoCupTournament: _carabaoCupTournament?.toMap(),
      playerAssists: _playerAssists,
      leagueAssists: _leaguePlayerAssists,
      leagueCleanSheets: _leagueClubCleanSheets,
      prizeMoney: _careerPrizeMoneyEarned,
      leagueClubRatingTotals: _leagueClubRatingTotals,
      leagueClubRatingCounts: _leagueClubRatingCounts,
      playerRatingsOverride: ratingsOverride,
      playerAgesOverride: agesOverride,
      pendingTransferOffers: pendingOffersList,
      activeSquadEvents: activeEventsList,
      playerContracts: _playerContracts,
      customFormationSlots: _customFormationSlots.map(
        (k, v) => MapEntry(k, v.map((s) => s.toJson()).toList()),
      ),
    );

    final statePayload = <String, dynamic>{
      'leagueId': _leagueId,
      'clubName': _userClub,
      'clubCode': _userClubCode,
      'isCustomClub': _isCustomClub,
      'squadMode': _squadMode,
      'budget': _budgetMillions,
      'season': _currentSeason,
      'gameweek': _currentGameweek,
      'totalGameweeks': _totalGameweeks,
      'winterBudgetAwarded': _winterBudgetAwarded,
      'squadIds': squadNames,
      'playerStats': statsMap,
      'recentResults': recentList,
      'recentUclResults': recentUclList,
      'recentFaCupResults': recentFaList,
      'recentCarabaoResults': recentCarabaoList,
      'leagueScorers': leagueScorersMap,
      'leagueTable': tableList,
      'seasonResults': archiveMap,
      'formationId': _formationId,
      'customFormationSlots': _customFormationSlots.map(
        (k, v) => MapEntry(k, v.map((s) => s.toJson()).toList()),
      ),
      'uclTournament': _uclTournament?.toMap(),
      'faCupTournament': _faCupTournament?.toMap(),
      'carabaoCupTournament': _carabaoCupTournament?.toMap(),
      'playerAssists': _playerAssists,
      'playerRatingsTotal': _playerRatingsTotal,
      'playerRatingsCount': _playerRatingsCount,
      'leagueAssists': _leaguePlayerAssists,
      'leagueAssistClubs': _leagueAssistClubs,
      'leagueCleanSheets': _leagueClubCleanSheets,
      'prizeMoney': _careerPrizeMoneyEarned,
      'leagueClubRatingTotals': _leagueClubRatingTotals,
      'leagueClubRatingCounts': _leagueClubRatingCounts,
      'playerRatingsOverride': ratingsOverride,
      'playerAgesOverride': agesOverride,
      'pendingTransferOffers': pendingOffersList,
      'activeSquadEvents': activeEventsList,
      'playerContracts': _playerContracts,
    };

    // 2. Dual-layer persistence: SQLite touchline_save.db career_save table (Issue #10)
    await SaveService.instance.saveCareerState(
      saveId: 'active_career',
      clubCode: _userClubCode,
      season: _currentSeason,
      budget: _budgetMillions,
      state: statePayload,
    );

    _existingSaveData = statePayload;
  }

  void _showWinterBudgetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Row(
          children: [
            const Icon(Icons.ac_unit_rounded, color: Colors.lightBlueAccent, size: 28),
            const SizedBox(width: 10),
            Text(
              'WINTER INJECTION',
              style: AppTypography.titleLarge(Theme.of(ctx).colorScheme.onSurface),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'January Transfer Window is officially OPEN!',
              style: AppTypography.bodyMedium(Theme.of(ctx).colorScheme.onSurface).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'The Board of Directors has approved an emergency transfer injection of +£10.0M to reinforce your squad for the championship run-in.',
              style: AppTypography.bodySmall(Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.lightBlueAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Updated Budget:', style: AppTypography.caption(Theme.of(ctx).colorScheme.onSurface)),
                  Text(
                    '£${_budgetMillions.toStringAsFixed(1)}M',
                    style: AppTypography.statNumber(AppPalette.green, fontSize: 16, weight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.gold),
            onPressed: () {
              Navigator.pop(ctx);
              _openTransferMarket();
            },
            child: const Text('Enter Market', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Automatically picks the highest-rated tactical starting XI (1 GK, 4 DEF, 4 MID, 2 FWD) (Issue #9)
  void _autoPickBestXi() {
    if (_userSquad.length < 11) return;
    SoundService.instance.playCorrect();

    final pool = List<Player>.from(_userSquad);
    final startingXi = <Player>[];

    // 1 GK: Highest rated goalkeeper
    final gks = pool.where((p) => p.primaryPosition == 'GK').toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    if (gks.isNotEmpty) {
      startingXi.add(gks.first);
      pool.remove(gks.first);
    }

    // 4 DEF: Highest rated defenders
    final defs = pool
        .where((p) => const ['CB', 'LB', 'RB', 'LWB', 'RWB'].contains(p.primaryPosition))
        .toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    for (int i = 0; i < min(4, defs.length); i++) {
      startingXi.add(defs[i]);
      pool.remove(defs[i]);
    }

    // 4 MID: Highest rated midfielders
    final mids = pool
        .where((p) => const ['CM', 'CAM', 'CDM', 'LM', 'RM'].contains(p.primaryPosition))
        .toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    for (int i = 0; i < min(4, mids.length); i++) {
      startingXi.add(mids[i]);
      pool.remove(mids[i]);
    }

    // 2 FWD: Highest rated forwards
    final fwds = pool
        .where((p) => const ['ST', 'CF', 'LW', 'RW'].contains(p.primaryPosition))
        .toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    for (int i = 0; i < min(2, fwds.length); i++) {
      startingXi.add(fwds[i]);
      pool.remove(fwds[i]);
    }

    // Backfill if any position group had fewer than needed
    pool.sort((a, b) => b.overall.compareTo(a.overall));
    while (startingXi.length < 11 && pool.isNotEmpty) {
      startingXi.add(pool.removeAt(0));
    }

    // Remaining players are Bench/Reserves sorted descending by overall
    pool.sort((a, b) => b.overall.compareTo(a.overall));

    setState(() {
      _userSquad = [...startingXi, ...pool];
    });

    _persistCareerState();

    final avgOvr = (startingXi.map((p) => p.overall).reduce((a, b) => a + b) / 11.0).toStringAsFixed(1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppPalette.gold,
        content: Text(
          'Tactical Auto-Pick: Optimal XI selected! (Starting XI Avg: $avgOvr OVR)',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
    );
  }

  /// Opens the interactive FIFA-style Formation & Pitch Editor (Issue #4 & Fix 31)
  void _openFormationEditor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FormationEditorSheet(
        squad: _userSquad,
        currentFormationId: _formationId,
        initialCustomSlots: _customFormationSlots[_formationId],
        onSave: (newFormation, newSquad, [customSlots]) {
          setState(() {
            _formationId = newFormation;
            _userSquad = newSquad;
            if (customSlots != null) {
              _customFormationSlots[newFormation] = customSlots;
            }
          });
          _persistCareerState();
        },
      ),
    );
  }

  /// Swaps two players in the squad list, changing starter vs reserve status (Issue #9)
  void _swapPlayers(int indexA, int indexB) {
    if (indexA < 0 || indexA >= _userSquad.length || indexB < 0 || indexB >= _userSquad.length || indexA == indexB) {
      return;
    }
    SoundService.instance.playClick();
    setState(() {
      final temp = _userSquad[indexA];
      _userSquad[indexA] = _userSquad[indexB];
      _userSquad[indexB] = temp;
    });
    _persistCareerState();
  }

  /// Opens bottom sheet allowing manager to swap any player with another squad member (Issue #9)
  void _openSwapSheet(int currentIndex) {
    final selected = _userSquad[currentIndex];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink = theme.colorScheme.onSurface;
    final inkMuted = ink.withValues(alpha: 0.65);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: inkMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.swap_vert_rounded, color: AppPalette.gold, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TACTICAL SUBSTITUTION',
                          style: AppTypography.sectionHeader(AppPalette.gold),
                        ),
                        Text(
                          'Swap ${selected.name} (${selected.primaryPosition} • ${selected.overall} OVR)',
                          style: AppTypography.bodySmall(inkMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Divider(color: theme.dividerColor, height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: _userSquad.length,
                separatorBuilder: (context, index) => index == currentIndex
                    ? const SizedBox.shrink()
                    : Divider(color: theme.dividerColor.withValues(alpha: 0.3), height: 1),
                itemBuilder: (context, index) {
                  if (index == currentIndex) return const SizedBox.shrink();

                  final player = _userSquad[index];
                  final isTargetStarter = index < 11;
                  final isSelectedGk = selected.isGoalkeeper || selected.primaryPosition == 'GK';
                  final isTargetGk = player.isGoalkeeper || player.primaryPosition == 'GK';
                  final targetEvent = SquadEventService.getPlayerEvent(player.name, _activeSquadEvents);
                  final isTargetUnavailable = targetEvent != null;
                  final selectedEvent = SquadEventService.getPlayerEvent(selected.name, _activeSquadEvents);
                  final isSelectedUnavailable = selectedEvent != null;

                  // Cannot place an unavailable player into Starting XI (indices 0..10)
                  final violatesAvailability = (currentIndex < 11 && isTargetUnavailable) || (index < 11 && isSelectedUnavailable);
                  final isGkAllowed = (isSelectedGk && isTargetGk) || (!isSelectedGk && !isTargetGk);
                  final canSwap = isGkAllowed && !violatesAvailability;

                  return InkWell(
                    onTap: () {
                      if (violatesAvailability) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppPalette.coral,
                            content: Text(
                              isTargetUnavailable
                                  ? '${player.name} is unavailable (${targetEvent.title}) and cannot start.'
                                  : '${selected.name} is unavailable (${selectedEvent?.title ?? "Unavailable"}) and cannot start.',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      if (!isGkAllowed) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppPalette.red,
                            content: Text(
                              isSelectedGk
                                  ? 'Goalkeepers can only be swapped with other goalkeepers.'
                                  : 'Outfield players cannot be swapped into the goalkeeper position.',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      _swapPlayers(currentIndex, index);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppPalette.gold,
                          content: Text(
                            'Tactical Swap: ${selected.name} ⇄ ${player.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ),
                      );
                    },
                    child: Opacity(
                      opacity: canSwap ? 1.0 : 0.4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              alignment: Alignment.center,
                              child: Text(
                                isTargetStarter ? '${index + 1}' : 'SUB',
                                style: TextStyle(
                                  fontFamily: AppTypography.bodyFamily,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isTargetStarter ? AppPalette.gold : inkMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PlayerAvatar(name: player.name, size: 32),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          player.name,
                                          style: TextStyle(
                                            fontFamily: AppTypography.fontFamily,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: ink,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      PositionBadge(position: player.primaryPosition),
                                      if (targetEvent != null) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: targetEvent.badgeColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: targetEvent.badgeColor, width: 0.8),
                                          ),
                                          child: Text(
                                            targetEvent.badgeLabel,
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: targetEvent.badgeColor,
                                            ),
                                          ),
                                        ),
                                      ] else if (!isGkAllowed) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppPalette.red.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: AppPalette.red, width: 0.8),
                                          ),
                                          child: const Text(
                                            'GK RESTRICTED',
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppPalette.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    'Age ${player.age?.toInt() ?? 25} • ${isTargetStarter ? "Starting XI" : "Bench / Reserve"}',
                                    style: AppTypography.caption(inkMuted),
                                  ),
                                ],
                              ),
                            ),
                            StatBadge(value: player.overall, label: ''),
                            const SizedBox(width: 8),
                            Icon(
                              canSwap ? Icons.swap_horiz_rounded : Icons.block_rounded,
                              size: 20,
                              color: canSwap ? AppPalette.gold : AppPalette.red,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sells a player from the squad, raising transfer war chest funds (Issue #9)
  void _sellPlayer(Player player, int index) {
    final window = TransferWindowState.compute(
      gameweek: _currentGameweek,
      totalGameweeks: _totalGameweeks,
    );

    if (!window.isOpen) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.lock_clock_rounded, color: AppPalette.red),
              const SizedBox(width: 8),
              const Text('Transfer Window Closed'),
            ],
          ),
          content: Text(
            'Outgoing player sales are only permitted during the Summer or Winter transfer window.\n\n${window.deadlineText}.',
            style: AppTypography.bodySmall(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: AppPalette.gold),
              child: const Text('Understood', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    if (_userSquad.length <= 11) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppPalette.red),
              const SizedBox(width: 8),
              const Text('Squad Size Limit'),
            ],
          ),
          content: Text(
            'Your squad must retain at least 11 registered players for matchday fixtures. Sign a replacement player before selling.',
            style: AppTypography.bodySmall(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: AppPalette.gold),
              child: const Text('Understood', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    if (player.primaryPosition == 'GK') {
      final gkCount = _userSquad.where((p) => p.primaryPosition == 'GK').length;
      if (gkCount <= 1) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppPalette.red),
                const SizedBox(width: 8),
                const Text('Only Goalkeeper'),
              ],
            ),
            content: Text(
              'You cannot sell ${player.name} because they are your club\'s only goalkeeper. Sign a replacement goalkeeper first.',
              style: AppTypography.bodySmall(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(backgroundColor: AppPalette.gold),
                child: const Text('Understood', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        return;
      }
    }

    final valuation = calculatePlayerValuation(player);
    final proceeds = calculatePlayerSalePrice(player);
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.currency_pound_rounded, color: AppPalette.gold),
            const SizedBox(width: 8),
            Text('Sell ${player.name}?', style: AppTypography.titleMedium(ink)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accept transfer offer for ${player.name}?',
              style: AppTypography.bodyLarge(ink).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${player.primaryPosition} • Rating: ${player.overall} OVR • Age: ${player.age?.toInt() ?? 25}',
              style: AppTypography.bodySmall(ink.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppPalette.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppPalette.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Market Value:', style: AppTypography.caption(ink)),
                      Text(
                        '£${valuation.toStringAsFixed(1)}M',
                        style: AppTypography.statNumber(ink, fontSize: 13, weight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Sale Proceeds (90%):', style: AppTypography.caption(ink)),
                      Text(
                        '+£${proceeds.toStringAsFixed(1)}M',
                        style: AppTypography.statNumber(AppPalette.green, fontSize: 13, weight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('New Club War Chest:', style: AppTypography.caption(ink)),
                      Text(
                        '£${(_budgetMillions + proceeds).toStringAsFixed(1)}M',
                        style: AppTypography.statNumber(AppPalette.gold, fontSize: 13, weight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              SoundService.instance.playClick();
              setState(() {
                _budgetMillions += proceeds;
                _userSquad.removeAt(index);
              });
              _persistCareerState();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppPalette.green,
                  content: Text(
                    'Sold ${player.name} for +£${proceeds.toStringAsFixed(1)}M! Transfer budget updated.',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              );
            },
            child: Text('Confirm Sale (+£${proceeds.toStringAsFixed(1)}M)',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Opens the inbound AI transfer offers bottom sheet (Fix 28 / User Fix 6)
  void _openInboundOffersSheet() {
    SoundService.instance.playClick();
    showInboundOffersSheet(
      context,
      offers: _pendingTransferOffers,
      userSquad: _userSquad,
      onAccept: _acceptTransferOffer,
      onRefuse: _refuseTransferOffer,
    );
  }

  /// Accepts an incoming AI club transfer bid, selling the player for the offered fee (Fix 28 / User Fix 6)
  void _acceptTransferOffer(TransferOffer offer) {
    if (_userSquad.length <= 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppPalette.red,
          content: Text('Cannot sell: Squad must maintain at least 11 registered players.'),
        ),
      );
      return;
    }

    final playerIndex = _userSquad.indexWhere(
      (p) => p.name.trim().toLowerCase() == offer.playerName.trim().toLowerCase(),
    );

    if (playerIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.red,
          content: Text('${offer.playerName} is no longer in your squad.'),
        ),
      );
      return;
    }

    final player = _userSquad[playerIndex];
    if (player.primaryPosition == 'GK' || player.isGoalkeeper) {
      final gks = _userSquad.where((p) => p.primaryPosition == 'GK' || p.isGoalkeeper).length;
      if (gks <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppPalette.red,
            content: Text('Cannot sell: Squad must retain at least one Goalkeeper.'),
          ),
        );
        return;
      }
    }

    SoundService.instance.playGoal();
    setState(() {
      _budgetMillions += offer.offeredFeeMillions;
      _userSquad.removeAt(playerIndex);
      _pendingTransferOffers.removeWhere((o) => o.id == offer.id);
    });
    _persistCareerState();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppPalette.green,
        content: Text(
          'Deal Agreed! ${offer.playerName} transferred to ${offer.buyingClub} for +£${offer.offeredFeeMillions.toStringAsFixed(1)}M!',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  /// Rejects an incoming AI club transfer bid (Fix 28 / User Fix 6)
  void _refuseTransferOffer(TransferOffer offer) {
    SoundService.instance.playClick();
    setState(() {
      _pendingTransferOffers.removeWhere((o) => o.id == offer.id);
    });
    _persistCareerState();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppPalette.red,
        content: Text(
          'Bid Refused: £${offer.offeredFeeMillions.toStringAsFixed(1)}M offer from ${offer.buyingClub} for ${offer.playerName} rejected.',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  /// Opens the Transfer Market & Scouting sheet (Issue #9 & Fix 28)
  void _openTransferMarket() {
    SoundService.instance.playClick();
    final windowState = TransferWindowState.compute(
      gameweek: _currentGameweek,
      totalGameweeks: _totalGameweeks,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransferMarketSheet(
        budget: _budgetMillions,
        isWindowOpen: windowState.isOpen,
        windowTitle: windowState.title,
        userSquad: _userSquad,
        currentSeason: _currentSeason,
        pendingOffersCount: _pendingTransferOffers.where((o) => o.isPending).length,
        onViewOffers: _openInboundOffersSheet,
        onSignPlayer: (player, fee, [int contractYears = 3]) {
          SoundService.instance.playCorrect();
          setState(() {
            _budgetMillions = max(0.0, _budgetMillions - fee);
            _userSquad.add(player);
            _playerContracts[player.name] = contractYears;
          });
          _persistCareerState();
        },
      ),
    );
  }

  /// Opens contract renewal and extension dialog for a squad player (Fix 30 / User Fix 8)
  void _promptRenewContract(Player player) {
    SoundService.instance.playClick();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink = theme.colorScheme.onSurface;
    final inkMuted = ink.withValues(alpha: 0.7);

    final currentYears = _playerContracts[player.name] ?? 3;
    final baseValuation = calculatePlayerValuation(player);
    final renewalCost = TransferMarketService.calculateContractRenewalCost(baseValuation);
    final canAfford = _budgetMillions >= renewalCost;
    final newYears = currentYears + 3;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppPalette.darkSurface : AppPalette.lightSurface,
        title: Row(
          children: [
            const Icon(Icons.history_edu_rounded, color: AppPalette.gold, size: 24),
            const SizedBox(width: 8),
            Text('Contract Extension', style: AppTypography.titleMedium(ink)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Extend ${player.name}\'s contract by +3 seasons?',
              style: AppTypography.bodyLarge(ink).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Rating: ${player.overall} OVR • Pos: ${player.primaryPosition} • Age: ${player.age?.toInt() ?? 25}',
              style: AppTypography.caption(inkMuted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPalette.gold.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Current Duration:', style: AppTypography.caption(ink)),
                      Text(
                        '$currentYears season${currentYears == 1 ? "" : "s"}',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: currentYears <= 1 ? AppPalette.warn : ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('New Contract Term:', style: AppTypography.caption(ink)),
                      Text(
                        '$newYears seasons (+3 yrs)',
                        style: AppTypography.statNumber(AppPalette.green, fontSize: 12, weight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Divider(color: AppPalette.gold.withValues(alpha: 0.3), height: 1),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Loyalty Extension Fee:', style: AppTypography.caption(ink)),
                      Text(
                        '£${renewalCost.toStringAsFixed(1)}M',
                        style: AppTypography.statNumber(AppPalette.gold, fontSize: 13, weight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Club War Chest:', style: AppTypography.caption(ink)),
                      Text(
                        '£${_budgetMillions.toStringAsFixed(1)}M',
                        style: AppTypography.statNumber(
                          canAfford ? AppPalette.green : AppPalette.coral,
                          fontSize: 12,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: canAfford ? AppPalette.gold : Colors.grey,
              foregroundColor: isDark ? AppPalette.darkBg : Colors.white,
            ),
            onPressed: canAfford
                ? () {
                    Navigator.pop(ctx);
                    SoundService.instance.playCorrect();
                    setState(() {
                      _budgetMillions = max(0.0, _budgetMillions - renewalCost);
                      _playerContracts[player.name] = newYears;
                    });
                    _persistCareerState();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppPalette.green,
                        content: Text(
                          'Extended ${player.name}\'s contract to $newYears seasons! (-£${renewalCost.toStringAsFixed(1)}M)',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    );
                  }
                : null,
            child: Text(
              canAfford ? 'Extend (+3 Seasons)' : 'INSUFFICIENT FUNDS',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens interactive season calendar & fixtures sheet (GW 1-38) (Issue #12)
  void _openScheduleSheet() {
    SoundService.instance.playClick();
    final league = kAvailableLeagues.firstWhere(
      (l) => l.id == _leagueId,
      orElse: () => kAvailableLeagues.first,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SeasonScheduleSheet(
        userClub: _userClub,
        userClubCode: _userClubCode,
        leagueName: league.name,
        leagueId: _leagueId,
        currentGameweek: _currentGameweek,
        totalGameweeks: _totalGameweeks,
        schedule: _seasonSchedule,
        seasonResultsArchive: _seasonResultsArchive,
      ),
    );
  }

  void _advanceSeason() {
    final pos = _leagueTable.indexWhere((t) => t.clubName == _userClub) + 1;
    final isChampion = pos == 1;
    if (isChampion) {
      SoundService.instance.playGoal();
    } else {
      SoundService.instance.playCorrect();
    }

    final totalTeams = _leagueClubs.isNotEmpty ? _leagueClubs.length : (_leagueTable.isNotEmpty ? _leagueTable.length : 20);
    final leagueMeritBonus = calculateLeagueMeritPrizeMoney(pos, totalTeams);
    final uclPrizeBonus = calculateUclPrizeMoney(_uclTournament, _userClub);
    final faCupPrizeBonus = _faCupTournament?.calculatePrizeMoney() ?? 0.0;
    final carabaoPrizeBonus = _carabaoCupTournament?.calculatePrizeMoney() ?? 0.0;
    final totalSeasonPrize = leagueMeritBonus + uclPrizeBonus + faCupPrizeBonus + carabaoPrizeBonus;

    // Calculate dynamic growth and decline results for the entire squad (Fix 27 / User Fix 5)
    final growthResults = <PlayerGrowthResult>[];
    for (final p in _userSquad) {
      final apps = _playerAppearances[p.name] ?? 0;
      final goals = _playerGoals[p.name] ?? 0;
      final assists = _playerAssists[p.name] ?? 0;
      final cleanSheets = _playerCleanSheets[p.name] ?? 0;
      final rTotal = _playerRatingsTotal[p.name] ?? 0.0;
      final rCount = _playerRatingsCount[p.name] ?? 0;
      final avgRating = rCount > 0 ? (rTotal / rCount) : 6.5;

      final res = PlayerGrowthService.processSeasonGrowth(
        player: p,
        appearances: apps,
        averageRating: avgRating,
        goals: goals,
        assists: assists,
        cleanSheets: cleanSheets,
      );
      growthResults.add(res);
    }

    // Calculate contract tick & free agent departures (Fix 30 / User Fix 8)
    final contractTick = TransferMarketService.processSeasonContractExpiry(
      squad: _userSquad,
      contracts: _playerContracts,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final ink = theme.colorScheme.onSurface;
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark ? AppPalette.darkSurface : AppPalette.lightSurface,
          title: Row(
            children: [
              Icon(
                isChampion ? Icons.emoji_events_rounded : Icons.workspace_premium_rounded,
                color: AppPalette.gold,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isChampion ? 'CHAMPIONS! 🏆' : 'Season $_currentSeason Concluded',
                  style: AppTypography.titleLarge(ink),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your club completed all $_totalGameweeks matchdays of Season $_currentSeason, finishing in position #$pos of $totalTeams.',
                  style: AppTypography.bodySmall(ink.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppPalette.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppPalette.gold.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('League Merit Prize (#$pos):', style: AppTypography.caption(ink)),
                          Text(
                            '+£${leagueMeritBonus.toStringAsFixed(1)}M',
                            style: AppTypography.statNumber(AppPalette.green, fontSize: 13, weight: FontWeight.w700),
                          ),
                        ],
                      ),
                      if (uclPrizeBonus > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('UCL Campaign Prize:', style: AppTypography.caption(ink)),
                            Text(
                              '+£${uclPrizeBonus.toStringAsFixed(1)}M',
                              style: AppTypography.statNumber(AppPalette.green, fontSize: 13, weight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                      if (faCupPrizeBonus > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('FA Cup Campaign Prize:', style: AppTypography.caption(ink)),
                            Text(
                              '+£${faCupPrizeBonus.toStringAsFixed(1)}M',
                              style: AppTypography.statNumber(AppPalette.green, fontSize: 13, weight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                      if (carabaoPrizeBonus > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Carabao Cup Prize:', style: AppTypography.caption(ink)),
                            Text(
                              '+£${carabaoPrizeBonus.toStringAsFixed(1)}M',
                              style: AppTypography.statNumber(AppPalette.green, fontSize: 13, weight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Divider(color: theme.dividerColor, height: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Prize Money:', style: AppTypography.bodySmall(ink).copyWith(fontWeight: FontWeight.bold)),
                          Text(
                            '+£${totalSeasonPrize.toStringAsFixed(1)}M',
                            style: AppTypography.statNumber(AppPalette.gold, fontSize: 15, weight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Updated War Chest:', style: AppTypography.caption(ink)),
                          Text(
                            '£${(_budgetMillions + totalSeasonPrize).toStringAsFixed(1)}M',
                            style: AppTypography.statNumber(AppPalette.green, fontSize: 13, weight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Winning matches and finishing higher earns greater performance prize money to reinvest into world-class talent next season.',
                  style: AppTypography.caption(ink.withValues(alpha: 0.65)),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppPalette.gold),
              onPressed: () {
                Navigator.pop(ctx);
                _showSquadDevelopmentDialog(growthResults, totalSeasonPrize, contractTick);
              },
              child: const Text('Review Squad Development', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showSquadDevelopmentDialog(
    List<PlayerGrowthResult> growthResults,
    double totalSeasonPrize,
    SquadContractTickResult contractTick,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final ink = theme.colorScheme.onSurface;
        final isDark = theme.brightness == Brightness.dark;
        final border = isDark ? AppPalette.darkBorder : AppPalette.lightBorder;

        final improvedCount = growthResults.where((r) => r.isGrowth).length;
        final declinedCount = growthResults.where((r) => r.isDecline).length;
        final stableCount = growthResults.where((r) => r.isUnchanged).length;

        return AlertDialog(
          backgroundColor: isDark ? AppPalette.darkSurface : AppPalette.lightSurface,
          title: Row(
            children: [
              const Icon(Icons.trending_up_rounded, color: AppPalette.green, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SQUAD DEVELOPMENT', style: AppTypography.titleLarge(ink)),
                    Text(
                      'Annual player progression & veteran aging',
                      style: AppTypography.caption(ink.withValues(alpha: 0.65)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildGrowthStatSummary('⚡ Improved', '$improvedCount', AppPalette.green),
                      _buildGrowthStatSummary('⏳ Stable', '$stableCount', AppPalette.gold),
                      _buildGrowthStatSummary('🔻 Age 33+ Decline', '$declinedCount', AppPalette.coral),
                    ],
                  ),
                ),
                if (contractTick.departedPlayers.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppPalette.coral.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppPalette.coral.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.person_remove_rounded, size: 16, color: AppPalette.coral),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CONTRACT EXPIRIES (${contractTick.departedPlayers.length} DEPARTED)',
                                style: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppPalette.coral,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${contractTick.departedPlayers.map((p) => p.name).join(", ")} reached contract expiry without renewal and departed as Free Agents.',
                                style: AppTypography.caption(ink).copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: growthResults.length,
                    separatorBuilder: (context, index) => Divider(color: border, height: 1),
                    itemBuilder: (_, index) {
                      final item = growthResults[index];
                      final deltaColor = item.isGrowth
                          ? AppPalette.green
                          : (item.isDecline ? AppPalette.coral : ink.withValues(alpha: 0.5));
                      final deltaText = item.isGrowth
                          ? '+${item.delta}'
                          : (item.isDecline ? '${item.delta}' : '=');

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            PlayerAvatar(name: item.player.name, size: 34),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item.player.name,
                                          style: TextStyle(
                                            fontFamily: AppTypography.fontFamily,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: ink,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      PositionBadge(position: item.player.primaryPosition),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Age ${item.oldAge} → ${item.newAge} • ${item.statusLabel}',
                                    style: TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontSize: 10.5,
                                      color: deltaColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${item.oldOverall}',
                                      style: TextStyle(
                                        fontFamily: AppTypography.fontFamily,
                                        fontSize: 13,
                                        color: ink.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    const Icon(Icons.arrow_forward_rounded, size: 11, color: AppPalette.gold),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${item.newOverall}',
                                      style: TextStyle(
                                        fontFamily: AppTypography.fontFamily,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: ink,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: deltaColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: deltaColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    deltaText,
                                    style: TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: deltaColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppPalette.gold),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  final remainingNames = contractTick.remainingSquad.map((p) => p.name).toSet();
                  _userSquad = growthResults
                      .map((r) => r.player)
                      .where((p) => remainingNames.contains(p.name))
                      .toList();
                  if (_userSquad.length < 11) {
                    _userSquad = List<Player>.from(contractTick.remainingSquad);
                  }
                  _playerContracts.clear();
                  _playerContracts.addAll(contractTick.updatedContracts);
                  _currentSeason++;
                  _currentGameweek = 1;
                  _budgetMillions += totalSeasonPrize;
                  _careerPrizeMoneyEarned += totalSeasonPrize;
                  _winterBudgetAwarded = false;
                  _seasonSchedule = generateSeasonSchedule(_leagueClubs, totalGameweeks: _totalGameweeks);
                  _uclTournament = UclTournament.create(userClub: _userClub);
                  final cupPool = List<String>.from(_leagueClubs);
                  for (final c in CupTournament.kDefaultEnglishCupClubs) {
                    if (!cupPool.contains(c)) cupPool.add(c);
                  }
                  _faCupTournament = CupTournament.create(id: 'fa_cup', userClub: _userClub, poolClubs: cupPool);
                  _carabaoCupTournament = CupTournament.create(id: 'carabao_cup', userClub: _userClub, poolClubs: cupPool);
                  _recentResults.clear();
                  _recentUclResults.clear();
                  _recentFaCupResults.clear();
                  _recentCarabaoResults.clear();
                  _pendingTransferOffers.clear();
                  _activeSquadEvents.clear();
                  _playerAppearances.clear();
                  _playerGoals.clear();
                  _playerAssists.clear();
                  _playerCleanSheets.clear();
                  _playerRatingsTotal.clear();
                  _playerRatingsCount.clear();
                  _leaguePlayerGoals.clear();
                  _leaguePlayerClubs.clear();
                  _leaguePlayerAssists.clear();
                  _leagueAssistClubs.clear();
                  _leagueClubCleanSheets.clear();
                  _leagueClubRatingTotals.clear();
                  _leagueClubRatingCounts.clear();
                  _teamStatsSortIndex = 0;
                  _seasonResultsArchive.clear();
                  _standingsTab = 0;
                  for (final t in _leagueTable) {
                    t.played = 0;
                    t.won = 0;
                    t.drawn = 0;
                    t.lost = 0;
                    t.goalsFor = 0;
                    t.goalsAgainst = 0;
                    t.points = 0;
                  }
                });
                _persistCareerState();
              },
              child: Text(
                'Begin Season ${_currentSeason + 1}',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGrowthStatSummary(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('CAREER CAMPAIGN')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isConfigured) {
      return _buildSetupWizard();
    }

    return _buildActiveCareer();
  }

  void _confirmDeleteSave() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppPalette.red),
            const SizedBox(width: 8),
            const Text('Delete Campaign Save?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete this saved campaign? All league standings, matchday progress, and squad records will be wiped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await PrefsService.instance.clearCareerConfig();
              await SaveService.instance.deleteCareerSave('active_career');
              setState(() {
                _existingSaveData = null;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Campaign save deleted.')),
                );
              }
            },
            child: const Text('Delete Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeSaveCard(Map<String, dynamic> saveData) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final inkMuted = ink.withValues(alpha: 0.7);
    final clubName = saveData['clubName'] as String? ?? 'Your Club';
    final clubCode = saveData['clubCode'] as String? ??
        (clubName.length >= 3 ? clubName.substring(0, 3).toUpperCase() : clubName.toUpperCase());
    final season = (saveData['season'] as num?)?.toInt() ?? 1;
    final gameweek = (saveData['gameweek'] as num?)?.toInt() ?? 1;
    final totalGw = (saveData['totalGameweeks'] as num?)?.toInt() ?? 38;
    final budget = (saveData['budget'] as num?)?.toDouble() ?? getClubStartingBudget(clubName);
    final leagueId = saveData['leagueId'] as String? ?? 'premier_league';
    final league = kAvailableLeagues.firstWhere(
      (l) => l.id == leagueId,
      orElse: () => kAvailableLeagues.first,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.gold, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bookmark_added_rounded, color: AppPalette.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'RESUME SAVED CAMPAIGN',
                  style: AppTypography.caption(AppPalette.gold).copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppPalette.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'SEASON $season',
                  style: AppTypography.caption(AppPalette.gold).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ClubBadge(code: clubCode, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clubName,
                      style: AppTypography.titleLarge(ink).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${league.name} • Gameweek $gameweek of $totalGw',
                      style: AppTypography.bodySmall(inkMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'War Chest: £${budget.toStringAsFixed(1)}M',
                      style: AppTypography.caption(AppPalette.green).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _confirmDeleteSave,
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppPalette.red),
                label: const Text('Discard Save', style: TextStyle(color: AppPalette.red, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppPalette.red.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    _initSeason();
                  },
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
                  label: const Text(
                    'RESUME CAMPAIGN',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.gold,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CAREER SETUP WIZARD (Issue #6)
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSetupWizard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink = theme.colorScheme.onSurface;
    final inkMuted = ink.withValues(alpha: 0.65);
    final selectedLeague = kAvailableLeagues.firstWhere((l) => l.id == _setupLeagueId);

    return Scaffold(
      appBar: AppBar(
        leading: _existingSaveData != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Return to Active Campaign',
                onPressed: () {
                  setState(() {
                    _isConfigured = true;
                  });
                },
              )
            : null,
        title: Text(
          'FOUND YOUR CLUB',
          style: AppTypography.sectionHeader(AppPalette.gold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_existingSaveData != null) ...[
              _buildResumeSaveCard(_existingSaveData!),
              const SizedBox(height: 20),
            ],
            // Header Banner
            HeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOUCHLINE MANAGER’S SUITE',
                    style: AppTypography.sectionHeader(AppPalette.gold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Launch Career Campaign',
                    style: AppTypography.heading(ink, fontSize: 24),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select your domestic league, establish your club identity, and choose your initial squad architecture.',
                    style: AppTypography.bodySmall(inkMuted),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // STEP 1: LEAGUE SELECTION
            Text(
              '1. CHOOSE LEAGUE',
              style: AppTypography.sectionHeader(AppPalette.gold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kAvailableLeagues.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final league = kAvailableLeagues[index];
                  final isSelected = league.id == _setupLeagueId;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _setupLeagueId = league.id;
                        _setupSelectedRealClub = league.clubs.first;
                        _setupReplacedClub = league.clubs.last;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 150,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised)
                            : (isDark ? AppPalette.darkCard : AppPalette.lightCard),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppPalette.gold : theme.dividerColor,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                league.country,
                                style: AppTypography.caption(AppPalette.gold),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: AppPalette.gold, size: 16),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            league.name,
                            style: AppTypography.bodyLarge(ink).copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${league.clubs.length} Clubs',
                            style: AppTypography.caption(inkMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // STEP 2: CLUB IDENTITY (REAL OR CUSTOM)
            Text(
              '2. CLUB IDENTITY',
              style: AppTypography.sectionHeader(AppPalette.gold),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _setupIsCustom = false),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_setupIsCustom ? AppPalette.gold : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 16,
                              color: !_setupIsCustom ? Colors.black : ink,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Manage Real Club',
                              style: TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: !_setupIsCustom ? Colors.black : ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _setupIsCustom = true),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _setupIsCustom ? AppPalette.gold : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 18,
                              color: _setupIsCustom ? Colors.black : ink,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Create Custom Club',
                              style: TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _setupIsCustom ? Colors.black : ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Detail for Real Club vs Custom Club
            if (!_setupIsCustom) ...[
              AlmanacCard(
                sectionTitle: 'SELECT TEAM IN ${selectedLeague.name.toUpperCase()}',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedLeague.clubs.map((club) {
                    final isSel = club == _setupSelectedRealClub;
                    final code = selectedLeague.clubCodes[club] ?? 'CLB';
                    return InkWell(
                      onTap: () => setState(() => _setupSelectedRealClub = club),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppPalette.gold.withValues(alpha: 0.15)
                              : (isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel ? AppPalette.gold : theme.dividerColor,
                            width: isSel ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClubBadge(code: code, size: 24),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  club,
                                  style: TextStyle(
                                    fontFamily: AppTypography.bodyFamily,
                                    fontSize: 13,
                                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                    color: isSel ? AppPalette.gold : ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '£${getClubStartingBudget(club).toStringAsFixed(0)}M war chest',
                                  style: TextStyle(
                                    fontFamily: AppTypography.bodyFamily,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isSel ? (isDark ? AppPalette.gold : AppPalette.goldDark) : inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ] else ...[
              AlmanacCard(
                sectionTitle: 'CUSTOM CLUB DETAILS',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _customClubNameController,
                      decoration: InputDecoration(
                        labelText: 'Club Name',
                        hintText: 'e.g. Ayaan FC, Royal London',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.shield_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customClubCodeController,
                      maxLength: 4,
                      decoration: InputDecoration(
                        labelText: '3-Letter Abbreviation / Badge Code',
                        hintText: 'e.g. AYN',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.badge_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Replaces Team in ${selectedLeague.name}:',
                      style: AppTypography.caption(inkMuted),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _setupReplacedClub,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: selectedLeague.clubs.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _setupReplacedClub = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppPalette.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppPalette.gold.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, size: 16, color: AppPalette.gold),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Starting War Chest: £${getClubStartingBudget(_setupReplacedClub).toStringAsFixed(0)}.0M (Inherited from $_setupReplacedClub)',
                              style: TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppPalette.gold : AppPalette.goldDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // STEP 3: SQUAD ALLOCATION TYPE
            Text(
              '3. SQUAD SELECTION',
              style: AppTypography.sectionHeader(AppPalette.gold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _setupSquadMode = 'current'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _setupSquadMode == 'current'
                            ? (isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised)
                            : (isDark ? AppPalette.darkCard : AppPalette.lightCard),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _setupSquadMode == 'current' ? AppPalette.gold : theme.dividerColor,
                          width: _setupSquadMode == 'current' ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.groups_rounded, color: AppPalette.gold, size: 24),
                          const SizedBox(height: 8),
                          Text(
                            'Current Squad',
                            style: AppTypography.bodyLarge(ink).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Inherit authentic stars and depth from the selected team.',
                            style: AppTypography.caption(inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() => _setupSquadMode = 'random');
                      if (_draftedRandomSquad.isEmpty) {
                        _generateDraftSquad();
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _setupSquadMode == 'random'
                            ? (isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised)
                            : (isDark ? AppPalette.darkCard : AppPalette.lightCard),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _setupSquadMode == 'random' ? AppPalette.gold : theme.dividerColor,
                          width: _setupSquadMode == 'random' ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.casino_rounded, color: AppPalette.gold, size: 24),
                          const SizedBox(height: 8),
                          Text(
                            'Random Squad',
                            style: AppTypography.bodyLarge(ink).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Draft a balanced 18-player squad (2 GK, 6 DEF, 6 MID, 4 FWD).',
                            style: AppTypography.caption(inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_setupSquadMode == 'random') ...[
              const SizedBox(height: 16),
              _buildRandomSquadDraftPreview(isDark, ink, inkMuted, theme),
            ],

            const SizedBox(height: 24),

            // STEP 4: CAMPAIGN LENGTH (Issue #12)
            Text(
              '4. CAMPAIGN LENGTH',
              style: AppTypography.sectionHeader(AppPalette.gold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _setupTotalGameweeks = 38),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _setupTotalGameweeks == 38
                            ? (isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised)
                            : (isDark ? AppPalette.darkCard : AppPalette.lightCard),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _setupTotalGameweeks == 38 ? AppPalette.gold : theme.dividerColor,
                          width: _setupTotalGameweeks == 38 ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Icon(Icons.calendar_month_rounded, color: AppPalette.gold, size: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppPalette.gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'AUTHENTIC',
                                  style: AppTypography.caption(AppPalette.gold).copyWith(fontSize: 8.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Full Marathon',
                            style: AppTypography.bodyLarge(ink).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '38 Matchdays • Summer & Winter (GW 19) transfer windows.',
                            style: AppTypography.caption(inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _setupTotalGameweeks = 18),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _setupTotalGameweeks == 18
                            ? (isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised)
                            : (isDark ? AppPalette.darkCard : AppPalette.lightCard),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _setupTotalGameweeks == 18 ? AppPalette.gold : theme.dividerColor,
                          width: _setupTotalGameweeks == 18 ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Icon(Icons.speed_rounded, color: AppPalette.gold, size: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppPalette.gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'FAST PACE',
                                  style: AppTypography.caption(AppPalette.gold).copyWith(fontSize: 8.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sprint Campaign',
                            style: AppTypography.bodyLarge(ink).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '18 Matchdays • Double round-robin (Home & Away).',
                            style: AppTypography.caption(inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // LAUNCH BUTTON
            FilledButton.icon(
              onPressed: _launchCareer,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text('FOUND CLUB & START SEASON 1 ($_setupTotalGameweeks MATCHES)'),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRandomSquadDraftPreview(bool isDark, Color ink, Color inkMuted, ThemeData theme) {
    if (_draftedRandomSquad.isEmpty && !_isDrafting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _draftedRandomSquad.isEmpty && !_isDrafting) {
          _generateDraftSquad();
        }
      });
    }

    if (_isDrafting) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        alignment: Alignment.center,
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppPalette.gold),
            const SizedBox(height: 12),
            Text('Drafting balanced 18-player squad...', style: AppTypography.bodySmall(inkMuted)),
          ],
        ),
      );
    }

    if (_draftedRandomSquad.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: OutlinedButton.icon(
          onPressed: _generateDraftSquad,
          icon: const Icon(Icons.casino_rounded, color: AppPalette.gold),
          label: const Text('GENERATE RANDOM DRAFT SQUAD'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppPalette.gold,
            side: const BorderSide(color: AppPalette.gold),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );
    }

    final avgOvr = (_draftedRandomSquad.map((p) => p.overall).reduce((a, b) => a + b) / _draftedRandomSquad.length).toStringAsFixed(1);
    final count80Plus = _draftedRandomSquad.where((p) => p.overall >= 80).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.shuffle_rounded, color: AppPalette.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DRAFT PREVIEW • $_draftSwapsRemaining / 3 SWAPS LEFT',
                      style: AppTypography.sectionHeader(AppPalette.gold),
                    ),
                    Text(
                      'Avg $avgOvr OVR • $count80Plus players 80+ • Tap [Swap (80+)] to switch',
                      style: AppTypography.caption(inkMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Re-roll entire draft',
                onPressed: _generateDraftSquad,
                color: inkMuted,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: theme.dividerColor, height: 1),
          const SizedBox(height: 6),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _draftedRandomSquad.length,
            separatorBuilder: (context, index) => Divider(color: theme.dividerColor.withValues(alpha: 0.2), height: 1),
            itemBuilder: (context, index) {
              final player = _draftedRandomSquad[index];
              final is80Plus = player.overall >= 80;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: inkMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    PlayerAvatar(name: player.name, size: 26),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  player.name,
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 12.5,
                                    fontWeight: is80Plus ? FontWeight.w700 : FontWeight.w500,
                                    color: ink,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              PositionBadge(position: player.primaryPosition),
                            ],
                          ),
                          Text(
                            'Age ${player.age?.toInt() ?? 25} • ${player.teamName.isNotEmpty ? player.teamName : "Free Agent"}',
                            style: AppTypography.caption(inkMuted).copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    StatBadge(value: player.overall, label: ''),
                    const SizedBox(width: 8),
                    if (_draftSwapsRemaining > 0)
                      SizedBox(
                        height: 28,
                        child: OutlinedButton.icon(
                          onPressed: () => _swapDraftPlayer(index),
                          icon: const Icon(Icons.shuffle_rounded, size: 12),
                          label: const Text('SWAP (80+)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppPalette.gold,
                            side: const BorderSide(color: AppPalette.gold, width: 0.8),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            textStyle: const TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'LOCKED',
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: inkMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ACTIVE CAREER DASHBOARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildActiveCareer() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink = theme.colorScheme.onSurface;
    final inkMuted = ink.withValues(alpha: 0.65);
    final border = theme.dividerColor;
    final coins = ref.watch(coinsProvider);
    final activeLeague = kAvailableLeagues.firstWhere(
      (l) => l.id == _leagueId,
      orElse: () => kAvailableLeagues.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('CAREER CAMPAIGN', style: AppTypography.sectionHeader(AppPalette.gold)),
        actions: [
          // Season Calendar & Fixtures Button (Issue #12)
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Season Calendar & Fixtures',
            onPressed: _openScheduleSheet,
          ),
          // New Campaign Button
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'New Campaign / Switch Club',
            onPressed: _promptNewCampaign,
          ),
          // Transfer budget pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppPalette.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '£${_budgetMillions.toStringAsFixed(1)}M',
              style: AppTypography.statNumber(AppPalette.green, fontSize: 12, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          // Coins pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: AppPalette.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppPalette.gold,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '¢',
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppPalette.darkBg : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  coins.toString(),
                  style: AppTypography.statNumber(ink, fontSize: 12, weight: FontWeight.w700),
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
            // Manager Office & Club Banner
            HeroCard(
              child: Row(
                children: [
                  ClubBadge(code: _userClubCode, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _userClub,
                                style: AppTypography.titleMedium(ink),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_isCustomClub) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppPalette.gold.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'CUSTOM',
                                  style: AppTypography.caption(AppPalette.gold).copyWith(fontSize: 9, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${activeLeague.divisionTitle} • S$_currentSeason (GW $_currentGameweek/$_totalGameweeks)',
                                style: AppTypography.caption(inkMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_careerPrizeMoneyEarned > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppPalette.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '+£${_careerPrizeMoneyEarned.toStringAsFixed(1)}M WON',
                                  style: const TextStyle(
                                    fontFamily: AppTypography.bodyFamily,
                                    fontSize: 8.5,
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
                  ),
                  FilledButton.icon(
                    onPressed: _simMatchday,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(_currentGameweek <= _totalGameweeks ? 'Sim' : 'End'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.gold,
                      foregroundColor: isDark ? AppPalette.darkBg : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Transfer Window Status Banner (Issue #12)
            _buildTransferWindowCard(
              windowState: TransferWindowState.compute(
                gameweek: _currentGameweek,
                totalGameweeks: _totalGameweeks,
              ),
              isDark: isDark,
              ink: ink,
              inkMuted: inkMuted,
            ),

            const SizedBox(height: 12),

            // Next Fixture Preview Card (Issue #12)
            _buildNextFixtureCard(
              activeLeague: activeLeague,
              isDark: isDark,
              ink: ink,
              inkMuted: inkMuted,
            ),

            const SizedBox(height: 16),

            // Unified Matchday Scoreboard & Report (Issue #7, Fix 23, Fix 24 & Fix 26 / User Fix 1, 2 & 4)
            if (_recentResults.isNotEmpty || _recentUclResults.isNotEmpty || _recentFaCupResults.isNotEmpty || _recentCarabaoResults.isNotEmpty) ...[
              Builder(
                builder: (context) {
                  final displayLeague = List<MatchResult>.from(_recentResults)..sort((a, b) {
                    final aUser = a.homeClub == _userClub || a.awayClub == _userClub;
                    final bUser = b.homeClub == _userClub || b.awayClub == _userClub;
                    if (aUser && !bUser) return -1;
                    if (!aUser && bUser) return 1;
                    return 0;
                  });

                  final displayUcl = List<MatchResult>.from(_recentUclResults)..sort((a, b) {
                    final aUser = a.homeClub == _userClub || a.awayClub == _userClub;
                    final bUser = b.homeClub == _userClub || b.awayClub == _userClub;
                    if (aUser && !bUser) return -1;
                    if (!aUser && bUser) return 1;
                    return 0;
                  });

                  final displayFa = List<MatchResult>.from(_recentFaCupResults)..sort((a, b) {
                    final aUser = a.homeClub == _userClub || a.awayClub == _userClub;
                    final bUser = b.homeClub == _userClub || b.awayClub == _userClub;
                    if (aUser && !bUser) return -1;
                    if (!aUser && bUser) return 1;
                    return 0;
                  });

                  final displayCarabao = List<MatchResult>.from(_recentCarabaoResults)..sort((a, b) {
                    final aUser = a.homeClub == _userClub || a.awayClub == _userClub;
                    final bUser = b.homeClub == _userClub || b.awayClub == _userClub;
                    if (aUser && !bUser) return -1;
                    if (!aUser && bUser) return 1;
                    return 0;
                  });

                  // User matches
                  final userLeagueMatches = displayLeague.where(
                    (m) => m.homeClub == _userClub || m.awayClub == _userClub,
                  );
                  final userLeagueMatch = userLeagueMatches.isNotEmpty ? userLeagueMatches.first : null;

                  final userUclMatches = displayUcl.where(
                    (m) => m.homeClub == _userClub || m.awayClub == _userClub,
                  );
                  final userUclMatch = userUclMatches.isNotEmpty ? userUclMatches.first : null;

                  final userFaMatches = displayFa.where(
                    (m) => m.homeClub == _userClub || m.awayClub == _userClub,
                  );
                  final userFaMatch = userFaMatches.isNotEmpty ? userFaMatches.first : null;

                  final userCarabaoMatches = displayCarabao.where(
                    (m) => m.homeClub == _userClub || m.awayClub == _userClub,
                  );
                  final userCarabaoMatch = userCarabaoMatches.isNotEmpty ? userCarabaoMatches.first : null;

                  final hasUcl = _recentUclResults.isNotEmpty;
                  final hasFa = _recentFaCupResults.isNotEmpty;
                  final hasCarabao = _recentCarabaoResults.isNotEmpty;
                  final hasMultipleComps = hasUcl || hasFa || hasCarabao;

                  List<MatchResult> currentResultsList = displayLeague;
                  String currentCompName = activeLeague.name.toUpperCase();
                  MatchResult? currentUserMatch = userLeagueMatch;

                  if (_resultsCompTab == 1 && hasUcl) {
                    currentResultsList = displayUcl;
                    currentCompName = 'UEFA CHAMPIONS LEAGUE';
                    currentUserMatch = userUclMatch;
                  } else if (_resultsCompTab == 2 && hasFa) {
                    currentResultsList = displayFa;
                    currentCompName = 'THE EMIRATES FA CUP';
                    currentUserMatch = userFaMatch;
                  } else if (_resultsCompTab == 3 && hasCarabao) {
                    currentResultsList = displayCarabao;
                    currentCompName = 'CARABAO CUP';
                    currentUserMatch = userCarabaoMatch;
                  }

                  return AlmanacCard(
                    sectionTitle: 'MATCHDAY ${_currentGameweek - 1} SCOREBOARD & REPORT',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. TOP SPOTLIGHT: YOUR CLUB MATCHES THIS MATCHDAY
                        if (userLeagueMatch != null || userUclMatch != null || userFaMatch != null || userCarabaoMatch != null) ...[
                          if (userLeagueMatch != null) ...[
                            _buildMatchResultTile(
                              m: userLeagueMatch,
                              isDark: isDark,
                              ink: ink,
                              inkMuted: inkMuted,
                              activeLeague: activeLeague,
                              competitionName: activeLeague.name.toUpperCase(),
                            ),
                          ],
                          if (userUclMatch != null) ...[
                            const SizedBox(height: 8),
                            _buildMatchResultTile(
                              m: userUclMatch,
                              isDark: isDark,
                              ink: ink,
                              inkMuted: inkMuted,
                              activeLeague: activeLeague,
                              competitionName: 'UEFA CHAMPIONS LEAGUE',
                            ),
                          ],
                          if (userFaMatch != null) ...[
                            const SizedBox(height: 8),
                            _buildMatchResultTile(
                              m: userFaMatch,
                              isDark: isDark,
                              ink: ink,
                              inkMuted: inkMuted,
                              activeLeague: activeLeague,
                              competitionName: 'THE EMIRATES FA CUP',
                            ),
                          ],
                          if (userCarabaoMatch != null) ...[
                            const SizedBox(height: 8),
                            _buildMatchResultTile(
                              m: userCarabaoMatch,
                              isDark: isDark,
                              ink: ink,
                              inkMuted: inkMuted,
                              activeLeague: activeLeague,
                              competitionName: 'CARABAO CUP',
                            ),
                          ],
                          const SizedBox(height: 12),
                        ],

                        // 2. COMPETITION TOGGLE SWITCHER (if cup/continental matches were played this gameweek)
                        if (hasMultipleComps) ...[
                          Container(
                            padding: const EdgeInsets.all(3),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildResultCompTabButton(
                                    tabIndex: 0,
                                    label: '${activeLeague.clubCodes[_userClub] ?? 'LEAGUE'} (${displayLeague.length})',
                                    icon: Icons.sports_soccer_rounded,
                                    isDark: isDark,
                                    ink: ink,
                                    inkMuted: inkMuted,
                                  ),
                                  if (hasUcl) ...[
                                    const SizedBox(width: 4),
                                    _buildResultCompTabButton(
                                      tabIndex: 1,
                                      label: 'UCL (${displayUcl.length})',
                                      icon: Icons.star_rounded,
                                      isDark: isDark,
                                      ink: ink,
                                      inkMuted: inkMuted,
                                      isUcl: true,
                                    ),
                                  ],
                                  if (hasFa) ...[
                                    const SizedBox(width: 4),
                                    _buildResultCompTabButton(
                                      tabIndex: 2,
                                      label: 'FA CUP (${displayFa.length})',
                                      icon: Icons.workspace_premium_rounded,
                                      isDark: isDark,
                                      ink: ink,
                                      inkMuted: inkMuted,
                                    ),
                                  ],
                                  if (hasCarabao) ...[
                                    const SizedBox(width: 4),
                                    _buildResultCompTabButton(
                                      tabIndex: 3,
                                      label: 'CARABAO (${displayCarabao.length})',
                                      icon: Icons.shield_rounded,
                                      isDark: isDark,
                                      ink: ink,
                                      inkMuted: inkMuted,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],

                        // 3. SECTION HEADER FOR FIXTURES LIST
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: theme.dividerColor.withValues(alpha: 0.3),
                                  height: 1,
                                  thickness: 0.5,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  _resultsCompTab == 1 && hasUcl
                                      ? 'ALL UCL MIDWEEK FIXTURES'
                                      : _resultsCompTab == 2 && hasFa
                                          ? 'ALL FA CUP FIXTURES'
                                          : _resultsCompTab == 3 && hasCarabao
                                              ? 'ALL CARABAO CUP FIXTURES'
                                              : 'AROUND THE LEAGUE',
                                  style: AppTypography.caption(inkMuted).copyWith(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: theme.dividerColor.withValues(alpha: 0.3),
                                  height: 1,
                                  thickness: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        // 4. FIXTURES LIST (excluding already featured user match)
                        for (int idx = 0; idx < currentResultsList.length; idx++) ...[
                          if (currentResultsList[idx] == currentUserMatch)
                            const SizedBox.shrink()
                          else ...[
                            if (idx > 0)
                              Divider(
                                color: theme.dividerColor.withValues(alpha: 0.3),
                                height: 16,
                                thickness: 0.5,
                              ),
                            _buildMatchResultTile(
                              m: currentResultsList[idx],
                              isDark: isDark,
                              ink: ink,
                              inkMuted: inkMuted,
                              activeLeague: activeLeague,
                              competitionName: currentCompName,
                            ),
                          ],
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // League Table, Team Stats, Golden Boot, Assists, Clean Sheets & UCL (Issue #3, #7, #8, Fix 22)
            AlmanacCard(
              sectionTitle: _standingsTab == 0
                  ? '${activeLeague.divisionTitle.toUpperCase()} STANDINGS'
                  : _standingsTab == 1
                      ? 'LEAGUE TEAM STATS • OVERALL PERFORMANCE'
                      : _standingsTab == 2
                          ? 'GOLDEN BOOT • LEAGUE TOP SCORERS'
                          : _standingsTab == 3
                              ? 'PLAYMAKER • LEAGUE TOP ASSISTS'
                              : _standingsTab == 4
                                  ? 'CLEAN SHEETS • DEFENSIVE SHUTOUTS'
                                  : _standingsTab == 5
                                      ? 'UEFA CHAMPIONS LEAGUE 2026/27'
                                      : 'DOMESTIC CUPS • BRACKETS & STATS',
              child: Column(
                children: [
                  // 7-Tab selector
                  Container(
                    padding: const EdgeInsets.all(3),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStandingsTabButton(
                            tabIndex: 0,
                            label: 'TABLE',
                            icon: Icons.table_chart_rounded,
                            isDark: isDark,
                            ink: ink,
                            inkMuted: inkMuted,
                          ),
                          const SizedBox(width: 4),
                          _buildStandingsTabButton(
                            tabIndex: 1,
                            label: 'TEAM STATS',
                            icon: Icons.analytics_rounded,
                            isDark: isDark,
                            ink: ink,
                            inkMuted: inkMuted,
                          ),
                          const SizedBox(width: 4),
                          _buildStandingsTabButton(
                            tabIndex: 2,
                            label: 'SCORERS',
                            icon: Icons.military_tech_rounded,
                            isDark: isDark,
                            ink: ink,
                            inkMuted: inkMuted,
                          ),
                          const SizedBox(width: 4),
                          _buildStandingsTabButton(
                            tabIndex: 3,
                            label: 'ASSISTS',
                            icon: Icons.auto_awesome_rounded,
                            isDark: isDark,
                            ink: ink,
                            inkMuted: inkMuted,
                          ),
                          const SizedBox(width: 4),
                          _buildStandingsTabButton(
                            tabIndex: 4,
                            label: 'CLEAN SHEETS',
                            icon: Icons.shield_rounded,
                            isDark: isDark,
                            ink: ink,
                            inkMuted: inkMuted,
                          ),
                          const SizedBox(width: 4),
                          _buildStandingsTabButton(
                            tabIndex: 5,
                            label: 'UCL',
                            icon: Icons.emoji_events_rounded,
                            isDark: isDark,
                            ink: ink,
                            inkMuted: inkMuted,
                          ),
                          const SizedBox(width: 4),
                          _buildStandingsTabButton(
                            tabIndex: 6,
                            label: 'CUPS',
                            icon: Icons.workspace_premium_rounded,
                            isDark: isDark,
                            ink: ink,
                            inkMuted: inkMuted,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_standingsTab == 0)
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(0.6), // Pos
                        1: FlexColumnWidth(3.0), // Club
                        2: FlexColumnWidth(0.8), // P
                        3: FlexColumnWidth(0.8), // W
                        4: FlexColumnWidth(0.8), // D
                        5: FlexColumnWidth(0.8), // L
                        6: FlexColumnWidth(1.0), // GD
                        7: FlexColumnWidth(1.1), // PTS
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          children: [
                            _headerCell('#', inkMuted),
                            _headerCell('CLUB', inkMuted, align: TextAlign.left),
                            _headerCell('P', inkMuted),
                            _headerCell('W', inkMuted),
                            _headerCell('D', inkMuted),
                            _headerCell('L', inkMuted),
                            _headerCell('GD', inkMuted),
                            _headerCell('PTS', inkMuted),
                          ],
                        ),
                        ...List.generate(_leagueTable.length, (idx) {
                          final t = _leagueTable[idx];
                          final isUser = t.clubName == _userClub;
                          final rowInk = isUser ? AppPalette.darkAccent : ink;

                          return TableRow(
                            decoration: isUser
                                ? BoxDecoration(color: AppPalette.darkAccent.withValues(alpha: 0.08))
                                : null,
                            children: [
                              _cell('${idx + 1}', inkMuted),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  t.clubName,
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 12,
                                    fontWeight: isUser ? FontWeight.w800 : FontWeight.w500,
                                    color: rowInk,
                                  ),
                                ),
                              ),
                              _cell('${t.played}', inkMuted),
                              _cell('${t.won}', inkMuted),
                              _cell('${t.drawn}', inkMuted),
                              _cell('${t.lost}', inkMuted),
                              _cell('${t.goalDifference >= 0 ? "+" : ""}${t.goalDifference}', rowInk),
                              _cell('${t.points}', rowInk, isBold: true),
                            ],
                          );
                        }),
                      ],
                    )
                  else if (_standingsTab == 1)
                    _buildTeamStatsTable(isDark, ink, inkMuted, activeLeague)
                  else if (_standingsTab == 2)
                    _buildGoldenBootTable(isDark, ink, inkMuted, activeLeague)
                  else if (_standingsTab == 3)
                    _buildAssistsTable(isDark, ink, inkMuted, activeLeague)
                  else if (_standingsTab == 4)
                    _buildCleanSheetsTable(isDark, ink, inkMuted, activeLeague)
                  else if (_standingsTab == 5)
                    _buildUclStandings(isDark, ink, inkMuted, activeLeague)
                  else
                    _buildCupsStandings(isDark, ink, inkMuted, activeLeague),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Squad Management Section (Starting XI vs Bench/Reserves, Auto-Pick, Swap & Sell)
            _buildSquadManagementSection(isDark, ink, inkMuted, border),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text, Color inkMuted, {TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: inkMuted,
        ),
      ),
    );
  }

  Widget _cell(String text, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 12,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
          color: color,
          fontFeatures: AppTypography.tabularFeatures,
        ),
      ),
    );
  }

  ScheduledFixture? get _nextUserFixture {
    if (_currentGameweek > _totalGameweeks || _seasonSchedule.isEmpty) return null;
    final roundFixtures = _seasonSchedule[_currentGameweek - 1];
    for (final f in roundFixtures) {
      if (f.homeClub == _userClub || f.awayClub == _userClub) {
        return f;
      }
    }
    return null;
  }

  /// Builds a prominent transfer window status banner (Issue #12)
  Widget _buildTransferWindowCard({
    required TransferWindowState windowState,
    required bool isDark,
    required Color ink,
    required Color inkMuted,
  }) {
    Color accentColor;
    IconData iconData;

    if (windowState.type == TransferWindowType.summer) {
      accentColor = AppPalette.gold;
      iconData = Icons.wb_sunny_rounded;
    } else if (windowState.type == TransferWindowType.winter) {
      accentColor = Colors.lightBlueAccent;
      iconData = Icons.ac_unit_rounded;
    } else {
      accentColor = inkMuted;
      iconData = Icons.lock_clock_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: windowState.isOpen ? accentColor.withValues(alpha: 0.5) : Theme.of(context).dividerColor,
          width: windowState.isOpen ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, color: accentColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          windowState.title,
                          style: AppTypography.caption(accentColor).copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: windowState.isOpen ? accentColor : accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            windowState.isOpen ? 'ACTIVE' : 'LOCKED',
                            style: TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: windowState.isOpen
                                  ? (isDark ? Colors.black : Colors.white)
                                  : inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      windowState.subtitle,
                      style: AppTypography.bodySmall(ink).copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      windowState.deadlineText,
                      style: AppTypography.caption(inkMuted).copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_pendingTransferOffers.where((o) => o.isPending).isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: _openInboundOffersSheet,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppPalette.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppPalette.gold.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mark_email_unread_rounded, color: AppPalette.gold, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_pendingTransferOffers.where((o) => o.isPending).length} Inbound Transfer Bids Received!',
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.gold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'REVIEW BIDS ➔',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: AppPalette.gold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: windowState.isOpen
                ? FilledButton.icon(
                    onPressed: _openTransferMarket,
                    icon: const Icon(Icons.storefront_rounded, size: 16),
                    label: const Text('EXPLORE TRANSFER MARKET & SCOUT PLAYERS'),
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: isDark ? AppPalette.darkBg : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      textStyle: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: _openTransferMarket,
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: const Text('SCOUT DATABASE (MARKET LOCKED)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: inkMuted,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      side: BorderSide(color: Theme.of(context).dividerColor),
                      textStyle: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Builds the tactical squad management card separating Starting XI vs Bench/Reserves (Issue #9)
  Widget _buildSquadManagementSection(bool isDark, Color ink, Color inkMuted, Color border) {
    final startingXi = _userSquad.take(11).toList();
    final bench = _userSquad.length > 11 ? _userSquad.sublist(11) : <Player>[];
    final startingAvg = startingXi.isNotEmpty
        ? (startingXi.map((p) => p.overall).reduce((a, b) => a + b) / startingXi.length)
        : 0.0;

    return AlmanacCard(
      sectionTitle: 'TEAM MANAGEMENT (${_userSquad.length} REGISTERED)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Control Bar: Starting XI Average OVR pill + Auto-Pick & Market buttons
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 13, color: AppPalette.gold),
                    const SizedBox(width: 4),
                    Text(
                      'XI OVR: ${startingAvg.toStringAsFixed(1)}',
                      style: AppTypography.caption(AppPalette.gold).copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Formation & Tactics Button (Issue #4 & Fix 31)
              OutlinedButton.icon(
                onPressed: _openFormationEditor,
                icon: const Icon(Icons.dashboard_customize_rounded, size: 14, color: AppPalette.gold),
                label: Text(
                  _customFormationSlots[_formationId] != null &&
                          TacticalFormation.getById(_formationId).isCustomized(_customFormationSlots[_formationId]!)
                      ? 'FORMATION ($_formationId*)'
                      : 'FORMATION ($_formationId)',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.gold,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  side: const BorderSide(color: AppPalette.gold, width: 1),
                  textStyle: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 6),
              // Auto-Pick Button
              OutlinedButton.icon(
                onPressed: _autoPickBestXi,
                icon: const Icon(Icons.bolt_rounded, size: 14, color: AppPalette.gold),
                label: const Text('AUTO-PICK XI'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.gold,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  side: const BorderSide(color: AppPalette.gold, width: 1),
                  textStyle: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 6),
              // Transfer Market Button
              FilledButton.icon(
                onPressed: _openTransferMarket,
                icon: const Icon(Icons.storefront_rounded, size: 14),
                label: const Text('MARKET'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.gold,
                  foregroundColor: isDark ? AppPalette.darkBg : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  textStyle: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: border, height: 1),
          const SizedBox(height: 10),

          // SUBHEADER 1: STARTING XI
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.sports_soccer_rounded, size: 14, color: AppPalette.gold),
                  const SizedBox(width: 6),
                  Text(
                    _customFormationSlots[_formationId] != null &&
                            TacticalFormation.getById(_formationId).isCustomized(_customFormationSlots[_formationId]!)
                        ? 'STARTING XI • $_formationId (CUSTOM)'
                        : 'STARTING XI • $_formationId',
                    style: AppTypography.caption(AppPalette.gold).copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                'Matchday Line-Up • Positions 1–11',
                style: AppTypography.caption(inkMuted).copyWith(fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Starters List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: startingXi.length,
            separatorBuilder: (context, index) => Divider(color: border.withValues(alpha: 0.3), height: 1),
            itemBuilder: (context, index) {
              return _buildSquadPlayerTile(
                index: index,
                player: startingXi[index],
                isStarter: true,
                isDark: isDark,
                ink: ink,
                inkMuted: inkMuted,
              );
            },
          ),

          const SizedBox(height: 16),
          Divider(color: border, height: 1),
          const SizedBox(height: 10),

          // SUBHEADER 2: BENCH & RESERVES
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.chair_alt_rounded, size: 14, color: inkMuted),
                  const SizedBox(width: 6),
                  Text(
                    'BENCH & RESERVES (${bench.length})',
                    style: AppTypography.caption(inkMuted).copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                'Available for Tactical Swap',
                style: AppTypography.caption(inkMuted).copyWith(fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),

          if (bench.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No bench reserves. Visit the Transfer Market to sign squad depth.',
                  style: AppTypography.caption(inkMuted).copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bench.length,
              separatorBuilder: (context, index) => Divider(color: border.withValues(alpha: 0.3), height: 1),
              itemBuilder: (context, index) {
                return _buildSquadPlayerTile(
                  index: 11 + index,
                  player: bench[index],
                  isStarter: false,
                  isDark: isDark,
                  ink: ink,
                  inkMuted: inkMuted,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSquadPlayerTile({
    required int index,
    required Player player,
    required bool isStarter,
    required bool isDark,
    required Color ink,
    required Color inkMuted,
  }) {
    final apps = _playerAppearances[player.name] ?? 0;
    final goals = _playerGoals[player.name] ?? 0;
    final assists = _playerAssists[player.name] ?? 0;
    final cleanSheets = _playerCleanSheets[player.name] ?? 0;
    final rTotal = _playerRatingsTotal[player.name] ?? 0.0;
    final rCount = _playerRatingsCount[player.name] ?? 0;
    final avgRating = rCount > 0 ? (rTotal / rCount) : 0.0;
    final ratingStr = avgRating > 0 ? ' • ★ ${avgRating.toStringAsFixed(1)}' : '';

    final isGk = player.primaryPosition == 'GK';
    final isDef = const ['CB', 'LB', 'RB', 'LWB', 'RWB'].contains(player.primaryPosition);
    final squadEvent = SquadEventService.getPlayerEvent(player.name, _activeSquadEvents);

    final statSummary = isGk
        ? '$apps apps • $cleanSheets cs$ratingStr'
        : (isDef
            ? '$apps apps • $goals gls • $cleanSheets cs$ratingStr'
            : '$apps apps • $goals gls • $assists ast$ratingStr');

    return InkWell(
      onTap: () => showPlayerDetailSheet(
        context,
        player,
        isCareerMode: true,
        careerClubName: _userClub,
        careerSeason: _currentSeason,
        careerAppearances: apps,
        careerGoals: goals,
        careerAssists: assists,
        careerCleanSheets: cleanSheets,
        careerAverageRating: avgRating > 0 ? avgRating : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            // Slot number badge
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isStarter
                    ? AppPalette.gold.withValues(alpha: 0.15)
                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isStarter ? AppPalette.gold.withValues(alpha: 0.5) : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Text(
                isStarter ? '${index + 1}' : 'S${index - 10}',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: isStarter ? AppPalette.gold : inkMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),

            PlayerAvatar(name: player.name, size: 28),
            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          player.name,
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 13,
                            fontWeight: isStarter ? FontWeight.w700 : FontWeight.w500,
                            color: ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      PositionBadge(position: player.primaryPosition),
                      if (squadEvent != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: squadEvent.badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: squadEvent.badgeColor.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(squadEvent.iconData, size: 9, color: squadEvent.badgeColor),
                              const SizedBox(width: 3),
                              Text(
                                squadEvent.badgeLabel,
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: squadEvent.badgeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if ((player.age?.round() ?? 25) <= 23 && (player.potential?.round() ?? 0) > player.overall) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppPalette.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: AppPalette.green.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            'POT ${(player.potential?.round() ?? 0)}',
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.green,
                            ),
                          ),
                        ),
                      ] else if ((player.age?.round() ?? 25) >= 33) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppPalette.coral.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: AppPalette.coral.withValues(alpha: 0.35)),
                          ),
                          child: const Text(
                            '33+ VET',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.coral,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _promptRenewContract(player),
                        borderRadius: BorderRadius.circular(3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: (_playerContracts[player.name] ?? 3) <= 1
                                ? AppPalette.warn.withValues(alpha: 0.18)
                                : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: (_playerContracts[player.name] ?? 3) <= 1
                                  ? AppPalette.warn.withValues(alpha: 0.6)
                                  : (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if ((_playerContracts[player.name] ?? 3) <= 1) ...[
                                const Icon(Icons.hourglass_bottom_rounded, size: 8.5, color: AppPalette.warn),
                                const SizedBox(width: 2),
                              ],
                              Text(
                                (_playerContracts[player.name] ?? 3) <= 1
                                    ? '1 YR LEFT'
                                    : '${_playerContracts[player.name] ?? 3}Y CONTRACT',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: (_playerContracts[player.name] ?? 3) <= 1 ? AppPalette.warn : inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Age ${player.age?.toInt() ?? 25} • $statSummary',
                    style: AppTypography.caption(inkMuted).copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),

            // Rating badge
            StatBadge(value: player.overall, label: ''),
            const SizedBox(width: 4),

            // Contract Renewal Action
            IconButton(
              icon: Icon(
                (_playerContracts[player.name] ?? 3) <= 1
                    ? Icons.hourglass_bottom_rounded
                    : Icons.history_edu_rounded,
                size: 16,
              ),
              tooltip: 'Renew Contract (+3 Yrs)',
              visualDensity: VisualDensity.compact,
              color: (_playerContracts[player.name] ?? 3) <= 1 ? AppPalette.warn : AppPalette.gold,
              onPressed: () => _promptRenewContract(player),
            ),

            // Tactical Swap Action
            IconButton(
              icon: const Icon(Icons.swap_vert_rounded, size: 18),
              tooltip: 'Swap Position',
              visualDensity: VisualDensity.compact,
              color: AppPalette.gold,
              onPressed: () => _openSwapSheet(index),
            ),

            // Sell Action
            IconButton(
              icon: const Icon(Icons.currency_pound_rounded, size: 16),
              tooltip: 'Sell Player (+£${calculatePlayerSalePrice(player)}M)',
              visualDensity: VisualDensity.compact,
              color: AppPalette.green,
              onPressed: () => _sellPlayer(player, index),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a dedicated upcoming fixture preview card with venue and kick-off button (Issue #12)
  Widget _buildNextFixtureCard({
    required LeagueDefinition activeLeague,
    required bool isDark,
    required Color ink,
    required Color inkMuted,
  }) {
    final fixture = _nextUserFixture;
    if (fixture == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_rounded, color: AppPalette.gold, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CAMPAIGN COMPLETE',
                    style: AppTypography.sectionHeader(AppPalette.gold),
                  ),
                  Text(
                    'All $_totalGameweeks matchdays concluded. Review final standings and advance.',
                    style: AppTypography.bodySmall(inkMuted),
                  ),
                ],
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.gold,
                foregroundColor: Colors.black,
              ),
              onPressed: _advanceSeason,
              child: const Text('Season Review', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    final isHome = fixture.homeClub == _userClub;
    final homeCode = fixture.homeClub == _userClub
        ? _userClubCode
        : (activeLeague.clubCodes[fixture.homeClub] ??
            fixture.homeClub.substring(0, min(3, fixture.homeClub.length)).toUpperCase());
    final awayCode = fixture.awayClub == _userClub
        ? _userClubCode
        : (activeLeague.clubCodes[fixture.awayClub] ??
            fixture.awayClub.substring(0, min(3, fixture.awayClub.length)).toUpperCase());
    final opponentCode = isHome ? awayCode : homeCode;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppPalette.gold.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.stadium_rounded, size: 14, color: AppPalette.gold),
                  const SizedBox(width: 5),
                  Text(
                    'NEXT FIXTURE • GW $_currentGameweek OF $_totalGameweeks',
                    style: AppTypography.caption(AppPalette.gold).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isHome ? AppPalette.green.withValues(alpha: 0.15) : AppPalette.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isHome ? 'HOME' : 'AWAY',
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isHome ? AppPalette.green : AppPalette.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Home team
              Expanded(
                child: Row(
                  children: [
                    ClubBadge(code: homeCode, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fixture.homeClub,
                            style: AppTypography.bodyMedium(ink).copyWith(
                              fontWeight: fixture.homeClub == _userClub ? FontWeight.w800 : FontWeight.w600,
                              color: fixture.homeClub == _userClub ? AppPalette.gold : ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (fixture.homeClub == _userClub)
                            Text('YOUR CLUB', style: AppTypography.caption(AppPalette.gold).copyWith(fontSize: 9)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // VS separator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'VS',
                  style: AppTypography.caption(inkMuted).copyWith(fontWeight: FontWeight.w800, fontSize: 10),
                ),
              ),
              // Away team
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            fixture.awayClub,
                            style: AppTypography.bodyMedium(ink).copyWith(
                              fontWeight: fixture.awayClub == _userClub ? FontWeight.w800 : FontWeight.w600,
                              color: fixture.awayClub == _userClub ? AppPalette.gold : ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                          if (fixture.awayClub == _userClub)
                            Text('YOUR CLUB', style: AppTypography.caption(AppPalette.gold).copyWith(fontSize: 9)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ClubBadge(code: awayCode, size: 28),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _simMatchday,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text('Kick Off vs $opponentCode (Gameweek $_currentGameweek)'),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.gold,
                foregroundColor: isDark ? AppPalette.darkBg : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openScheduleSheet,
              icon: const Icon(Icons.calendar_month_rounded, size: 16),
              label: const Text('VIEW FULL CALENDAR & FIXTURES'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.gold,
                side: BorderSide(color: AppPalette.gold.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 9),
                textStyle: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds an editorial matchday result tile with club badges, scoreline, and goal events with minute timestamps (Issue #7)
  Widget _buildMatchResultTile({
    required MatchResult m,
    required bool isDark,
    required Color ink,
    required Color inkMuted,
    required LeagueDefinition activeLeague,
    String competitionName = 'PREMIER LEAGUE',
  }) {
    final isUserMatch = m.homeClub == _userClub || m.awayClub == _userClub;
    final homeCode = m.homeClub == _userClub
        ? _userClubCode
        : (activeLeague.clubCodes[m.homeClub] ?? m.homeClub.substring(0, min(3, m.homeClub.length)).toUpperCase());
    final awayCode = m.awayClub == _userClub
        ? _userClubCode
        : (activeLeague.clubCodes[m.awayClub] ?? m.awayClub.substring(0, min(3, m.awayClub.length)).toUpperCase());

    // User result status indicator
    String? userOutcome;
    Color? outcomeColor;
    if (isUserMatch) {
      final userGoals = m.homeClub == _userClub ? m.homeGoals : m.awayGoals;
      final oppGoals = m.homeClub == _userClub ? m.awayGoals : m.homeGoals;
      if (userGoals > oppGoals) {
        userOutcome = 'VICTORY';
        outcomeColor = AppPalette.green;
      } else if (userGoals == oppGoals) {
        userOutcome = 'DRAW';
        outcomeColor = AppPalette.gold;
      } else {
        userOutcome = 'DEFEAT';
        outcomeColor = AppPalette.red;
      }
    }

    final tileBg = isUserMatch
        ? (isDark ? AppPalette.gold.withValues(alpha: 0.08) : AppPalette.gold.withValues(alpha: 0.12))
        : (isDark ? AppPalette.darkCard : AppPalette.lightCard);

    final borderColor = isUserMatch
        ? AppPalette.gold.withValues(alpha: 0.55)
        : Theme.of(context).dividerColor.withValues(alpha: 0.35);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => MatchDetailSheet.show(context, m, competitionName: competitionName),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: isUserMatch ? 1.5 : 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header badge for User Match (Fix 23 / User Fix 1)
              if (isUserMatch) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 15, color: AppPalette.gold),
                        const SizedBox(width: 5),
                        Text(
                          'YOUR CLUB FIXTURE • FEATURED MATCH',
                          style: AppTypography.caption(AppPalette.gold).copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: outcomeColor?.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: (outcomeColor ?? AppPalette.gold).withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        userOutcome ?? '',
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: outcomeColor,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Match Scoreline Row
              Row(
                children: [
                  // Home Club Name + Badge
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            m.homeClub,
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 13,
                              fontWeight: m.homeClub == _userClub ? FontWeight.w800 : FontWeight.w600,
                              color: m.homeClub == _userClub ? (isDark ? Colors.white : Colors.black) : ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ClubBadge(code: homeCode, size: 22),
                      ],
                    ),
                  ),

                  // Score Box
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isUserMatch
                          ? AppPalette.gold.withValues(alpha: 0.2)
                          : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${m.homeGoals}  –  ${m.awayGoals}',
                      style: AppTypography.statNumber(
                        isUserMatch ? AppPalette.gold : ink,
                        fontSize: 14,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),

                  // Away Club Badge + Name
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        ClubBadge(code: awayCode, size: 22),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            m.awayClub,
                            textAlign: TextAlign.start,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 13,
                              fontWeight: m.awayClub == _userClub ? FontWeight.w800 : FontWeight.w600,
                              color: m.awayClub == _userClub ? (isDark ? Colors.white : Colors.black) : ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Goal Scorers and Minute Timestamps Row
              const SizedBox(height: 8),
              if (m.homeGoalEvents.isEmpty && m.awayGoalEvents.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'No goals',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption(inkMuted).copyWith(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Home Scorers Column (Right-aligned)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: m.homeGoalEvents.map((g) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1.5),
                            child: Text(
                              '⚽ ${g.formatted}',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                fontSize: 10.5,
                                fontWeight: m.homeClub == _userClub ? FontWeight.w700 : FontWeight.w500,
                                color: m.homeClub == _userClub ? AppPalette.gold : inkMuted,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Center spacer aligning with the score box
                    const SizedBox(width: 50),

                    // Away Scorers Column (Left-aligned)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: m.awayGoalEvents.map((g) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1.5),
                            child: Text(
                              '⚽ ${g.formatted}',
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                fontSize: 10.5,
                                fontWeight: m.awayClub == _userClub ? FontWeight.w700 : FontWeight.w500,
                                color: m.awayClub == _userClub ? AppPalette.gold : inkMuted,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'TAP FOR MATCH REPORT & RATINGS',
                    style: AppTypography.caption(AppPalette.gold.withValues(alpha: 0.8)).copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, size: 8, color: AppPalette.gold.withValues(alpha: 0.8)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the cumulative league-wide team stats leaderboard (Issue #7 & Fix 22)
  Widget _buildTeamStatsTable(bool isDark, Color ink, Color inkMuted, LeagueDefinition activeLeague) {
    // 1. Compile stats for all league clubs
    final List<ClubTeamStats> statsList = [];
    for (final club in _leagueClubs) {
      final t = _leagueTable.where((entry) => entry.clubName == club).firstOrNull;
      final code = activeLeague.clubCodes[club] ??
          (club == _userClub ? _userClubCode : (club.length >= 3 ? club.substring(0, 3).toUpperCase() : club.toUpperCase()));
      final played = t?.played ?? 0;
      final won = t?.won ?? 0;
      final drawn = t?.drawn ?? 0;
      final lost = t?.lost ?? 0;
      final gf = t?.goalsFor ?? 0;
      final ga = t?.goalsAgainst ?? 0;
      final gd = t?.goalDifference ?? 0;
      final cs = _leagueClubCleanSheets[club] ?? 0;
      final rating = getClubAverageRating(club);
      final pts = t?.points ?? 0;

      statsList.add(ClubTeamStats(
        clubName: club,
        clubCode: code,
        played: played,
        won: won,
        drawn: drawn,
        lost: lost,
        goalsFor: gf,
        goalsAgainst: ga,
        goalDifference: gd,
        cleanSheets: cs,
        avgRating: rating,
        points: pts,
      ));
    }

    if (statsList.every((s) => s.played == 0)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.analytics_rounded, size: 36, color: AppPalette.gold),
            const SizedBox(height: 8),
            Text('No Team Statistics Yet', style: AppTypography.titleMedium(ink)),
            const SizedBox(height: 4),
            Text(
              'Simulate matchdays to track cumulative goals scored, goals conceded, clean sheets, and average match ratings.',
              textAlign: TextAlign.center,
              style: AppTypography.caption(inkMuted),
            ),
          ],
        ),
      );
    }

    // 2. Sort according to _teamStatsSortIndex
    statsList.sort((a, b) {
      switch (_teamStatsSortIndex) {
        case 0: // Attack (GF)
          if (b.goalsFor != a.goalsFor) return b.goalsFor.compareTo(a.goalsFor);
          if (b.goalDifference != a.goalDifference) return b.goalDifference.compareTo(a.goalDifference);
          return b.points.compareTo(a.points);
        case 1: // Defense (GA - lowest conceded first)
          if (a.played > 0 && b.played > 0) {
            if (a.goalsAgainst != b.goalsAgainst) return a.goalsAgainst.compareTo(b.goalsAgainst);
            if (b.cleanSheets != a.cleanSheets) return b.cleanSheets.compareTo(a.cleanSheets);
          }
          return b.points.compareTo(a.points);
        case 2: // Clean Sheets
          if (b.cleanSheets != a.cleanSheets) return b.cleanSheets.compareTo(a.cleanSheets);
          if (a.goalsAgainst != b.goalsAgainst) return a.goalsAgainst.compareTo(b.goalsAgainst);
          return b.points.compareTo(a.points);
        case 3: // Team Rating
          if (b.avgRating != a.avgRating) return b.avgRating.compareTo(a.avgRating);
          if (b.points != a.points) return b.points.compareTo(a.points);
          return b.goalDifference.compareTo(a.goalDifference);
        case 4: // Goal Difference
          if (b.goalDifference != a.goalDifference) return b.goalDifference.compareTo(a.goalDifference);
          if (b.goalsFor != a.goalsFor) return b.goalsFor.compareTo(a.goalsFor);
          return b.points.compareTo(a.points);
        default:
          return b.points.compareTo(a.points);
      }
    });

    // 3. Leaders for podium highlights
    final playedClubs = statsList.where((s) => s.played > 0).toList();
    final topAttack = playedClubs.isNotEmpty ? (List<ClubTeamStats>.from(playedClubs)..sort((a, b) => b.goalsFor.compareTo(a.goalsFor))).first : null;
    final bestDefense = playedClubs.isNotEmpty ? (List<ClubTeamStats>.from(playedClubs)..sort((a, b) => a.goalsAgainst.compareTo(b.goalsAgainst))).first : null;
    final mostCleanSheets = playedClubs.isNotEmpty ? (List<ClubTeamStats>.from(playedClubs)..sort((a, b) => b.cleanSheets.compareTo(a.cleanSheets))).first : null;
    final highestRated = playedClubs.isNotEmpty ? (List<ClubTeamStats>.from(playedClubs)..sort((a, b) => b.avgRating.compareTo(a.avgRating))).first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Category Podium Highlights (if matches played)
        if (topAttack != null && bestDefense != null && mostCleanSheets != null && highestRated != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppPalette.gold.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, size: 14, color: AppPalette.gold),
                    const SizedBox(width: 6),
                    Text(
                      'SEASON LEADERS • CATEGORY KINGS',
                      style: AppTypography.caption(AppPalette.gold).copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildLeaderPill(
                        icon: Icons.sports_soccer_rounded,
                        title: 'TOP ATTACK',
                        club: topAttack.clubName,
                        stat: '${topAttack.goalsFor} Goals',
                        isDark: isDark,
                        ink: ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildLeaderPill(
                        icon: Icons.shield_rounded,
                        title: 'BEST DEFENSE',
                        club: bestDefense.clubName,
                        stat: '${bestDefense.goalsAgainst} Conceded',
                        isDark: isDark,
                        ink: ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _buildLeaderPill(
                        icon: Icons.dry_cleaning_rounded,
                        title: 'CLEAN SHEETS',
                        club: mostCleanSheets.clubName,
                        stat: '${mostCleanSheets.cleanSheets} Shutouts',
                        isDark: isDark,
                        ink: ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildLeaderPill(
                        icon: Icons.star_rounded,
                        title: 'HIGHEST RATED',
                        club: highestRated.clubName,
                        stat: '★ ${highestRated.avgRating.toStringAsFixed(2)}',
                        isDark: isDark,
                        ink: ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        // Sort Metric Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              _buildSortChip(0, '⚽ Attack (GF)', isDark),
              const SizedBox(width: 6),
              _buildSortChip(1, '🛡️ Defense (GA)', isDark),
              const SizedBox(width: 6),
              _buildSortChip(2, '🧤 Clean Sheets', isDark),
              const SizedBox(width: 6),
              _buildSortChip(3, '⭐ Rating (AVG)', isDark),
              const SizedBox(width: 6),
              _buildSortChip(4, '📊 Goal Diff', isDark),
            ],
          ),
        ),

        // Team Stats Data Table
        Table(
          columnWidths: const {
            0: FlexColumnWidth(0.7), // Rank
            1: FlexColumnWidth(3.0), // Club
            2: FlexColumnWidth(0.7), // P
            3: FlexColumnWidth(0.9), // GF
            4: FlexColumnWidth(0.9), // GA
            5: FlexColumnWidth(0.8), // CS
            6: FlexColumnWidth(1.2), // AVG ★
            7: FlexColumnWidth(0.9), // GD
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                _headerCell('#', inkMuted),
                _headerCell('CLUB', inkMuted, align: TextAlign.left),
                _headerCell('P', inkMuted),
                _headerCell('GF', _teamStatsSortIndex == 0 ? AppPalette.gold : inkMuted),
                _headerCell('GA', _teamStatsSortIndex == 1 ? AppPalette.gold : inkMuted),
                _headerCell('CS', _teamStatsSortIndex == 2 ? AppPalette.gold : inkMuted),
                _headerCell('AVG★', _teamStatsSortIndex == 3 ? AppPalette.gold : inkMuted),
                _headerCell('GD', _teamStatsSortIndex == 4 ? AppPalette.gold : inkMuted),
              ],
            ),
            ...List.generate(statsList.length, (idx) {
              final item = statsList[idx];
              final isUser = item.clubName == _userClub;
              final rowInk = isUser ? (isDark ? Colors.white : Colors.black) : ink;

              final rowColor = isUser
                  ? AppPalette.gold.withValues(alpha: 0.12)
                  : (idx % 2 == 1
                      ? (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02))
                      : null);

              Widget rankWidget;
              if (idx == 0) {
                rankWidget = const Center(child: Text('🥇', style: TextStyle(fontSize: 13)));
              } else if (idx == 1) {
                rankWidget = const Center(child: Text('🥈', style: TextStyle(fontSize: 13)));
              } else if (idx == 2) {
                rankWidget = const Center(child: Text('🥉', style: TextStyle(fontSize: 13)));
              } else {
                rankWidget = _cell('${idx + 1}', inkMuted);
              }

              return TableRow(
                decoration: rowColor != null ? BoxDecoration(color: rowColor, borderRadius: BorderRadius.circular(4)) : null,
                children: [
                  rankWidget,
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        ClubBadge(code: item.clubCode, size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item.clubName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              fontWeight: isUser ? FontWeight.w800 : FontWeight.w600,
                              color: isUser ? AppPalette.gold : rowInk,
                            ),
                          ),
                        ),
                        if (isUser) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.star_rounded, size: 12, color: AppPalette.gold),
                        ],
                      ],
                    ),
                  ),
                  _cell('${item.played}', inkMuted),
                  _cell('${item.goalsFor}', _teamStatsSortIndex == 0 ? AppPalette.gold : rowInk, isBold: _teamStatsSortIndex == 0),
                  _cell('${item.goalsAgainst}', _teamStatsSortIndex == 1 ? AppPalette.gold : rowInk, isBold: _teamStatsSortIndex == 1),
                  _cell('${item.cleanSheets}', _teamStatsSortIndex == 2 ? AppPalette.gold : rowInk, isBold: _teamStatsSortIndex == 2),
                  _cell(item.avgRating.toStringAsFixed(2), _teamStatsSortIndex == 3 ? AppPalette.gold : rowInk, isBold: _teamStatsSortIndex == 3),
                  _cell('${item.goalDifference >= 0 ? "+" : ""}${item.goalDifference}', _teamStatsSortIndex == 4 ? AppPalette.gold : inkMuted, isBold: _teamStatsSortIndex == 4),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildSortChip(int index, String label, bool isDark) {
    final isSelected = _teamStatsSortIndex == index;
    return InkWell(
      onTap: () => setState(() => _teamStatsSortIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppPalette.gold.withValues(alpha: 0.2)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppPalette.gold : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppPalette.gold : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderPill({
    required IconData icon,
    required String title,
    required String club,
    required String stat,
    required bool isDark,
    required Color ink,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppPalette.gold),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.gold,
                  ),
                ),
                Text(
                  club,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  stat,
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the Golden Boot top scorers leaderboard (Issue #8)
  Widget _buildGoldenBootTable(bool isDark, Color ink, Color inkMuted, LeagueDefinition activeLeague) {
    final entries = _leaguePlayerGoals.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.sports_soccer_rounded, size: 36, color: AppPalette.gold),
            const SizedBox(height: 8),
            Text(
              'No Goals Scored Yet',
              style: AppTypography.titleMedium(ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Simulate matchdays to begin tracking league top scorers and the Golden Boot race.',
              textAlign: TextAlign.center,
              style: AppTypography.caption(inkMuted),
            ),
          ],
        ),
      );
    }

    final topScorers = entries.take(10).toList();

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(0.7), // Rank
        1: FlexColumnWidth(3.2), // Player Name
        2: FlexColumnWidth(2.2), // Club
        3: FlexColumnWidth(1.0), // Goals
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _headerCell('#', inkMuted),
            _headerCell('PLAYER', inkMuted, align: TextAlign.left),
            _headerCell('CLUB', inkMuted, align: TextAlign.left),
            _headerCell('GLS', inkMuted),
          ],
        ),
        ...List.generate(topScorers.length, (idx) {
          final scorer = topScorers[idx];
          final playerName = scorer.key;
          final goals = scorer.value;
          final clubName = _leaguePlayerClubs[playerName] ?? '';
          final isUserPlayer = _userSquad.any((p) => p.name == playerName);
          final clubCode = activeLeague.clubCodes[clubName] ??
              (clubName == _userClub ? _userClubCode : (clubName.length >= 3 ? clubName.substring(0, 3).toUpperCase() : clubName.toUpperCase()));

          final rowColor = isUserPlayer
              ? AppPalette.gold.withValues(alpha: 0.1)
              : (idx % 2 == 1
                  ? (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02))
                  : null);

          // Medal styling for top 3
          Widget rankWidget;
          if (idx == 0) {
            rankWidget = const Center(
              child: Text('🥇', style: TextStyle(fontSize: 14)),
            );
          } else if (idx == 1) {
            rankWidget = const Center(
              child: Text('🥈', style: TextStyle(fontSize: 14)),
            );
          } else if (idx == 2) {
            rankWidget = const Center(
              child: Text('🥉', style: TextStyle(fontSize: 14)),
            );
          } else {
            rankWidget = _cell('${idx + 1}', inkMuted);
          }

          return TableRow(
            decoration: rowColor != null ? BoxDecoration(color: rowColor, borderRadius: BorderRadius.circular(4)) : null,
            children: [
              rankWidget,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        playerName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12.5,
                          fontWeight: isUserPlayer ? FontWeight.w800 : FontWeight.w600,
                          color: isUserPlayer ? AppPalette.gold : ink,
                        ),
                      ),
                    ),
                    if (isUserPlayer) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded, size: 13, color: AppPalette.gold),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    ClubBadge(code: clubCode, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        clubName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _cell('$goals', isUserPlayer ? AppPalette.gold : ink, isBold: true),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildStandingsTabButton({
    required int tabIndex,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color ink,
    required Color inkMuted,
  }) {
    final isSelected = _standingsTab == tabIndex;
    return InkWell(
      onTap: () => setState(() => _standingsTab = tabIndex),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? AppPalette.gold : inkMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? (isDark ? Colors.white : Colors.black) : inkMuted,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCompTabButton({
    required int tabIndex,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color ink,
    required Color inkMuted,
    bool isUcl = false,
  }) {
    final isSelected = _resultsCompTab == tabIndex;
    return InkWell(
      onTap: () => setState(() => _resultsCompTab = tabIndex),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4)]
              : null,
          border: isSelected && isUcl
              ? Border.all(color: AppPalette.gold.withValues(alpha: 0.5), width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? (isUcl ? AppPalette.gold : AppPalette.darkAccent) : inkMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? (isDark ? Colors.white : Colors.black) : inkMuted,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the Playmaker top assists leaderboard (Issue #7 & #8)
  Widget _buildAssistsTable(bool isDark, Color ink, Color inkMuted, LeagueDefinition activeLeague) {
    final entries = _leaguePlayerAssists.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 36, color: AppPalette.gold),
            const SizedBox(height: 8),
            Text('No Assists Recorded Yet', style: AppTypography.titleMedium(ink)),
            const SizedBox(height: 4),
            Text('Playmakers will appear here as goals are created.', style: AppTypography.caption(inkMuted)),
          ],
        ),
      );
    }

    final topAssisters = entries.take(10).toList();

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(0.7),
        1: FlexColumnWidth(3.2),
        2: FlexColumnWidth(2.2),
        3: FlexColumnWidth(1.0),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _headerCell('#', inkMuted),
            _headerCell('PLAYER', inkMuted, align: TextAlign.left),
            _headerCell('CLUB', inkMuted, align: TextAlign.left),
            _headerCell('AST', inkMuted),
          ],
        ),
        ...List.generate(topAssisters.length, (idx) {
          final item = topAssisters[idx];
          final playerName = item.key;
          final assists = item.value;
          final clubName = _leagueAssistClubs[playerName] ?? '';
          final isUserPlayer = _userSquad.any((p) => p.name == playerName);
          final clubCode = activeLeague.clubCodes[clubName] ??
              (clubName == _userClub ? _userClubCode : (clubName.length >= 3 ? clubName.substring(0, 3).toUpperCase() : clubName.toUpperCase()));

          final rowColor = isUserPlayer
              ? AppPalette.gold.withValues(alpha: 0.1)
              : (idx % 2 == 1
                  ? (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02))
                  : null);

          Widget rankWidget;
          if (idx == 0) {
            rankWidget = const Center(child: Text('🥇', style: TextStyle(fontSize: 14)));
          } else if (idx == 1) {
            rankWidget = const Center(child: Text('🥈', style: TextStyle(fontSize: 14)));
          } else if (idx == 2) {
            rankWidget = const Center(child: Text('🥉', style: TextStyle(fontSize: 14)));
          } else {
            rankWidget = _cell('${idx + 1}', inkMuted);
          }

          return TableRow(
            decoration: rowColor != null ? BoxDecoration(color: rowColor, borderRadius: BorderRadius.circular(4)) : null,
            children: [
              rankWidget,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        playerName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12.5,
                          fontWeight: isUserPlayer ? FontWeight.w800 : FontWeight.w600,
                          color: isUserPlayer ? AppPalette.gold : ink,
                        ),
                      ),
                    ),
                    if (isUserPlayer) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded, size: 13, color: AppPalette.gold),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    ClubBadge(code: clubCode, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        clubName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _cell('$assists', isUserPlayer ? AppPalette.gold : ink, isBold: true),
            ],
          );
        }),
      ],
    );
  }

  /// Builds the Clean Sheets club shutouts leaderboard (Issue #8)
  Widget _buildCleanSheetsTable(bool isDark, Color ink, Color inkMuted, LeagueDefinition activeLeague) {
    final entries = _leagueClubCleanSheets.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.shield_rounded, size: 36, color: AppPalette.gold),
            const SizedBox(height: 8),
            Text('No Clean Sheets Yet', style: AppTypography.titleMedium(ink)),
            const SizedBox(height: 4),
            Text('Defensive records will update as clubs record shutouts.', style: AppTypography.caption(inkMuted)),
          ],
        ),
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(0.7),
        1: FlexColumnWidth(4.5),
        2: FlexColumnWidth(1.2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _headerCell('#', inkMuted),
            _headerCell('CLUB', inkMuted, align: TextAlign.left),
            _headerCell('CS', inkMuted),
          ],
        ),
        ...List.generate(entries.length, (idx) {
          final item = entries[idx];
          final clubName = item.key;
          final cleanSheets = item.value;
          final isUser = clubName == _userClub;
          final clubCode = activeLeague.clubCodes[clubName] ??
              (clubName == _userClub ? _userClubCode : (clubName.length >= 3 ? clubName.substring(0, 3).toUpperCase() : clubName.toUpperCase()));

          final rowColor = isUser
              ? AppPalette.gold.withValues(alpha: 0.1)
              : (idx % 2 == 1
                  ? (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02))
                  : null);

          Widget rankWidget;
          if (idx == 0) {
            rankWidget = const Center(child: Text('🥇', style: TextStyle(fontSize: 14)));
          } else if (idx == 1) {
            rankWidget = const Center(child: Text('🥈', style: TextStyle(fontSize: 14)));
          } else if (idx == 2) {
            rankWidget = const Center(child: Text('🥉', style: TextStyle(fontSize: 14)));
          } else {
            rankWidget = _cell('${idx + 1}', inkMuted);
          }

          return TableRow(
            decoration: rowColor != null ? BoxDecoration(color: rowColor, borderRadius: BorderRadius.circular(4)) : null,
            children: [
              rankWidget,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    ClubBadge(code: clubCode, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        clubName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12.5,
                          fontWeight: isUser ? FontWeight.w800 : FontWeight.w600,
                          color: isUser ? AppPalette.gold : ink,
                        ),
                      ),
                    ),
                    if (isUser) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded, size: 13, color: AppPalette.gold),
                    ],
                  ],
                ),
              ),
              _cell('$cleanSheets', isUser ? AppPalette.gold : ink, isBold: true),
            ],
          );
        }),
      ],
    );
  }

  /// Builds the full UEFA Champions League standings, bracket, and scorers view (Issue #3)
  Widget _buildUclStandings(bool isDark, Color ink, Color inkMuted, LeagueDefinition activeLeague) {
    if (_uclTournament == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.emoji_events_rounded, size: 36, color: AppPalette.gold),
            const SizedBox(height: 8),
            Text('UEFA Champions League 2026/27', style: AppTypography.titleMedium(ink)),
            const SizedBox(height: 4),
            Text('Tournament has not been initialized for this career.', style: AppTypography.caption(inkMuted)),
          ],
        ),
      );
    }

    final ucl = _uclTournament!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Champion banner if tournament completed
        if (ucl.champion != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppPalette.gold.withValues(alpha: 0.25), const Color(0xFF1E3A4C).withValues(alpha: 0.35)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppPalette.gold, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: AppPalette.gold, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UCL 2026/27 CHAMPIONS',
                        style: AppTypography.caption(AppPalette.gold).copyWith(fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                      Text(
                        ucl.champion!,
                        style: AppTypography.titleMedium(ink).copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Sub-tabs: 0: GROUPS, 1: KNOCKOUTS, 2: SCORELINES, 3: SCORERS, 4: ASSISTS, 5: CLEAN SHEETS
        Container(
          padding: const EdgeInsets.all(2),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildUclSubTab(0, 'GROUPS', isDark, ink, inkMuted),
                const SizedBox(width: 4),
                _buildUclSubTab(1, 'KNOCKOUTS', isDark, ink, inkMuted),
                const SizedBox(width: 4),
                _buildUclSubTab(2, 'SCORELINES', isDark, ink, inkMuted),
                const SizedBox(width: 4),
                _buildUclSubTab(3, 'SCORERS', isDark, ink, inkMuted),
                const SizedBox(width: 4),
                _buildUclSubTab(4, 'ASSISTS', isDark, ink, inkMuted),
                const SizedBox(width: 4),
                _buildUclSubTab(5, 'CLEAN SHEETS', isDark, ink, inkMuted),
              ],
            ),
          ),
        ),

        if (_uclViewTab == 0)
          _buildUclGroupsView(ucl, isDark, ink, inkMuted, activeLeague)
        else if (_uclViewTab == 1)
          _buildUclKnockoutsView(ucl, isDark, ink, inkMuted)
        else if (_uclViewTab == 2)
          _buildUclScorelinesView(ucl, isDark, ink, inkMuted, activeLeague)
        else if (_uclViewTab == 3)
          _buildUclScorersView(ucl, isDark, ink, inkMuted)
        else if (_uclViewTab == 4)
          _buildUclAssistsView(ucl, isDark, ink, inkMuted)
        else
          _buildUclCleanSheetsView(ucl, isDark, ink, inkMuted),
      ],
    );
  }

  Widget _buildUclSubTab(int tabIndex, String label, bool isDark, Color ink, Color inkMuted) {
    final isSelected = _uclViewTab == tabIndex;
    return InkWell(
      onTap: () => setState(() => _uclViewTab = tabIndex),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 3)]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppPalette.gold : inkMuted,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildUclGroupsView(UclTournament ucl, bool isDark, Color ink, Color inkMuted, LeagueDefinition activeLeague) {
    return Column(
      children: ['A', 'B', 'C', 'D'].map((g) {
        final table = ucl.groupTables[g] ?? [];
        final sorted = List<TableEntry>.from(table)
          ..sort((a, b) {
            if (b.points != a.points) return b.points.compareTo(a.points);
            if (b.goalDifference != a.goalDifference) return b.goalDifference.compareTo(a.goalDifference);
            return b.goalsFor.compareTo(a.goalsFor);
          });

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A4C).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 12, color: AppPalette.gold),
                    const SizedBox(width: 6),
                    Text(
                      'GROUP $g',
                      style: AppTypography.caption(AppPalette.gold).copyWith(fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                    const Spacer(),
                    Text('Top 2 Advance to QF', style: AppTypography.caption(inkMuted).copyWith(fontSize: 9.5)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(0.6),
                  1: FlexColumnWidth(3.0),
                  2: FlexColumnWidth(0.8),
                  3: FlexColumnWidth(0.8),
                  4: FlexColumnWidth(0.8),
                  5: FlexColumnWidth(0.8),
                  6: FlexColumnWidth(1.0),
                  7: FlexColumnWidth(1.1),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    children: [
                      _headerCell('#', inkMuted),
                      _headerCell('CLUB', inkMuted, align: TextAlign.left),
                      _headerCell('P', inkMuted),
                      _headerCell('W', inkMuted),
                      _headerCell('D', inkMuted),
                      _headerCell('L', inkMuted),
                      _headerCell('GD', inkMuted),
                      _headerCell('PTS', inkMuted),
                    ],
                  ),
                  ...List.generate(sorted.length, (idx) {
                    final t = sorted[idx];
                    final isUser = t.clubName == _userClub;
                    final qualifies = idx < 2;
                    final clubCode = activeLeague.clubCodes[t.clubName] ??
                        (t.clubName == _userClub ? _userClubCode : (t.clubName.length >= 3 ? t.clubName.substring(0, 3).toUpperCase() : t.clubName.toUpperCase()));

                    final rowColor = isUser
                        ? AppPalette.gold.withValues(alpha: 0.1)
                        : (qualifies
                            ? AppPalette.green.withValues(alpha: 0.04)
                            : null);

                    return TableRow(
                      decoration: rowColor != null ? BoxDecoration(color: rowColor, borderRadius: BorderRadius.circular(4)) : null,
                      children: [
                        _cell('${idx + 1}', qualifies ? AppPalette.green : inkMuted, isBold: qualifies),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              ClubBadge(code: clubCode, size: 16),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  t.clubName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 11.5,
                                    fontWeight: isUser ? FontWeight.w800 : (qualifies ? FontWeight.w600 : FontWeight.w500),
                                    color: isUser ? AppPalette.gold : ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _cell('${t.played}', ink),
                        _cell('${t.won}', ink),
                        _cell('${t.drawn}', ink),
                        _cell('${t.lost}', ink),
                        _cell('${t.goalDifference}', t.goalDifference > 0 ? AppPalette.green : (t.goalDifference < 0 ? AppPalette.red : ink)),
                        _cell('${t.points}', isUser ? AppPalette.gold : ink, isBold: true),
                      ],
                    );
                  }),
                ],
              ),

              // Group played match scorelines (Issue 2)
              Builder(
                builder: (context) {
                  final groupMatches = ucl.groupFixtures
                      .where((f) => f.stage == 'Group $g' && f.isPlayed)
                      .toList();
                  if (groupMatches.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GROUP $g RESULTS (${groupMatches.length} played)',
                          style: AppTypography.caption(AppPalette.gold).copyWith(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...groupMatches.map((f) {
                          final isUserMatch = f.homeClub == _userClub || f.awayClub == _userClub;
                          return InkWell(
                            onTap: () {
                              MatchDetailSheet.show(
                                context,
                                f.result!,
                                competitionName: 'UEFA CHAMPIONS LEAGUE • GROUP $g',
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: isUserMatch
                                    ? AppPalette.gold.withValues(alpha: 0.08)
                                    : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03)),
                                borderRadius: BorderRadius.circular(6),
                                border: isUserMatch
                                    ? Border.all(color: AppPalette.gold.withValues(alpha: 0.4), width: 1)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'MD${f.matchday}',
                                    style: AppTypography.caption(inkMuted).copyWith(fontSize: 9.5, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            f.homeClub,
                                            textAlign: TextAlign.end,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: AppTypography.fontFamily,
                                              fontSize: 11,
                                              fontWeight: f.homeClub == _userClub ? FontWeight.w800 : FontWeight.w500,
                                              color: f.homeClub == _userClub ? AppPalette.gold : ink,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${f.result!.homeGoals} - ${f.result!.awayGoals}',
                                            style: TextStyle(
                                              fontFamily: AppTypography.fontFamily,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: ink,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            f.awayClub,
                                            textAlign: TextAlign.start,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: AppTypography.fontFamily,
                                              fontSize: 11,
                                              fontWeight: f.awayClub == _userClub ? FontWeight.w800 : FontWeight.w500,
                                              color: f.awayClub == _userClub ? AppPalette.gold : ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, size: 14, color: inkMuted),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUclKnockoutsView(UclTournament ucl, bool isDark, Color ink, Color inkMuted) {
    if (ucl.quarterFinals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.account_tree_rounded, size: 36, color: AppPalette.gold),
            const SizedBox(height: 8),
            Text('Knockout Stage Awaits', style: AppTypography.titleMedium(ink)),
            const SizedBox(height: 4),
            Text('The Quarter-Finals draw will take place after Matchday 6 of the group stage.', textAlign: TextAlign.center, style: AppTypography.caption(inkMuted)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStageHeader('QUARTER-FINALS (2 LEGS)'),
        ...ucl.quarterFinals.map((t) => _buildKnockoutTieCard(t, isDark, ink, inkMuted)),

        if (ucl.semiFinals.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildStageHeader('SEMI-FINALS (2 LEGS)'),
          ...ucl.semiFinals.map((t) => _buildKnockoutTieCard(t, isDark, ink, inkMuted)),
        ],

        if (ucl.finalTie != null) ...[
          const SizedBox(height: 12),
          _buildStageHeader('CHAMPIONS LEAGUE FINAL'),
          _buildKnockoutTieCard(ucl.finalTie!, isDark, ink, inkMuted, isFinal: true),
        ],
      ],
    );
  }

  Widget _buildStageHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppPalette.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        title,
        style: AppTypography.caption(AppPalette.gold).copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildKnockoutTieCard(UclKnockoutTie tie, bool isDark, Color ink, Color inkMuted, {bool isFinal = false}) {
    final codeA = tie.clubA.length >= 3 ? tie.clubA.substring(0, 3).toUpperCase() : tie.clubA.toUpperCase();
    final codeB = tie.clubB.length >= 3 ? tie.clubB.substring(0, 3).toUpperCase() : tie.clubB.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tie.winner != null ? AppPalette.gold.withValues(alpha: 0.4) : Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    ClubBadge(code: codeA, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tie.clubA,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12,
                          fontWeight: tie.winner == tie.clubA ? FontWeight.w800 : FontWeight.w600,
                          color: tie.winner == tie.clubA ? AppPalette.gold : ink,
                        ),
                      ),
                    ),
                    if (tie.winner == tie.clubA) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.check_circle_rounded, size: 12, color: AppPalette.green),
                    ],
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tie.isCompleted ? '${tie.scoreA} - ${tie.scoreB}' : (isFinal ? 'FINAL' : 'AGG'),
                  style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 11, fontWeight: FontWeight.w800, color: ink),
                ),
              ),

              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (tie.winner == tie.clubB) ...[
                      const Icon(Icons.check_circle_rounded, size: 12, color: AppPalette.green),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        tie.clubB,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12,
                          fontWeight: tie.winner == tie.clubB ? FontWeight.w800 : FontWeight.w600,
                          color: tie.winner == tie.clubB ? AppPalette.gold : ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ClubBadge(code: codeB, size: 18),
                  ],
                ),
              ),
            ],
          ),
          if (!isFinal && tie.leg1.isPlayed) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () {
                MatchDetailSheet.show(
                  context,
                  tie.leg1.result!,
                  competitionName: 'UEFA CHAMPIONS LEAGUE • ${tie.stage} LEG 1',
                );
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Text(
                      'Leg 1: ${tie.leg1.homeClub} ${tie.leg1.result!.homeGoals}-${tie.leg1.result!.awayGoals} ${tie.leg1.awayClub}',
                      style: AppTypography.caption(ink).copyWith(fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, size: 14, color: inkMuted),
                  ],
                ),
              ),
            ),
            if (tie.leg2?.isPlayed == true) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: () {
                  MatchDetailSheet.show(
                    context,
                    tie.leg2!.result!,
                    competitionName: 'UEFA CHAMPIONS LEAGUE • ${tie.stage} LEG 2',
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Leg 2: ${tie.leg2!.homeClub} ${tie.leg2!.result!.homeGoals}-${tie.leg2!.result!.awayGoals} ${tie.leg2!.awayClub}',
                        style: AppTypography.caption(ink).copyWith(fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded, size: 14, color: inkMuted),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 2),
              Text('(Leg 2 pending)', style: AppTypography.caption(inkMuted).copyWith(fontSize: 9.5, fontStyle: FontStyle.italic)),
            ],
          ] else if (isFinal && tie.leg1.isPlayed) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () {
                MatchDetailSheet.show(
                  context,
                  tie.leg1.result!,
                  competitionName: 'UEFA CHAMPIONS LEAGUE FINAL',
                );
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Text(
                      'View Final Match Statistics & Events',
                      style: AppTypography.caption(AppPalette.gold).copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, size: 14, color: AppPalette.gold),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUclScorersView(UclTournament ucl, bool isDark, Color ink, Color inkMuted) {
    final entries = ucl.playerGoals.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.sports_soccer_rounded, size: 36, color: AppPalette.gold),
            const SizedBox(height: 8),
            Text('No Champions League Goals Yet', style: AppTypography.titleMedium(ink)),
            const SizedBox(height: 4),
            Text('Scorers will appear as UCL matchdays are simulated.', style: AppTypography.caption(inkMuted)),
          ],
        ),
      );
    }

    final topScorers = entries.take(10).toList();

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(0.7),
        1: FlexColumnWidth(3.2),
        2: FlexColumnWidth(2.2),
        3: FlexColumnWidth(1.0),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _headerCell('#', inkMuted),
            _headerCell('PLAYER', inkMuted, align: TextAlign.left),
            _headerCell('CLUB', inkMuted, align: TextAlign.left),
            _headerCell('GLS', inkMuted),
          ],
        ),
        ...List.generate(topScorers.length, (idx) {
          final scorer = topScorers[idx];
          final playerName = scorer.key;
          final goals = scorer.value;
          final clubName = ucl.playerClubs[playerName] ?? '';
          final isUserPlayer = _userSquad.any((p) => p.name == playerName);
          final clubCode = clubName.length >= 3 ? clubName.substring(0, 3).toUpperCase() : clubName.toUpperCase();

          Widget rankWidget;
          if (idx == 0) {
            rankWidget = const Center(child: Text('🥇', style: TextStyle(fontSize: 14)));
          } else if (idx == 1) {
            rankWidget = const Center(child: Text('🥈', style: TextStyle(fontSize: 14)));
          } else if (idx == 2) {
            rankWidget = const Center(child: Text('🥉', style: TextStyle(fontSize: 14)));
          } else {
            rankWidget = _cell('${idx + 1}', inkMuted);
          }

          return TableRow(
            decoration: isUserPlayer ? BoxDecoration(color: AppPalette.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)) : null,
            children: [
              rankWidget,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        playerName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12.5,
                          fontWeight: isUserPlayer ? FontWeight.w800 : FontWeight.w600,
                          color: isUserPlayer ? AppPalette.gold : ink,
                        ),
                      ),
                    ),
                    if (isUserPlayer) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded, size: 13, color: AppPalette.gold),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    ClubBadge(code: clubCode, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        clubName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _cell('$goals', isUserPlayer ? AppPalette.gold : ink, isBold: true),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildUclAssistsView(UclTournament ucl, bool isDark, Color ink, Color inkMuted) {
    final entries = ucl.playerAssists.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 36, color: AppPalette.gold),
            const SizedBox(height: 8),
            Text('No Champions League Assists Yet', style: AppTypography.titleMedium(ink)),
            const SizedBox(height: 4),
            Text('Playmakers will appear as UCL matchdays are simulated.', style: AppTypography.caption(inkMuted)),
          ],
        ),
      );
    }

    final topAssisters = entries.take(10).toList();

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(0.7),
        1: FlexColumnWidth(3.2),
        2: FlexColumnWidth(2.2),
        3: FlexColumnWidth(1.0),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _headerCell('#', inkMuted),
            _headerCell('PLAYER', inkMuted, align: TextAlign.left),
            _headerCell('CLUB', inkMuted, align: TextAlign.left),
            _headerCell('AST', inkMuted),
          ],
        ),
        ...List.generate(topAssisters.length, (idx) {
          final assister = topAssisters[idx];
          final playerName = assister.key;
          final assists = assister.value;
          final clubName = ucl.playerClubs[playerName] ?? '';
          final isUserPlayer = _userSquad.any((p) => p.name == playerName);
          final clubCode = clubName.length >= 3 ? clubName.substring(0, 3).toUpperCase() : clubName.toUpperCase();

          Widget rankWidget;
          if (idx == 0) {
            rankWidget = const Center(child: Text('🥇', style: TextStyle(fontSize: 14)));
          } else if (idx == 1) {
            rankWidget = const Center(child: Text('🥈', style: TextStyle(fontSize: 14)));
          } else if (idx == 2) {
            rankWidget = const Center(child: Text('🥉', style: TextStyle(fontSize: 14)));
          } else {
            rankWidget = _cell('${idx + 1}', inkMuted);
          }

          return TableRow(
            decoration: isUserPlayer ? BoxDecoration(color: AppPalette.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)) : null,
            children: [
              rankWidget,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        playerName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12.5,
                          fontWeight: isUserPlayer ? FontWeight.w800 : FontWeight.w600,
                          color: isUserPlayer ? AppPalette.gold : ink,
                        ),
                      ),
                    ),
                    if (isUserPlayer) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded, size: 13, color: AppPalette.gold),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    ClubBadge(code: clubCode, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        clubName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _cell('$assists', isUserPlayer ? AppPalette.gold : ink, isBold: true),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildUclCleanSheetsView(UclTournament ucl, bool isDark, Color ink, Color inkMuted) {
    final entries = ucl.playerCleanSheets.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.shield_rounded, size: 36, color: AppPalette.gold),
            const SizedBox(height: 8),
            Text('No Champions League Clean Sheets Yet', style: AppTypography.titleMedium(ink)),
            const SizedBox(height: 4),
            Text('Defensive shutouts will appear as UCL matchdays are simulated.', style: AppTypography.caption(inkMuted)),
          ],
        ),
      );
    }

    final topCleanSheets = entries.take(10).toList();

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(0.7),
        1: FlexColumnWidth(4.5),
        2: FlexColumnWidth(1.2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _headerCell('#', inkMuted),
            _headerCell('CLUB', inkMuted, align: TextAlign.left),
            _headerCell('CS', inkMuted),
          ],
        ),
        ...List.generate(topCleanSheets.length, (idx) {
          final item = topCleanSheets[idx];
          final clubName = item.key;
          final cleanSheets = item.value;
          final isUserClub = clubName == _userClub;
          final clubCode = clubName.length >= 3 ? clubName.substring(0, 3).toUpperCase() : clubName.toUpperCase();

          Widget rankWidget;
          if (idx == 0) {
            rankWidget = const Center(child: Text('🥇', style: TextStyle(fontSize: 14)));
          } else if (idx == 1) {
            rankWidget = const Center(child: Text('🥈', style: TextStyle(fontSize: 14)));
          } else if (idx == 2) {
            rankWidget = const Center(child: Text('🥉', style: TextStyle(fontSize: 14)));
          } else {
            rankWidget = _cell('${idx + 1}', inkMuted);
          }

          return TableRow(
            decoration: isUserClub ? BoxDecoration(color: AppPalette.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)) : null,
            children: [
              rankWidget,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    ClubBadge(code: clubCode, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        clubName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12.5,
                          fontWeight: isUserClub ? FontWeight.w800 : FontWeight.w600,
                          color: isUserClub ? AppPalette.gold : ink,
                        ),
                      ),
                    ),
                    if (isUserClub) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded, size: 13, color: AppPalette.gold),
                    ],
                  ],
                ),
              ),
              _cell('$cleanSheets', isUserClub ? AppPalette.gold : ink, isBold: true),
            ],
          );
        }),
      ],
    );
  }

  /// Builds the full chronological UCL scorelines view across all stages (Issue 2)
  Widget _buildUclScorelinesView(
    UclTournament ucl,
    bool isDark,
    Color ink,
    Color inkMuted,
    LeagueDefinition activeLeague,
  ) {
    // Collect all played matches from groups, QF, SF, Final
    final allPlayedGroup = ucl.groupFixtures.where((f) => f.isPlayed).toList();
    final allPlayedQf = <UclFixture>[];
    for (final tie in ucl.quarterFinals) {
      if (tie.leg1.isPlayed) allPlayedQf.add(tie.leg1);
      if (tie.leg2?.isPlayed == true) allPlayedQf.add(tie.leg2!);
    }
    final allPlayedSf = <UclFixture>[];
    for (final tie in ucl.semiFinals) {
      if (tie.leg1.isPlayed) allPlayedSf.add(tie.leg1);
      if (tie.leg2?.isPlayed == true) allPlayedSf.add(tie.leg2!);
    }
    final allPlayedFinal = <UclFixture>[];
    if (ucl.finalTie?.leg1.isPlayed == true) {
      allPlayedFinal.add(ucl.finalTie!.leg1);
    }

    final totalPlayed = allPlayedGroup.length + allPlayedQf.length + allPlayedSf.length + allPlayedFinal.length;
    if (totalPlayed == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.sports_soccer_rounded, size: 36, color: AppPalette.gold),
            const SizedBox(height: 8),
            Text('No UCL Matches Played Yet', style: AppTypography.titleMedium(ink)),
            const SizedBox(height: 4),
            Text(
              'European scorelines will appear here as UCL matchdays are simulated.',
              textAlign: TextAlign.center,
              style: AppTypography.caption(inkMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // If final played
        if (allPlayedFinal.isNotEmpty) ...[
          _buildStageHeader('CHAMPIONS LEAGUE FINAL'),
          ...allPlayedFinal.map((f) => _buildUclScorelineCard(
                f,
                isDark,
                ink,
                inkMuted,
                activeLeague,
                compLabel: 'FINAL',
              )),
          const SizedBox(height: 12),
        ],

        // If SF played
        if (allPlayedSf.isNotEmpty) ...[
          _buildStageHeader('SEMI-FINALS'),
          ...allPlayedSf.map((f) => _buildUclScorelineCard(
                f,
                isDark,
                ink,
                inkMuted,
                activeLeague,
                compLabel: 'SEMI-FINAL',
              )),
          const SizedBox(height: 12),
        ],

        // If QF played
        if (allPlayedQf.isNotEmpty) ...[
          _buildStageHeader('QUARTER-FINALS'),
          ...allPlayedQf.map((f) => _buildUclScorelineCard(
                f,
                isDark,
                ink,
                inkMuted,
                activeLeague,
                compLabel: 'QUARTER-FINAL',
              )),
          const SizedBox(height: 12),
        ],

        // Group Stage matchdays in reverse chronological order
        for (int md = 6; md >= 1; md--) ...[
          Builder(builder: (context) {
            final mdMatches = allPlayedGroup.where((f) => f.matchday == md).toList();
            if (mdMatches.isEmpty) return const SizedBox.shrink();

            // Pin user club match to top of this matchday
            final sortedMdMatches = List<UclFixture>.from(mdMatches)
              ..sort((a, b) {
                final aIsUser = a.homeClub == _userClub || a.awayClub == _userClub;
                final bIsUser = b.homeClub == _userClub || b.awayClub == _userClub;
                if (aIsUser && !bIsUser) return -1;
                if (!aIsUser && bIsUser) return 1;
                return a.id.compareTo(b.id);
              });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStageHeader('GROUP STAGE • MATCHDAY $md'),
                ...sortedMdMatches.map((f) => _buildUclScorelineCard(
                      f,
                      isDark,
                      ink,
                      inkMuted,
                      activeLeague,
                      compLabel: 'GROUP STAGE MD$md',
                    )),
                const SizedBox(height: 10),
              ],
            );
          }),
        ],
      ],
    );
  }

  Widget _buildUclScorelineCard(
    UclFixture f,
    bool isDark,
    Color ink,
    Color inkMuted,
    LeagueDefinition activeLeague, {
    required String compLabel,
  }) {
    final m = f.result;
    if (m == null) return const SizedBox.shrink();

    final isUserMatch = m.homeClub == _userClub || m.awayClub == _userClub;
    final homeCode = activeLeague.clubCodes[m.homeClub] ??
        (m.homeClub == _userClub
            ? _userClubCode
            : (m.homeClub.length >= 3 ? m.homeClub.substring(0, 3).toUpperCase() : m.homeClub.toUpperCase()));
    final awayCode = activeLeague.clubCodes[m.awayClub] ??
        (m.awayClub == _userClub
            ? _userClubCode
            : (m.awayClub.length >= 3 ? m.awayClub.substring(0, 3).toUpperCase() : m.awayClub.toUpperCase()));

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isUserMatch
            ? AppPalette.gold.withValues(alpha: 0.08)
            : (isDark ? AppPalette.darkCard : AppPalette.lightCard),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUserMatch
              ? AppPalette.gold.withValues(alpha: 0.6)
              : Theme.of(context).dividerColor.withValues(alpha: 0.4),
          width: isUserMatch ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          MatchDetailSheet.show(
            context,
            m,
            competitionName: 'UEFA CHAMPIONS LEAGUE • $compLabel',
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            children: [
              if (isUserMatch) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, size: 11, color: AppPalette.gold),
                    const SizedBox(width: 4),
                    Text(
                      'YOUR CLUB FIXTURE',
                      style: AppTypography.caption(AppPalette.gold).copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            m.homeClub,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              fontWeight: m.homeClub == _userClub ? FontWeight.w800 : FontWeight.w600,
                              color: m.homeClub == _userClub ? AppPalette.gold : ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ClubBadge(code: homeCode, size: 18),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${m.homeGoals} - ${m.awayGoals}',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: ink,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        ClubBadge(code: awayCode, size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            m.awayClub,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              fontWeight: m.awayClub == _userClub ? FontWeight.w800 : FontWeight.w600,
                              color: m.awayClub == _userClub ? AppPalette.gold : ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 14, color: inkMuted),
                ],
              ),
              Builder(builder: (context) {
                final allGoals = [...m.homeGoalEvents, ...m.awayGoalEvents];
                if (allGoals.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    allGoals
                        .map((e) => "${e.scorerName} ${e.minute}'")
                        .take(3)
                        .join(', '),
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(inkMuted).copyWith(fontSize: 9.5),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // DOMESTIC CUP COMPETITIONS UI: FA CUP & CARABAO CUP (Fix 26 / User Fix 4)
  // =========================================================================

  Widget _buildCupsStandings(bool isDark, Color ink, Color inkMuted, LeagueDefinition activeLeague) {
    final faCup = _faCupTournament;
    final carabao = _carabaoCupTournament;

    if (faCup == null && carabao == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.workspace_premium_rounded, size: 36, color: AppPalette.gold),
            const SizedBox(height: 8),
            Text('Domestic Cup Competitions', style: AppTypography.titleMedium(ink)),
            const SizedBox(height: 4),
            Text('Tournaments have not been initialized for this career.', style: AppTypography.caption(inkMuted)),
          ],
        ),
      );
    }

    final currentCup = (_cupSelectedId == 0 ? faCup : carabao) ?? faCup ?? carabao!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cup Switcher: [ 🏆 THE EMIRATES FA CUP ] vs [ 🎖️ CARABAO CUP ]
        Container(
          padding: const EdgeInsets.all(3),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildCupSelectorButton(
                  cupIndex: 0,
                  label: 'THE EMIRATES FA CUP',
                  icon: Icons.workspace_premium_rounded,
                  isDark: isDark,
                  ink: ink,
                  inkMuted: inkMuted,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildCupSelectorButton(
                  cupIndex: 1,
                  label: 'CARABAO CUP',
                  icon: Icons.shield_rounded,
                  isDark: isDark,
                  ink: ink,
                  inkMuted: inkMuted,
                ),
              ),
            ],
          ),
        ),

        // Champion Banner if this cup has finished
        if (currentCup.champion != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppPalette.gold.withValues(alpha: 0.25),
                  _cupSelectedId == 0
                      ? const Color(0xFF8B0000).withValues(alpha: 0.35)
                      : const Color(0xFF006400).withValues(alpha: 0.35),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppPalette.gold, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: AppPalette.gold, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${currentCup.name.toUpperCase()} 2026/27 WINNER',
                        style: AppTypography.caption(AppPalette.gold).copyWith(fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                      Text(
                        currentCup.champion!,
                        style: AppTypography.titleMedium(ink).copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Sub-tabs: 0: BRACKETS, 1: SCORELINES, 2: SCORERS, 3: ASSISTS, 4: CLEAN SHEETS
        Container(
          padding: const EdgeInsets.all(2),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCupSubTab(0, 'BRACKETS', isDark, ink, inkMuted),
                const SizedBox(width: 4),
                _buildCupSubTab(1, 'SCORELINES', isDark, ink, inkMuted),
                const SizedBox(width: 4),
                _buildCupSubTab(2, 'SCORERS', isDark, ink, inkMuted),
                const SizedBox(width: 4),
                _buildCupSubTab(3, 'ASSISTS', isDark, ink, inkMuted),
                const SizedBox(width: 4),
                _buildCupSubTab(4, 'CLEAN SHEETS', isDark, ink, inkMuted),
              ],
            ),
          ),
        ),

        if (_cupViewTab == 0)
          _buildCupBracketsView(currentCup, isDark, ink, inkMuted, activeLeague)
        else if (_cupViewTab == 1)
          _buildCupScorelinesView(currentCup, isDark, ink, inkMuted, activeLeague)
        else if (_cupViewTab == 2)
          _buildCupScorersView(currentCup, isDark, ink, inkMuted)
        else if (_cupViewTab == 3)
          _buildCupAssistsView(currentCup, isDark, ink, inkMuted)
        else
          _buildCupCleanSheetsView(currentCup, isDark, ink, inkMuted),
      ],
    );
  }

  Widget _buildCupSelectorButton({
    required int cupIndex,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color ink,
    required Color inkMuted,
  }) {
    final isSelected = _cupSelectedId == cupIndex;
    return InkWell(
      onTap: () => setState(() => _cupSelectedId = cupIndex),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4)]
              : null,
          border: isSelected
              ? Border.all(color: AppPalette.gold.withValues(alpha: 0.5), width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppPalette.gold : inkMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppPalette.gold : inkMuted,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCupSubTab(int tabIndex, String label, bool isDark, Color ink, Color inkMuted) {
    final isSelected = _cupViewTab == tabIndex;
    return InkWell(
      onTap: () => setState(() => _cupViewTab = tabIndex),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 3)]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppPalette.gold : inkMuted,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildCupBracketsView(
    CupTournament cup,
    bool isDark,
    Color ink,
    Color inkMuted,
    LeagueDefinition activeLeague,
  ) {
    final r16 = cup.getFixturesForRound(1);
    final qf = cup.getFixturesForRound(2);
    final sf = cup.getFixturesForRound(3);
    final fn = cup.getFixturesForRound(4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (r16.isNotEmpty) ...[
          _buildStageHeader('ROUND OF 16 (${r16.where((f) => f.isPlayed).length}/8 PLAYED)'),
          ...r16.map((f) => _buildCupFixtureTile(f, isDark, ink, inkMuted, activeLeague)),
          const SizedBox(height: 12),
        ],

        if (qf.isNotEmpty) ...[
          _buildStageHeader('QUARTER-FINALS (${qf.where((f) => f.isPlayed).length}/4 PLAYED)'),
          ...qf.map((f) => _buildCupFixtureTile(f, isDark, ink, inkMuted, activeLeague)),
          const SizedBox(height: 12),
        ],

        if (sf.isNotEmpty) ...[
          _buildStageHeader('SEMI-FINALS (${sf.where((f) => f.isPlayed).length}/2 PLAYED)'),
          ...sf.map((f) => _buildCupFixtureTile(f, isDark, ink, inkMuted, activeLeague)),
          const SizedBox(height: 12),
        ],

        if (fn.isNotEmpty) ...[
          _buildStageHeader('THE FINAL • WEMBLEY STADIUM'),
          ...fn.map((f) => _buildCupFixtureTile(f, isDark, ink, inkMuted, activeLeague, isFinal: true)),
        ] else ...[
          _buildStageHeader('THE FINAL • WEMBLEY STADIUM'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Center(
              child: Text(
                'Finalists will be decided after the Semi-Finals',
                style: AppTypography.caption(inkMuted).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCupFixtureTile(
    CupFixture f,
    bool isDark,
    Color ink,
    Color inkMuted,
    LeagueDefinition activeLeague, {
    bool isFinal = false,
  }) {
    final isUserMatch = f.homeClub == _userClub || f.awayClub == _userClub;
    final homeCode = activeLeague.clubCodes[f.homeClub] ??
        (f.homeClub == _userClub ? _userClubCode : (f.homeClub.length >= 3 ? f.homeClub.substring(0, 3).toUpperCase() : f.homeClub.toUpperCase()));
    final awayCode = activeLeague.clubCodes[f.awayClub] ??
        (f.awayClub == _userClub ? _userClubCode : (f.awayClub.length >= 3 ? f.awayClub.substring(0, 3).toUpperCase() : f.awayClub.toUpperCase()));

    final homeWon = f.winner == f.homeClub;
    final awayWon = f.winner == f.awayClub;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isUserMatch
            ? AppPalette.gold.withValues(alpha: 0.08)
            : (isDark ? AppPalette.darkCard : AppPalette.lightCard),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUserMatch
              ? AppPalette.gold.withValues(alpha: 0.6)
              : (f.winner != null ? AppPalette.gold.withValues(alpha: 0.25) : Theme.of(context).dividerColor.withValues(alpha: 0.4)),
          width: isUserMatch ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: f.isPlayed && f.result != null
            ? () {
                MatchDetailSheet.show(
                  context,
                  f.result!,
                  competitionName: '${f.cupName.toUpperCase()} • ${f.stage.toUpperCase()}',
                );
              }
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            children: [
              if (isUserMatch) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, size: 11, color: AppPalette.gold),
                    const SizedBox(width: 4),
                    Text(
                      'YOUR CLUB TIE',
                      style: AppTypography.caption(AppPalette.gold).copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            f.homeClub,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              fontWeight: homeWon ? FontWeight.w800 : (f.homeClub == _userClub ? FontWeight.w700 : FontWeight.w500),
                              color: homeWon ? AppPalette.gold : (f.homeClub == _userClub ? AppPalette.gold : ink),
                            ),
                          ),
                        ),
                        if (homeWon) ...[
                          const SizedBox(width: 3),
                          const Icon(Icons.check_circle_rounded, size: 11, color: AppPalette.green),
                        ],
                        const SizedBox(width: 6),
                        ClubBadge(code: homeCode, size: 18),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      f.isPlayed ? f.scoreline : 'GW ${f.matchday}',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: f.isPlayed ? 11.5 : 9.5,
                        fontWeight: FontWeight.w800,
                        color: f.isPlayed ? ink : inkMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        ClubBadge(code: awayCode, size: 18),
                        const SizedBox(width: 6),
                        if (awayWon) ...[
                          const Icon(Icons.check_circle_rounded, size: 11, color: AppPalette.green),
                          const SizedBox(width: 3),
                        ],
                        Flexible(
                          child: Text(
                            f.awayClub,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              fontWeight: awayWon ? FontWeight.w800 : (f.awayClub == _userClub ? FontWeight.w700 : FontWeight.w500),
                              color: awayWon ? AppPalette.gold : (f.awayClub == _userClub ? AppPalette.gold : ink),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (f.isPlayed) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 14, color: inkMuted),
                  ],
                ],
              ),
              if (f.isPlayed && f.result != null) ...[
                Builder(builder: (context) {
                  final allGoals = [...f.result!.homeGoalEvents, ...f.result!.awayGoalEvents];
                  if (allGoals.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      allGoals
                          .map((e) => "${e.scorerName} ${e.minute}'")
                          .take(3)
                          .join(', '),
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(inkMuted).copyWith(fontSize: 9.5),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCupScorelinesView(
    CupTournament cup,
    bool isDark,
    Color ink,
    Color inkMuted,
    LeagueDefinition activeLeague,
  ) {
    final playedFixtures = cup.fixtures.where((f) => f.isPlayed && f.result != null).toList().reversed.toList();

    if (playedFixtures.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.sports_soccer_rounded, size: 36, color: AppPalette.gold),
            const SizedBox(height: 8),
            Text('No ${cup.shortName} Matches Played Yet', style: AppTypography.titleMedium(ink)),
            const SizedBox(height: 4),
            Text('Scorelines will appear here as cup rounds are simulated.', textAlign: TextAlign.center, style: AppTypography.caption(inkMuted)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: playedFixtures.map((f) => _buildCupFixtureTile(f, isDark, ink, inkMuted, activeLeague)).toList(),
    );
  }

  Widget _buildCupScorersView(CupTournament cup, bool isDark, Color ink, Color inkMuted) {
    final entries = cup.playerGoals.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.sports_soccer_rounded, size: 36, color: AppPalette.gold),
            const SizedBox(height: 8),
            Text('No ${cup.shortName} Goals Yet', style: AppTypography.titleMedium(ink)),
            const SizedBox(height: 4),
            Text('Scorers will appear as cup rounds are simulated.', style: AppTypography.caption(inkMuted)),
          ],
        ),
      );
    }

    final topScorers = entries.take(10).toList();

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(0.7),
        1: FlexColumnWidth(3.2),
        2: FlexColumnWidth(2.2),
        3: FlexColumnWidth(1.0),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _headerCell('#', inkMuted),
            _headerCell('PLAYER', inkMuted, align: TextAlign.left),
            _headerCell('CLUB', inkMuted, align: TextAlign.left),
            _headerCell('GLS', inkMuted),
          ],
        ),
        ...List.generate(topScorers.length, (idx) {
          final scorer = topScorers[idx];
          final playerName = scorer.key;
          final goals = scorer.value;
          final clubName = cup.playerClubs[playerName] ?? '';
          final isUserPlayer = _userSquad.any((p) => p.name == playerName);
          final clubCode = clubName.length >= 3 ? clubName.substring(0, 3).toUpperCase() : clubName.toUpperCase();

          Widget rankWidget;
          if (idx == 0) {
            rankWidget = const Center(child: Text('🥇', style: TextStyle(fontSize: 14)));
          } else if (idx == 1) {
            rankWidget = const Center(child: Text('🥈', style: TextStyle(fontSize: 14)));
          } else if (idx == 2) {
            rankWidget = const Center(child: Text('🥉', style: TextStyle(fontSize: 14)));
          } else {
            rankWidget = _cell('${idx + 1}', inkMuted);
          }

          return TableRow(
            decoration: isUserPlayer ? BoxDecoration(color: AppPalette.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)) : null,
            children: [
              rankWidget,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        playerName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12.5,
                          fontWeight: isUserPlayer ? FontWeight.w800 : FontWeight.w600,
                          color: isUserPlayer ? AppPalette.gold : ink,
                        ),
                      ),
                    ),
                    if (isUserPlayer) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded, size: 13, color: AppPalette.gold),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    ClubBadge(code: clubCode, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        clubName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _cell('$goals', isUserPlayer ? AppPalette.gold : ink, isBold: true),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildCupAssistsView(CupTournament cup, bool isDark, Color ink, Color inkMuted) {
    final entries = cup.playerAssists.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 36, color: AppPalette.gold),
            const SizedBox(height: 8),
            Text('No ${cup.shortName} Assists Yet', style: AppTypography.titleMedium(ink)),
            const SizedBox(height: 4),
            Text('Playmakers will appear as cup rounds are simulated.', style: AppTypography.caption(inkMuted)),
          ],
        ),
      );
    }

    final topAssisters = entries.take(10).toList();

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(0.7),
        1: FlexColumnWidth(3.2),
        2: FlexColumnWidth(2.2),
        3: FlexColumnWidth(1.0),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _headerCell('#', inkMuted),
            _headerCell('PLAYER', inkMuted, align: TextAlign.left),
            _headerCell('CLUB', inkMuted, align: TextAlign.left),
            _headerCell('AST', inkMuted),
          ],
        ),
        ...List.generate(topAssisters.length, (idx) {
          final assister = topAssisters[idx];
          final playerName = assister.key;
          final assists = assister.value;
          final clubName = cup.playerClubs[playerName] ?? '';
          final isUserPlayer = _userSquad.any((p) => p.name == playerName);
          final clubCode = clubName.length >= 3 ? clubName.substring(0, 3).toUpperCase() : clubName.toUpperCase();

          Widget rankWidget;
          if (idx == 0) {
            rankWidget = const Center(child: Text('🥇', style: TextStyle(fontSize: 14)));
          } else if (idx == 1) {
            rankWidget = const Center(child: Text('🥈', style: TextStyle(fontSize: 14)));
          } else if (idx == 2) {
            rankWidget = const Center(child: Text('🥉', style: TextStyle(fontSize: 14)));
          } else {
            rankWidget = _cell('${idx + 1}', inkMuted);
          }

          return TableRow(
            decoration: isUserPlayer ? BoxDecoration(color: AppPalette.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)) : null,
            children: [
              rankWidget,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        playerName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12.5,
                          fontWeight: isUserPlayer ? FontWeight.w800 : FontWeight.w600,
                          color: isUserPlayer ? AppPalette.gold : ink,
                        ),
                      ),
                    ),
                    if (isUserPlayer) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded, size: 13, color: AppPalette.gold),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    ClubBadge(code: clubCode, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        clubName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _cell('$assists', isUserPlayer ? AppPalette.gold : ink, isBold: true),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildCupCleanSheetsView(CupTournament cup, bool isDark, Color ink, Color inkMuted) {
    final entries = cup.playerCleanSheets.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.shield_rounded, size: 36, color: AppPalette.gold),
            const SizedBox(height: 8),
            Text('No ${cup.shortName} Clean Sheets Yet', style: AppTypography.titleMedium(ink)),
            const SizedBox(height: 4),
            Text('Defensive shutouts will appear as cup rounds are simulated.', style: AppTypography.caption(inkMuted)),
          ],
        ),
      );
    }

    final topCleanSheets = entries.take(10).toList();

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(0.7),
        1: FlexColumnWidth(4.5),
        2: FlexColumnWidth(1.2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _headerCell('#', inkMuted),
            _headerCell('CLUB', inkMuted, align: TextAlign.left),
            _headerCell('CS', inkMuted),
          ],
        ),
        ...List.generate(topCleanSheets.length, (idx) {
          final item = topCleanSheets[idx];
          final clubName = item.key;
          final cleanSheets = item.value;
          final isUserClub = clubName == _userClub;
          final clubCode = clubName.length >= 3 ? clubName.substring(0, 3).toUpperCase() : clubName.toUpperCase();

          Widget rankWidget;
          if (idx == 0) {
            rankWidget = const Center(child: Text('🥇', style: TextStyle(fontSize: 14)));
          } else if (idx == 1) {
            rankWidget = const Center(child: Text('🥈', style: TextStyle(fontSize: 14)));
          } else if (idx == 2) {
            rankWidget = const Center(child: Text('🥉', style: TextStyle(fontSize: 14)));
          } else {
            rankWidget = _cell('${idx + 1}', inkMuted);
          }

          return TableRow(
            decoration: isUserClub ? BoxDecoration(color: AppPalette.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)) : null,
            children: [
              rankWidget,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    ClubBadge(code: clubCode, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        clubName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isUserClub ? AppPalette.gold : inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _cell('$cleanSheets', isUserClub ? AppPalette.gold : ink, isBold: true),
            ],
          );
        }),
      ],
    );
  }
}

