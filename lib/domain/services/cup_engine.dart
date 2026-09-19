import 'dart:math';
import 'sim_engine.dart';

/// Represents a single knockout cup fixture between two clubs.
class CupFixture {
  final String id;
  final String cupId; // 'fa_cup' or 'carabao_cup'
  final String cupName; // 'The Emirates FA Cup' or 'Carabao Cup'
  final String stage; // 'Round of 16', 'Quarter-Finals', 'Semi-Finals', 'Final'
  final int roundIndex; // 1 (R16), 2 (QF), 3 (SF), 4 (Final)
  final int matchday; // Gameweek when played
  final String homeClub;
  final String awayClub;
  MatchResult? result;
  int? homePenalties;
  int? awayPenalties;
  String? winner;

  CupFixture({
    required this.id,
    required this.cupId,
    required this.cupName,
    required this.stage,
    required this.roundIndex,
    required this.matchday,
    required this.homeClub,
    required this.awayClub,
    this.result,
    this.homePenalties,
    this.awayPenalties,
    this.winner,
  });

  bool get isPlayed => result != null;

  String get scoreline {
    if (result == null) return 'vs';
    final base = '${result!.homeGoals} - ${result!.awayGoals}';
    if (homePenalties != null && awayPenalties != null) {
      return '$base ($homePenalties-$awayPenalties pen)';
    }
    return base;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'cupId': cupId,
    'cupName': cupName,
    'stage': stage,
    'roundIndex': roundIndex,
    'matchday': matchday,
    'homeClub': homeClub,
    'awayClub': awayClub,
    if (result != null) 'result': result!.toMap(),
    if (homePenalties != null) 'homePen': homePenalties,
    if (awayPenalties != null) 'awayPen': awayPenalties,
    if (winner != null) 'winner': winner,
  };

  factory CupFixture.fromMap(Map<String, dynamic> map) => CupFixture(
    id: map['id'] as String? ?? '',
    cupId: map['cupId'] as String? ?? 'fa_cup',
    cupName: map['cupName'] as String? ?? 'FA Cup',
    stage: map['stage'] as String? ?? 'Round of 16',
    roundIndex: (map['roundIndex'] as num?)?.toInt() ?? 1,
    matchday: (map['matchday'] as num?)?.toInt() ?? 1,
    homeClub: map['homeClub'] as String? ?? '',
    awayClub: map['awayClub'] as String? ?? '',
    result: map['result'] != null
        ? MatchResult.fromMap(Map<String, dynamic>.from(map['result'] as Map))
        : null,
    homePenalties: (map['homePen'] as num?)?.toInt(),
    awayPenalties: (map['awayPen'] as num?)?.toInt(),
    winner: map['winner'] as String?,
  );
}

/// Domestic Cup Tournament Manager (FA Cup / Carabao Cup)
class CupTournament {
  final String id; // 'fa_cup' or 'carabao_cup'
  final String name; // 'The Emirates FA Cup' or 'Carabao Cup'
  final String shortName; // 'FA CUP' or 'CARABAO'
  final String userClub;
  final List<String> participants;
  final List<CupFixture> fixtures;
  String? champion;
  String? runnerUp;

  // Cup Statistics
  final Map<String, int> playerGoals = {};
  final Map<String, int> playerAssists = {};
  final Map<String, int> playerCleanSheets = {};
  final Map<String, int> playerAppearances = {};
  final Map<String, String> playerClubs = {};

  CupTournament({
    required this.id,
    required this.name,
    required this.shortName,
    required this.userClub,
    required this.participants,
    List<CupFixture>? fixtures,
    this.champion,
    this.runnerUp,
  }) : fixtures = fixtures != null ? List<CupFixture>.from(fixtures) : <CupFixture>[];

  static const List<String> kDefaultEnglishCupClubs = [
    'Arsenal', 'Aston Villa', 'Chelsea', 'Liverpool',
    'Manchester City', 'Manchester United', 'Newcastle United', 'Tottenham Hotspur',
    'Brighton & Hove Albion', 'West Ham United', 'AFC Bournemouth', 'Brentford',
    'Crystal Palace', 'Everton', 'Fulham', 'Wolverhampton Wanderers',
    'Nottingham Forest', 'Leicester City', 'Southampton', 'Ipswich Town'
  ];

  static const List<String> kDefaultContinentalCupClubs = [
    'Real Madrid', 'Barcelona', 'Bayern Munich', 'Paris Saint-Germain',
    'Inter Milan', 'Juventus', 'Borussia Dortmund', 'Atlético Madrid',
    'Bayer Leverkusen', 'AC Milan', 'Sporting CP', 'Benfica',
    'Porto', 'PSV Eindhoven', 'Marseille', 'Monaco'
  ];

