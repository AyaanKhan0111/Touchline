import 'dart:math';
import 'sim_engine.dart';

/// Represents a single UCL fixture between two clubs
class UclFixture {
  final String id;
  final String stage; // 'Group A', 'Group B', 'QF_Leg1', 'QF_Leg2', 'SF_Leg1', 'SF_Leg2', 'Final'
  final int matchday; // 1 to 11
  final String homeClub;
  final String awayClub;
  MatchResult? result;

  UclFixture({
    required this.id,
    required this.stage,
    required this.matchday,
    required this.homeClub,
    required this.awayClub,
    this.result,
  });

  bool get isPlayed => result != null;

  Map<String, dynamic> toMap() => {
    'id': id,
    'stage': stage,
    'matchday': matchday,
    'homeClub': homeClub,
    'awayClub': awayClub,
    if (result != null) 'result': result!.toMap(),
  };

  factory UclFixture.fromMap(Map<String, dynamic> map) => UclFixture(
    id: map['id'] as String? ?? '',
    stage: map['stage'] as String? ?? 'Group',
    matchday: (map['matchday'] as num?)?.toInt() ?? 1,
    homeClub: map['homeClub'] as String? ?? '',
    awayClub: map['awayClub'] as String? ?? '',
    result: map['result'] != null
        ? MatchResult.fromMap(Map<String, dynamic>.from(map['result'] as Map))
        : null,
  );
}

/// A knockout two-legged tie or single final
class UclKnockoutTie {
  final String stage; // 'QF', 'SF', 'Final'
  final String clubA;
  final String clubB;
  UclFixture leg1;
  UclFixture? leg2; // Null for single-match Final
  String? winner;

  UclKnockoutTie({
    required this.stage,
    required this.clubA,
    required this.clubB,
    required this.leg1,
    this.leg2,
    this.winner,
  });

  int get scoreA {
    int s = leg1.result?.homeClub == clubA ? (leg1.result?.homeGoals ?? 0) : (leg1.result?.awayGoals ?? 0);
    if (leg2?.result != null) {
      s += leg2!.result!.homeClub == clubA ? leg2!.result!.homeGoals : leg2!.result!.awayGoals;
    }
    return s;
  }

  int get scoreB {
    int s = leg1.result?.homeClub == clubB ? (leg1.result?.homeGoals ?? 0) : (leg1.result?.awayGoals ?? 0);
    if (leg2?.result != null) {
      s += leg2!.result!.homeClub == clubB ? leg2!.result!.homeGoals : leg2!.result!.awayGoals;
    }
    return s;
  }

  bool get isCompleted => leg2 != null ? leg2!.isPlayed : leg1.isPlayed;

  void computeWinner() {
    if (!isCompleted) return;
    if (scoreA > scoreB) {
      winner = clubA;
    } else if (scoreB > scoreA) {
      winner = clubB;
    } else {
      // Penalty shootout tie-breaker
      final rng = Random();
      winner = rng.nextBool() ? clubA : clubB;
    }
  }

  Map<String, dynamic> toMap() => {
    'stage': stage,
    'clubA': clubA,
    'clubB': clubB,
    'leg1': leg1.toMap(),
    if (leg2 != null) 'leg2': leg2!.toMap(),
    if (winner != null) 'winner': winner,
  };

  factory UclKnockoutTie.fromMap(Map<String, dynamic> map) => UclKnockoutTie(
    stage: map['stage'] as String? ?? 'QF',
    clubA: map['clubA'] as String? ?? '',
    clubB: map['clubB'] as String? ?? '',
    leg1: UclFixture.fromMap(Map<String, dynamic>.from(map['leg1'] as Map)),
    leg2: map['leg2'] != null ? UclFixture.fromMap(Map<String, dynamic>.from(map['leg2'] as Map)) : null,
    winner: map['winner'] as String?,
  );
}

/// UEFA Champions League 2026/27 Competition Manager
class UclTournament {
  final String userClub;
  final List<String> participants;
  final Map<String, List<String>> groups; // 'A', 'B', 'C', 'D'
  final Map<String, List<TableEntry>> groupTables;
  final List<UclFixture> groupFixtures;
  final List<UclKnockoutTie> quarterFinals;
  final List<UclKnockoutTie> semiFinals;
  UclKnockoutTie? finalTie;
  String? champion;

  // Separate UCL statistics
  final Map<String, int> playerGoals = {};
  final Map<String, int> playerAssists = {};
  final Map<String, int> playerCleanSheets = {};
  final Map<String, int> playerAppearances = {};
  final Map<String, String> playerClubs = {};

  UclTournament({
    required this.userClub,
    required this.participants,
    required this.groups,
    required this.groupTables,
    required this.groupFixtures,
    List<UclKnockoutTie>? quarterFinals,
    List<UclKnockoutTie>? semiFinals,
    this.finalTie,
    this.champion,
  })  : quarterFinals = quarterFinals != null ? List<UclKnockoutTie>.from(quarterFinals) : <UclKnockoutTie>[],
        semiFinals = semiFinals != null ? List<UclKnockoutTie>.from(semiFinals) : <UclKnockoutTie>[];

  /// Real 2026/27 European Elite Clubs pool from the database
  static const List<String> kDefaultUclClubs = [
    'Real Madrid',
    'Barcelona',
    'Bayern Munich',
    'Paris Saint-Germain',
    'Manchester City',
    'Arsenal',
    'Liverpool',
    'Inter Milan',
    'Borussia Dortmund',
    'Atlético Madrid',
    'Bayer Leverkusen',
    'Juventus',
    'AC Milan',
    'Sporting CP',
    'Benfica',
    'Aston Villa',
  ];

  /// Initialize a new UCL campaign for the season, ensuring the user's club participates
  factory UclTournament.create({required String userClub}) {
    final clubs = List<String>.from(kDefaultUclClubs);
    // If user's club is not in the default 16, include them (replace Aston Villa)
    if (!clubs.contains(userClub)) {
      clubs.removeLast();
      clubs.add(userClub);
    }

    // Shuffle and distribute into 4 groups of 4
    final rng = Random();
    clubs.shuffle(rng);

    final groups = <String, List<String>>{
      'A': clubs.sublist(0, 4),
      'B': clubs.sublist(4, 8),
      'C': clubs.sublist(8, 12),
      'D': clubs.sublist(12, 16),
    };

    final groupTables = <String, List<TableEntry>>{};
    for (final entry in groups.entries) {
      groupTables[entry.key] = entry.value.map((c) => TableEntry(clubName: c)).toList();
    }

    // Generate 6 matchdays for group stage
    final groupFixtures = <UclFixture>[];
    int fixtureCounter = 1;

    for (final entry in groups.entries) {
      final gName = entry.key;
      final gClubs = entry.value;

      // Single round robin pairings (3 matchdays)
      final md1 = [
        [gClubs[0], gClubs[1]],
        [gClubs[2], gClubs[3]],
      ];
      final md2 = [
        [gClubs[0], gClubs[2]],
        [gClubs[3], gClubs[1]],
      ];
      final md3 = [
        [gClubs[0], gClubs[3]],
        [gClubs[1], gClubs[2]],
      ];

      final rounds = [md1, md2, md3];

      // Matchdays 1 to 3 (Home leg)
      for (int m = 0; m < 3; m++) {
        for (final pair in rounds[m]) {
          groupFixtures.add(UclFixture(
            id: 'ucl_${fixtureCounter++}',
            stage: 'Group $gName',
            matchday: m + 1,
            homeClub: pair[0],
            awayClub: pair[1],
          ));
        }
      }

      // Matchdays 4 to 6 (Return leg with reversed venues)
      for (int m = 0; m < 3; m++) {
        for (final pair in rounds[m]) {
          groupFixtures.add(UclFixture(
            id: 'ucl_${fixtureCounter++}',
            stage: 'Group $gName',
            matchday: m + 4,
            homeClub: pair[1],
            awayClub: pair[0],
          ));
        }
      }
    }

    return UclTournament(
      userClub: userClub,
      participants: clubs,
      groups: groups,
      groupTables: groupTables,
      groupFixtures: groupFixtures,
    );
  }

  /// Current stage title for UI displays
  String get currentStageTitle {
    if (champion != null) return 'CHAMPIONS: $champion';
    if (finalTie != null) return 'FINAL';
    if (semiFinals.isNotEmpty) {
      final isLeg2 = semiFinals.any((s) => s.leg1.isPlayed && !s.isCompleted);
      return isLeg2 ? 'SEMI-FINALS • 2ND LEG' : 'SEMI-FINALS • 1ST LEG';
    }
    if (quarterFinals.isNotEmpty) {
      final isLeg2 = quarterFinals.any((q) => q.leg1.isPlayed && !q.isCompleted);
      return isLeg2 ? 'QUARTER-FINALS • 2ND LEG' : 'QUARTER-FINALS • 1ST LEG';
    }
    final playedCount = groupFixtures.where((f) => f.isPlayed).length;
    final currentMd = (playedCount ~/ 8) + 1;
    return 'GROUP STAGE • MD ${currentMd.clamp(1, 6)}/6';
  }