  /// Initialize a new Cup tournament (FA Cup or Carabao Cup)
  factory CupTournament.create({
    required String id,
    required String userClub,
    List<String>? poolClubs,
  }) {
    final isFa = id == 'fa_cup';
    final name = isFa ? 'The Emirates FA Cup' : 'Carabao Cup';
    final shortName = isFa ? 'FA CUP' : 'CARABAO';

    final clubs = poolClubs != null && poolClubs.length >= 16
        ? List<String>.from(poolClubs)
        : List<String>.from(kDefaultEnglishCupClubs);

    // Ensure user's club is always in the 16 participants
    clubs.remove(userClub);
    final rng = Random();
    clubs.shuffle(rng);
    final selected16 = [userClub, ...clubs.take(15)];
    selected16.shuffle(rng);

    final r16Fixtures = <CupFixture>[];
    for (int i = 0; i < 8; i++) {
      r16Fixtures.add(CupFixture(
        id: '${id}_r16_${i + 1}',
        cupId: id,
        cupName: name,
        stage: 'Round of 16',
        roundIndex: 1,
        matchday: isFa ? 8 : 5,
        homeClub: selected16[i * 2],
        awayClub: selected16[i * 2 + 1],
      ));
    }

    return CupTournament(
      id: id,
      name: name,
      shortName: shortName,
      userClub: userClub,
      participants: selected16,
      fixtures: r16Fixtures,
    );
  }

  /// Whether the user club is still active in the tournament
  bool get isUserClubAlive {
    if (champion == userClub) return true;
    if (champion != null && champion != userClub) return false;
    for (final f in fixtures.where((f) => f.isPlayed)) {
      if ((f.homeClub == userClub || f.awayClub == userClub) && f.winner != null && f.winner != userClub) {
        return false;
      }
    }
    return true;
  }

  /// Current stage title for UI
  String get currentStageTitle {
    if (champion != null) return 'CHAMPIONS: $champion';
    final active = fixtures.where((f) => !f.isPlayed).toList();
    if (active.isEmpty) {
      final lastPlayed = fixtures.where((f) => f.isPlayed).toList();
      return lastPlayed.isNotEmpty ? lastPlayed.last.stage : 'UPCOMING';
    }
    return active.first.stage;
  }

  List<CupFixture> getFixturesForRound(int roundIndex) {
    return fixtures.where((f) => f.roundIndex == roundIndex).toList();
  }

  /// Checks if earlier rounds completed and generates subsequent bracket fixtures
  void checkAndAdvanceStages({int totalGameweeks = 38}) {
    final isFa = id == 'fa_cup';

    // 1. Check Round of 16 (roundIndex 1) -> generate Quarter-Finals (roundIndex 2)
    final r16 = getFixturesForRound(1);
    final qf = getFixturesForRound(2);
    if (r16.isNotEmpty && r16.every((f) => f.isPlayed && f.winner != null) && qf.isEmpty) {
      final winners = r16.map((f) => f.winner!).toList();
      final qfMatchday = isFa
          ? (totalGameweeks == 18 ? 13 : 14)
          : (totalGameweeks == 18 ? 7 : 11);

      for (int i = 0; i < 4; i++) {
        fixtures.add(CupFixture(
          id: '${id}_qf_${i + 1}',
          cupId: id,
          cupName: name,
          stage: 'Quarter-Finals',
          roundIndex: 2,
          matchday: qfMatchday,
          homeClub: winners[i * 2],
          awayClub: winners[i * 2 + 1],
        ));
      }
    }

    // 2. Check Quarter-Finals (roundIndex 2) -> generate Semi-Finals (roundIndex 3)
    final currentQf = getFixturesForRound(2);
    final sf = getFixturesForRound(3);
    if (currentQf.isNotEmpty && currentQf.every((f) => f.isPlayed && f.winner != null) && sf.isEmpty) {
      final winners = currentQf.map((f) => f.winner!).toList();
      final sfMatchday = isFa
          ? (totalGameweeks == 18 ? 15 : 29)
          : (totalGameweeks == 18 ? 9 : 17);

      for (int i = 0; i < 2; i++) {
        fixtures.add(CupFixture(
          id: '${id}_sf_${i + 1}',
          cupId: id,
          cupName: name,
          stage: 'Semi-Finals',
          roundIndex: 3,
          matchday: sfMatchday,
          homeClub: winners[i * 2],
          awayClub: winners[i * 2 + 1],
        ));
      }
    }

    // 3. Check Semi-Finals (roundIndex 3) -> generate Final (roundIndex 4)
    final currentSf = getFixturesForRound(3);
    final fn = getFixturesForRound(4);
    if (currentSf.isNotEmpty && currentSf.every((f) => f.isPlayed && f.winner != null) && fn.isEmpty) {
      final winners = currentSf.map((f) => f.winner!).toList();
      final finalMatchday = isFa
          ? (totalGameweeks == 18 ? 17 : 37)
          : (totalGameweeks == 18 ? 11 : 24);

      fixtures.add(CupFixture(
        id: '${id}_final',
        cupId: id,
        cupName: name,
        stage: 'Final',
        roundIndex: 4,
        matchday: finalMatchday,
        homeClub: winners[0],
        awayClub: winners[1],
      ));
    }

    // 4. Check Final -> Crown champion
    final currentFinal = getFixturesForRound(4);
    if (currentFinal.isNotEmpty && currentFinal.first.isPlayed && currentFinal.first.winner != null) {
      champion = currentFinal.first.winner;
      runnerUp = currentFinal.first.homeClub == champion
          ? currentFinal.first.awayClub
          : currentFinal.first.homeClub;
    }
  }