  /// Whether the initial 6-matchday group stage is finished
  bool get isGroupStageComplete => groupFixtures.every((f) => f.isPlayed);

  /// Get fixtures belonging to a specific matchday (1-11)
  List<UclFixture> getFixturesForMatchday(int matchday) {
    if (matchday >= 1 && matchday <= 6) {
      return groupFixtures.where((f) => f.matchday == matchday).toList();
    } else if (matchday == 7) {
      return quarterFinals.map((t) => t.leg1).toList();
    } else if (matchday == 8) {
      return quarterFinals.where((t) => t.leg2 != null).map((t) => t.leg2!).toList();
    } else if (matchday == 9) {
      return semiFinals.map((t) => t.leg1).toList();
    } else if (matchday == 10) {
      return semiFinals.where((t) => t.leg2 != null).map((t) => t.leg2!).toList();
    } else if (matchday == 11) {
      return finalTie != null ? [finalTie!.leg1] : [];
    }
    return [];
  }

  /// Simulates all unplayed fixtures for a given UCL matchday
  List<MatchResult> simulateMatchday(
    int matchday, {
    required SimEngine simEngine,
    Map<String, List<SimPlayer>>? clubPlayers,
  }) {
    checkAndAdvanceStages();
    final fixtures = getFixturesForMatchday(matchday);
    final results = <MatchResult>[];

    for (final f in fixtures) {
      if (!f.isPlayed) {
        final homeSquad = clubPlayers?[f.homeClub];
        final awaySquad = clubPlayers?[f.awayClub];
        final res = simEngine.simulateMatch(
          homeClub: f.homeClub,
          homeRating: 84.0,
          awayClub: f.awayClub,
          awayRating: 84.0,
          homePlayers: homeSquad,
          awayPlayers: awaySquad,
        );
        recordFixtureResult(f, res);
        results.add(res);
      } else if (f.result != null) {
        results.add(f.result!);
      }
    }

    checkAndAdvanceStages();
    return results;
  }

  /// Maps Premier League gameweek to UCL matchday (or null if no UCL this week)
  /// In 38-GW marathon: Group Stage GW 3, 6, 9, 12, 15, 18; QF GW 22/25; SF GW 28/31; Final GW 35
  /// In 18-GW sprint: Group Stage GW 2, 4, 6, 8, 10, 12; QF GW 14/15; SF GW 16/17; Final GW 18
  static int? getUclMatchdayForLeagueGw(int leagueGw, {int totalGameweeks = 38}) {
    if (totalGameweeks == 18) {
      switch (leagueGw) {
        case 2: return 1;
        case 4: return 2;
        case 6: return 3;
        case 8: return 4;
        case 10: return 5;
        case 12: return 6;
        case 14: return 7;  // QF Leg 1
        case 15: return 8;  // QF Leg 2
        case 16: return 9;  // SF Leg 1
        case 17: return 10; // SF Leg 2
        case 18: return 11; // Final
        default: return null;
      }
    }
    switch (leagueGw) {
      case 3: return 1;
      case 6: return 2;
      case 9: return 3;
      case 12: return 4;
      case 15: return 5;
      case 18: return 6;
      case 22: return 7;  // QF Leg 1
      case 25: return 8;  // QF Leg 2
      case 28: return 9;  // SF Leg 1
      case 31: return 10; // SF Leg 2
      case 35: return 11; // Final
      default: return null;
    }
  }

  /// Check if a knockout stage needs to be drawn and populated
  void checkAndAdvanceStages() {
    // 1. If group stage is finished (all 24 group matches played) and QF not generated
    final allGroupPlayed = groupFixtures.every((f) => f.isPlayed);
    if (allGroupPlayed && quarterFinals.isEmpty) {
      _generateQuarterFinals();
    }

    // 2. If QF is completed and SF not generated
    if (quarterFinals.isNotEmpty && quarterFinals.every((t) => t.isCompleted) && semiFinals.isEmpty) {
      for (final qf in quarterFinals) {
        qf.computeWinner();
      }
      _generateSemiFinals();
    }

    // 3. If SF is completed and Final not generated
    if (semiFinals.isNotEmpty && semiFinals.every((t) => t.isCompleted) && finalTie == null) {
      for (final sf in semiFinals) {
        sf.computeWinner();
      }
      _generateFinal();
    }

    // 4. If Final is completed
    if (finalTie != null && finalTie!.isCompleted && champion == null) {
      finalTie!.computeWinner();
      champion = finalTie!.winner;
    }
  }

  void _generateQuarterFinals() {
    // Sort tables to get 1st and 2nd from each group
    final winners = <String>[];
    final runnersUp = <String>[];

    for (final g in ['A', 'B', 'C', 'D']) {
      final table = groupTables[g]!;
      table.sort((a, b) {
        if (b.points != a.points) return b.points.compareTo(a.points);
        if (b.goalDifference != a.goalDifference) return b.goalDifference.compareTo(a.goalDifference);
        return b.goalsFor.compareTo(a.goalsFor);
      });
      winners.add(table[0].clubName);
      runnersUp.add(table[1].clubName);
    }

    // QF 1: Winner A vs Runner-up B
    // QF 2: Winner C vs Runner-up D
    // QF 3: Winner B vs Runner-up A
    // QF 4: Winner D vs Runner-up C
    final pairings = [
      [runnersUp[1], winners[0]],
      [runnersUp[3], winners[2]],
      [runnersUp[0], winners[1]],
      [runnersUp[2], winners[3]],
    ];

    final qfs = <UclKnockoutTie>[];
    int idCounter = 100;
    for (int i = 0; i < 4; i++) {
      final homeLeg1 = pairings[i][0];
      final awayLeg1 = pairings[i][1];
      qfs.add(UclKnockoutTie(
        stage: 'Quarter-Final ${i + 1}',
        clubA: homeLeg1,
        clubB: awayLeg1,
        leg1: UclFixture(
          id: 'ucl_qf_${idCounter++}_1',
          stage: 'Quarter-Final',
          matchday: 7,
          homeClub: homeLeg1,
          awayClub: awayLeg1,
        ),
        leg2: UclFixture(
          id: 'ucl_qf_${idCounter++}_2',
          stage: 'Quarter-Final',
          matchday: 8,
          homeClub: awayLeg1,
          awayClub: homeLeg1,
        ),
      ));
    }
    quarterFinals.clear();
    quarterFinals.addAll(qfs);
  }

  void _generateSemiFinals() {
    final w = quarterFinals.map((q) => q.winner!).toList();
    int idCounter = 200;
    semiFinals.clear();
    semiFinals.add(UclKnockoutTie(
      stage: 'Semi-Final 1',
      clubA: w[0],
      clubB: w[1],
      leg1: UclFixture(
        id: 'ucl_sf_${idCounter++}_1',
        stage: 'Semi-Final',
        matchday: 9,
        homeClub: w[0],
        awayClub: w[1],
      ),
      leg2: UclFixture(
        id: 'ucl_sf_${idCounter++}_2',
        stage: 'Semi-Final',
        matchday: 10,
        homeClub: w[1],
        awayClub: w[0],
      ),
    ));
    semiFinals.add(UclKnockoutTie(
      stage: 'Semi-Final 2',
      clubA: w[2],
      clubB: w[3],
      leg1: UclFixture(
        id: 'ucl_sf_${idCounter++}_1',
        stage: 'Semi-Final',
        matchday: 9,
        homeClub: w[2],
        awayClub: w[3],
      ),
      leg2: UclFixture(
        id: 'ucl_sf_${idCounter++}_2',
        stage: 'Semi-Final',
        matchday: 10,
        homeClub: w[3],
        awayClub: w[2],
      ),
    ));
  }

  void _generateFinal() {
    final finalist1 = semiFinals[0].winner!;
    final finalist2 = semiFinals[1].winner!;
    finalTie = UclKnockoutTie(
      stage: 'Final',
      clubA: finalist1,
      clubB: finalist2,
      leg1: UclFixture(
        id: 'ucl_final_300',
        stage: 'Final',
        matchday: 11,
        homeClub: finalist1,
        awayClub: finalist2,
      ),
    );
  }