  /// Simulates all unplayed fixtures for a given round
  List<MatchResult> simulateRound(
    int roundIndex, {
    required SimEngine simEngine,
    Map<String, List<SimPlayer>>? clubPlayers,
    int totalGameweeks = 38,
  }) {
    checkAndAdvanceStages(totalGameweeks: totalGameweeks);
    final roundFixtures = getFixturesForRound(roundIndex);
    final results = <MatchResult>[];
    final rng = Random();

    for (final f in roundFixtures) {
      if (!f.isPlayed) {
        final homeSquad = clubPlayers?[f.homeClub];
        final awaySquad = clubPlayers?[f.awayClub];

        final res = simEngine.simulateMatch(
          homeClub: f.homeClub,
          homeRating: 83.0,
          awayClub: f.awayClub,
          awayRating: 83.0,
          homePlayers: homeSquad,
          awayPlayers: awaySquad,
        );

        f.result = res;

        // Resolve knockout winner (Extra Time / Penalties if draw)
        if (res.homeGoals > res.awayGoals) {
          f.winner = f.homeClub;
        } else if (res.awayGoals > res.homeGoals) {
          f.winner = f.awayClub;
        } else {
          // Penalty shootout tie-break
          final hPen = 4 + rng.nextInt(2); // 4 to 5
          int aPen = 3 + rng.nextInt(2);
          if (aPen == hPen) {
            aPen = rng.nextBool() ? hPen + 1 : hPen - 1;
            if (aPen < 0) aPen = 1;
          }
          f.homePenalties = hPen;
          f.awayPenalties = aPen;
          f.winner = hPen > aPen ? f.homeClub : f.awayClub;
        }

        recordFixtureResult(f, res);
        results.add(res);
      } else if (f.result != null) {
        results.add(f.result!);
      }
    }

    checkAndAdvanceStages(totalGameweeks: totalGameweeks);
    return results;
  }

  /// Records player statistics from match result
  void recordFixtureResult(CupFixture fixture, MatchResult result) {
    // Scorers
    for (final g in result.homeGoalEvents) {
      if (!g.isOwnGoal) {
        playerGoals[g.scorerName] = (playerGoals[g.scorerName] ?? 0) + 1;
        playerClubs[g.scorerName] = fixture.homeClub;
      }
      if (g.assisterName != null && g.assisterName!.isNotEmpty) {
        playerAssists[g.assisterName!] = (playerAssists[g.assisterName!] ?? 0) + 1;
        playerClubs[g.assisterName!] = fixture.homeClub;
      }
    }
    for (final g in result.awayGoalEvents) {
      if (!g.isOwnGoal) {
        playerGoals[g.scorerName] = (playerGoals[g.scorerName] ?? 0) + 1;
        playerClubs[g.scorerName] = fixture.awayClub;
      }
      if (g.assisterName != null && g.assisterName!.isNotEmpty) {
        playerAssists[g.assisterName!] = (playerAssists[g.assisterName!] ?? 0) + 1;
        playerClubs[g.assisterName!] = fixture.awayClub;
      }
    }

    // Clean Sheets (Goalkeepers)
    if (result.awayGoals == 0) {
      final gk = '${fixture.homeClub} GK';
      playerCleanSheets[gk] = (playerCleanSheets[gk] ?? 0) + 1;
      playerClubs[gk] = fixture.homeClub;
    }
    if (result.homeGoals == 0) {
      final gk = '${fixture.awayClub} GK';
      playerCleanSheets[gk] = (playerCleanSheets[gk] ?? 0) + 1;
      playerClubs[gk] = fixture.awayClub;
    }
  }

  /// Maps Premier League gameweek to FA Cup round (or null if no FA Cup this week)
  static int? getFaCupRoundForLeagueGw(int leagueGw, {int totalGameweeks = 38}) {
    if (totalGameweeks == 18) {
      switch (leagueGw) {
        case 5: return 1;  // Round of 16
        case 13: return 2; // Quarter-Finals
        case 15: return 3; // Semi-Finals
        case 17: return 4; // Final
        default: return null;
      }
    }
    switch (leagueGw) {
      case 8: return 1;  // Round of 16
      case 14: return 2; // Quarter-Finals
      case 29: return 3; // Semi-Finals
      case 37: return 4; // Final
      default: return null;
    }
  }

  /// Maps Premier League gameweek to Carabao Cup round (or null if no Carabao Cup this week)
  static int? getCarabaoRoundForLeagueGw(int leagueGw, {int totalGameweeks = 38}) {
    if (totalGameweeks == 18) {
      switch (leagueGw) {
        case 3: return 1;  // Round of 16
        case 7: return 2;  // Quarter-Finals
        case 9: return 3;  // Semi-Finals
        case 11: return 4; // Final
        default: return null;
      }
    }
    switch (leagueGw) {
      case 5: return 1;  // Round of 16
      case 11: return 2; // Quarter-Finals
      case 17: return 3; // Semi-Finals
      case 24: return 4; // Final
      default: return null;
    }
  }

  /// Prize money awarded for cup progression
  double calculatePrizeMoney() {
    final isFa = id == 'fa_cup';
    if (champion == userClub) return isFa ? 15.0 : 8.0;
    if (runnerUp == userClub) return isFa ? 6.0 : 3.5;

    // Check if reached Semi-Finals
    final sf = getFixturesForRound(3);
    final reachedSf = sf.any((f) => f.homeClub == userClub || f.awayClub == userClub);
    if (reachedSf) return isFa ? 3.0 : 1.5;

    // Check if reached Quarter-Finals
    final qf = getFixturesForRound(2);
    final reachedQf = qf.any((f) => f.homeClub == userClub || f.awayClub == userClub);
    if (reachedQf) return isFa ? 1.5 : 0.8;

    return 0.5; // Participation
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'shortName': shortName,
    'userClub': userClub,
    'participants': participants,
    'fixtures': fixtures.map((f) => f.toMap()).toList(),
    if (champion != null) 'champion': champion,
    if (runnerUp != null) 'runnerUp': runnerUp,
    'playerGoals': playerGoals,
    'playerAssists': playerAssists,
    'playerCleanSheets': playerCleanSheets,
    'playerAppearances': playerAppearances,
    'playerClubs': playerClubs,
  };

  factory CupTournament.fromMap(Map<String, dynamic> map) {
    final cup = CupTournament(
      id: map['id'] as String? ?? 'fa_cup',
      name: map['name'] as String? ?? 'FA Cup',
      shortName: map['shortName'] as String? ?? 'FA CUP',
      userClub: map['userClub'] as String? ?? '',
      participants: List<String>.from(map['participants'] as List? ?? []),
      fixtures: (map['fixtures'] as List? ?? [])
          .map((f) => CupFixture.fromMap(Map<String, dynamic>.from(f as Map)))
          .toList(),
      champion: map['champion'] as String?,
      runnerUp: map['runnerUp'] as String?,
    );

    if (map['playerGoals'] is Map) {
      (map['playerGoals'] as Map).forEach((k, v) => cup.playerGoals[k.toString()] = (v as num).toInt());
    }
    if (map['playerAssists'] is Map) {
      (map['playerAssists'] as Map).forEach((k, v) => cup.playerAssists[k.toString()] = (v as num).toInt());
    }
    if (map['playerCleanSheets'] is Map) {
      (map['playerCleanSheets'] as Map).forEach((k, v) => cup.playerCleanSheets[k.toString()] = (v as num).toInt());
    }
    if (map['playerAppearances'] is Map) {
      (map['playerAppearances'] as Map).forEach((k, v) => cup.playerAppearances[k.toString()] = (v as num).toInt());
    }
    if (map['playerClubs'] is Map) {
      (map['playerClubs'] as Map).forEach((k, v) => cup.playerClubs[k.toString()] = v.toString());
    }

    return cup;
  }
}