  /// Record match result and update stats
  void recordFixtureResult(UclFixture fixture, MatchResult res) {
    fixture.result = res;

    // If group stage, update table
    if (fixture.stage.startsWith('Group')) {
      final gKey = fixture.stage.replaceAll('Group', '').trim();
      final table = groupTables[gKey];
      if (table != null) {
        final homeEntry = table.firstWhere((t) => t.clubName == fixture.homeClub);
        final awayEntry = table.firstWhere((t) => t.clubName == fixture.awayClub);
        homeEntry.recordResult(scored: res.homeGoals, conceded: res.awayGoals);
        awayEntry.recordResult(scored: res.awayGoals, conceded: res.homeGoals);
      }
    }

    // Track goals, assists, clean sheets in UCL
    for (final g in res.homeGoalEvents) {
      if (!g.isOwnGoal) {
        playerGoals[g.scorerName] = (playerGoals[g.scorerName] ?? 0) + 1;
        playerClubs[g.scorerName] = res.homeClub;
      }
      if (g.assisterName != null && g.assisterName!.isNotEmpty) {
        playerAssists[g.assisterName!] = (playerAssists[g.assisterName!] ?? 0) + 1;
      }
    }
    for (final g in res.awayGoalEvents) {
      if (!g.isOwnGoal) {
        playerGoals[g.scorerName] = (playerGoals[g.scorerName] ?? 0) + 1;
        playerClubs[g.scorerName] = res.awayClub;
      }
      if (g.assisterName != null && g.assisterName!.isNotEmpty) {
        playerAssists[g.assisterName!] = (playerAssists[g.assisterName!] ?? 0) + 1;
      }
    }

    // Check clean sheets
    if (res.awayGoals == 0) {
      playerCleanSheets[res.homeClub] = (playerCleanSheets[res.homeClub] ?? 0) + 1;
    }
    if (res.homeGoals == 0) {
      playerCleanSheets[res.awayClub] = (playerCleanSheets[res.awayClub] ?? 0) + 1;
    }

    checkAndAdvanceStages();
  }

  Map<String, dynamic> toMap() => {
    'userClub': userClub,
    'participants': participants,
    'groups': groups,
    'groupTables': groupTables.map((k, v) => MapEntry(k, v.map((e) => e.toMap()).toList())),
    'groupFixtures': groupFixtures.map((f) => f.toMap()).toList(),
    'quarterFinals': quarterFinals.map((t) => t.toMap()).toList(),
    'semiFinals': semiFinals.map((t) => t.toMap()).toList(),
    if (finalTie != null) 'finalTie': finalTie!.toMap(),
    if (champion != null) 'champion': champion,
    'playerGoals': playerGoals,
    'playerAssists': playerAssists,
    'playerCleanSheets': playerCleanSheets,
    'playerAppearances': playerAppearances,
    'playerClubs': playerClubs,
  };

  factory UclTournament.fromMap(Map<String, dynamic> map) {
    final userClub = map['userClub'] as String? ?? 'Arsenal';
    final participants = List<String>.from((map['participants'] as List?) ?? []);
    final groupsRaw = map['groups'] as Map<String, dynamic>? ?? {};
    final groups = groupsRaw.map((k, v) => MapEntry(k, List<String>.from((v as List?) ?? [])));

    final groupTablesRaw = map['groupTables'] as Map<String, dynamic>? ?? {};
    final groupTables = groupTablesRaw.map((k, v) => MapEntry(
      k,
      ((v as List?) ?? []).map((e) => TableEntry.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
    ));

    final groupFixtures = ((map['groupFixtures'] as List?) ?? [])
        .map((f) => UclFixture.fromMap(Map<String, dynamic>.from(f as Map)))
        .toList();

    final quarterFinals = ((map['quarterFinals'] as List?) ?? [])
        .map((t) => UclKnockoutTie.fromMap(Map<String, dynamic>.from(t as Map)))
        .toList();

    final semiFinals = ((map['semiFinals'] as List?) ?? [])
        .map((t) => UclKnockoutTie.fromMap(Map<String, dynamic>.from(t as Map)))
        .toList();

    final finalTie = map['finalTie'] != null
        ? UclKnockoutTie.fromMap(Map<String, dynamic>.from(map['finalTie'] as Map))
        : null;

    final tournament = UclTournament(
      userClub: userClub,
      participants: participants,
      groups: groups,
      groupTables: groupTables,
      groupFixtures: groupFixtures,
      quarterFinals: quarterFinals,
      semiFinals: semiFinals,
      finalTie: finalTie,
      champion: map['champion'] as String?,
    );

    if (map['playerGoals'] is Map) {
      (map['playerGoals'] as Map).forEach((k, v) => tournament.playerGoals[k.toString()] = (v as num).toInt());
    }
    if (map['playerAssists'] is Map) {
      (map['playerAssists'] as Map).forEach((k, v) => tournament.playerAssists[k.toString()] = (v as num).toInt());
    }
    if (map['playerCleanSheets'] is Map) {
      (map['playerCleanSheets'] as Map).forEach((k, v) => tournament.playerCleanSheets[k.toString()] = (v as num).toInt());
    }
    if (map['playerAppearances'] is Map) {
      (map['playerAppearances'] as Map).forEach((k, v) => tournament.playerAppearances[k.toString()] = (v as num).toInt());
    }
    if (map['playerClubs'] is Map) {
      (map['playerClubs'] as Map).forEach((k, v) => tournament.playerClubs[k.toString()] = v.toString());
    }

    return tournament;
  }
}
