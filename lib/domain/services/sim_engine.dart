import 'dart:math';

/// Represents an individual player in the simulation engine with position and rating.
class SimPlayer {
  final String name;
  final String position;
  final int overall;
  final bool isStarter;

  const SimPlayer({
    required this.name,
    this.position = 'CM',
    this.overall = 75,
    this.isStarter = true,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'pos': position,
    'ovr': overall,
    'starter': isStarter,
  };

  factory SimPlayer.fromMap(Map<String, dynamic> map) => SimPlayer(
    name: map['name'] as String? ?? 'Player',
    position: map['pos'] as String? ?? 'CM',
    overall: (map['ovr'] as num?)?.toInt() ?? 75,
    isStarter: map['starter'] as bool? ?? true,
  );
}

/// Represents an individual goal scored in a simulated match with scorer, assister and timestamp.
class GoalEvent {
  final String scorerName;
  final int minute;
  final bool isPenalty;
  final bool isOwnGoal;
  final String? assisterName;

  const GoalEvent({
    required this.scorerName,
    required this.minute,
    this.isPenalty = false,
    this.isOwnGoal = false,
    this.assisterName,
  });

  String get formatted {
    final suffix = isPenalty ? ' (pen)' : (isOwnGoal ? ' (og)' : '');
    final ast = (assisterName != null && assisterName!.isNotEmpty && !isPenalty && !isOwnGoal)
        ? ' [ast: $assisterName]'
        : '';
    return "$scorerName $minute'$suffix$ast";
  }

  Map<String, dynamic> toMap() => {
    'scorer': scorerName,
    'minute': minute,
    'pen': isPenalty,
    'og': isOwnGoal,
    if (assisterName != null) 'ast': assisterName,
  };

  factory GoalEvent.fromMap(Map<String, dynamic> map) => GoalEvent(
    scorerName: map['scorer'] as String? ?? 'Player',
    minute: (map['minute'] as num?)?.toInt() ?? 45,
    isPenalty: map['pen'] as bool? ?? false,
    isOwnGoal: map['og'] as bool? ?? false,
    assisterName: map['ast'] as String?,
  );
}

/// Represents a tactical substitution event during the match.
class SubstitutionEvent {
  final String playerOut;
  final String playerIn;
  final int minute;

  const SubstitutionEvent({
    required this.playerOut,
    required this.playerIn,
    required this.minute,
  });

  String get formatted => "⇄ $playerIn for $playerOut ($minute')";

  Map<String, dynamic> toMap() => {
    'out': playerOut,
    'in': playerIn,
    'min': minute,
  };

  factory SubstitutionEvent.fromMap(Map<String, dynamic> map) => SubstitutionEvent(
    playerOut: map['out'] as String? ?? 'Player Out',
    playerIn: map['in'] as String? ?? 'Player In',
    minute: (map['min'] as num?)?.toInt() ?? 60,
  );
}

/// Detailed match statistics for a club (possession, shots, corners, etc.)
class TeamMatchStats {
  final int shots;
  final int shotsOnTarget;
  final int possession; // percentage, e.g. 54
  final int corners;
  final int fouls;

  const TeamMatchStats({
    this.shots = 12,
    this.shotsOnTarget = 5,
    this.possession = 50,
    this.corners = 5,
    this.fouls = 10,
  });

  Map<String, dynamic> toMap() => {
    'shots': shots,
    'sot': shotsOnTarget,
    'pos': possession,
    'cor': corners,
    'fouls': fouls,
  };

  factory TeamMatchStats.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const TeamMatchStats();
    return TeamMatchStats(
      shots: (map['shots'] as num?)?.toInt() ?? 12,
      shotsOnTarget: (map['sot'] as num?)?.toInt() ?? 5,
      possession: (map['pos'] as num?)?.toInt() ?? 50,
      corners: (map['cor'] as num?)?.toInt() ?? 5,
      fouls: (map['fouls'] as num?)?.toInt() ?? 10,
    );
  }
}

/// Result of a single simulated match with rich stats, ratings and substitutions.
class MatchResult {
  final String homeClub;
  final String awayClub;
  final int homeGoals;
  final int awayGoals;
  final List<GoalEvent> homeGoalEvents;
  final List<GoalEvent> awayGoalEvents;
  final List<SubstitutionEvent> homeSubstitutions;
  final List<SubstitutionEvent> awaySubstitutions;
  final Map<String, double> homePlayerRatings;
  final Map<String, double> awayPlayerRatings;
  final TeamMatchStats homeStats;
  final TeamMatchStats awayStats;
  final String motm;
  final int attendance;

  const MatchResult({
    required this.homeClub,
    required this.awayClub,
    required this.homeGoals,
    required this.awayGoals,
    this.homeGoalEvents = const [],
    this.awayGoalEvents = const [],
    this.homeSubstitutions = const [],
    this.awaySubstitutions = const [],
    this.homePlayerRatings = const {},
    this.awayPlayerRatings = const {},
    this.homeStats = const TeamMatchStats(),
    this.awayStats = const TeamMatchStats(),
    this.motm = '',
    List<String>? homeScorers,
    List<String>? awayScorers,
    required this.attendance,
  });

  /// Backward-compatible list of scorer names
  List<String> get homeScorers => homeGoalEvents.isNotEmpty
      ? homeGoalEvents.map((g) => g.scorerName).toList()
      : const [];

  List<String> get awayScorers => awayGoalEvents.isNotEmpty
      ? awayGoalEvents.map((g) => g.scorerName).toList()
      : const [];

  String get scoreLine => '$homeClub $homeGoals – $awayGoals $awayClub';

  Map<String, dynamic> toMap() => {
    'homeClub': homeClub,
    'awayClub': awayClub,
    'homeGoals': homeGoals,
    'awayGoals': awayGoals,
    'homeEvents': homeGoalEvents.map((e) => e.toMap()).toList(),
    'awayEvents': awayGoalEvents.map((e) => e.toMap()).toList(),
    'homeSubs': homeSubstitutions.map((e) => e.toMap()).toList(),
    'awaySubs': awaySubstitutions.map((e) => e.toMap()).toList(),
    'homeRatings': homePlayerRatings,
    'awayRatings': awayPlayerRatings,
    'homeStats': homeStats.toMap(),
    'awayStats': awayStats.toMap(),
    'motm': motm,
    'attendance': attendance,
  };

  factory MatchResult.fromMap(Map<String, dynamic> map) {
    Map<String, double> parseRatings(dynamic r) {
      if (r is Map) {
        return r.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      }
      return {};
    }

    return MatchResult(
      homeClub: map['homeClub'] as String,
      awayClub: map['awayClub'] as String,
      homeGoals: (map['homeGoals'] as num).toInt(),
      awayGoals: (map['awayGoals'] as num).toInt(),
      homeGoalEvents: (map['homeEvents'] as List<dynamic>?)
              ?.map((e) => GoalEvent.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      awayGoalEvents: (map['awayEvents'] as List<dynamic>?)
              ?.map((e) => GoalEvent.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      homeSubstitutions: (map['homeSubs'] as List<dynamic>?)
              ?.map((e) => SubstitutionEvent.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      awaySubstitutions: (map['awaySubs'] as List<dynamic>?)
              ?.map((e) => SubstitutionEvent.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      homePlayerRatings: parseRatings(map['homeRatings']),
      awayPlayerRatings: parseRatings(map['awayRatings']),
      homeStats: TeamMatchStats.fromMap(map['homeStats'] as Map<String, dynamic>?),
      awayStats: TeamMatchStats.fromMap(map['awayStats'] as Map<String, dynamic>?),
      motm: map['motm'] as String? ?? '',
      attendance: (map['attendance'] as num?)?.toInt() ?? 40000,
    );
  }
}

/// League table row entry
class TableEntry {
  final String clubName;
  int played = 0;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
  int points = 0;

  TableEntry({required this.clubName});

  int get goalDifference => goalsFor - goalsAgainst;

  void recordResult({required int scored, required int conceded}) {
    played++;
    goalsFor += scored;
    goalsAgainst += conceded;
    if (scored > conceded) {
      won++;
      points += 3;
    } else if (scored == conceded) {
      drawn++;
      points += 1;
    } else {
      lost++;
    }
  }

  Map<String, dynamic> toMap() => {
    'clubName': clubName,
    'played': played,
    'won': won,
    'drawn': drawn,
    'lost': lost,
    'goalsFor': goalsFor,
    'goalsAgainst': goalsAgainst,
    'points': points,
  };

  factory TableEntry.fromMap(Map<String, dynamic> map) {
    final entry = TableEntry(clubName: map['clubName'] as String? ?? '');
    entry.played = (map['played'] as num?)?.toInt() ?? 0;
    entry.won = (map['won'] as num?)?.toInt() ?? 0;
    entry.drawn = (map['drawn'] as num?)?.toInt() ?? 0;
    entry.lost = (map['lost'] as num?)?.toInt() ?? 0;
    entry.goalsFor = (map['goalsFor'] as num?)?.toInt() ?? 0;
    entry.goalsAgainst = (map['goalsAgainst'] as num?)?.toInt() ?? 0;
    entry.points = (map['points'] as num?)?.toInt() ?? 0;
    return entry;
  }
}

/// Pure Dart Seeded Match Simulation Engine with authentic position-weighted scoring,
/// tactical substitutions, assists, player match ratings, and full match statistics.
class SimEngine {
  final Random _rng;

  SimEngine([int? seed]) : _rng = Random(seed ?? DateTime.now().millisecondsSinceEpoch);

  /// Simulate a match between two clubs
  MatchResult simulateMatch({
    required String homeClub,
    required double homeRating,
    required String awayClub,
    required double awayRating,
    List<String> homeSquad = const [],
    List<String> awaySquad = const [],
    List<SimPlayer>? homePlayers,
    List<SimPlayer>? awayPlayers,
  }) {
    // 1. Home advantage bonus (+2.5 rating points)
    final adjustedHomeRating = homeRating + 2.5;

    // Expected goals model
    final ratingDiff = adjustedHomeRating - awayRating;
    final homeExp = (1.45 + (ratingDiff * 0.08)).clamp(0.2, 4.5);
    final awayExp = (1.10 - (ratingDiff * 0.06)).clamp(0.1, 3.8);

    final homeGoals = _simulatePoisson(homeExp);
    final awayGoals = _simulatePoisson(awayExp);

    // 2. Resolve squads into SimPlayers (starters vs bench)
    final homeResolved = _resolveSquad(homePlayers, homeSquad, homeClub);
    final awayResolved = _resolveSquad(awayPlayers, awaySquad, awayClub);

    // 3. Generate second-half substitutions (between 52' and 78')
    final homeSubs = _generateSubstitutions(homeResolved);
    final awaySubs = _generateSubstitutions(awayResolved);

    // 4. Generate chronological goal events with position-weighted scorers, assists, penalties
    final homeGoalEvents = _generateGoalEvents(
      count: homeGoals,
      conceded: awayGoals,
      squad: homeResolved,
      opposingSquad: awayResolved,
      clubName: homeClub,
      subs: homeSubs,
    );

    final awayGoalEvents = _generateGoalEvents(
      count: awayGoals,
      conceded: homeGoals,
      squad: awayResolved,
      opposingSquad: homeResolved,
      clubName: awayClub,
      subs: awaySubs,
    );

    // 5. Generate player ratings (6.0 - 10.0 scale)
    final homeRatings = _calculatePlayerRatings(
      squad: homeResolved,
      subs: homeSubs,
      goalsScored: homeGoalEvents,
      goalsConceded: awayGoals,
    );

    final awayRatings = _calculatePlayerRatings(
      squad: awayResolved,
      subs: awaySubs,
      goalsScored: awayGoalEvents,
      goalsConceded: homeGoals,
    );

    // 6. Find Man of the Match (MOTM)
    String bestPlayer = '';
    double bestRating = -1.0;
    homeRatings.forEach((name, rating) {
      if (rating > bestRating) {
        bestRating = rating;
        bestPlayer = name;
      }
    });
    awayRatings.forEach((name, rating) {
      if (rating > bestRating) {
        bestRating = rating;
        bestPlayer = name;
      }
    });

    // 7. Team stats (possession, shots, corners, fouls)
    final possessionHome = (50 + ((homeRating - awayRating) * 1.2).round() + (_rng.nextInt(7) - 3)).clamp(35, 65);
    final possessionAway = 100 - possessionHome;

    final homeShots = max(homeGoals + 2, (homeExp * 4.5).round() + _rng.nextInt(6));
    final awayShots = max(awayGoals + 2, (awayExp * 4.5).round() + _rng.nextInt(6));

    final homeSot = min(homeShots, max(homeGoals, (homeShots * 0.42).round() + _rng.nextInt(3)));
    final awaySot = min(awayShots, max(awayGoals, (awayShots * 0.42).round() + _rng.nextInt(3)));

    final homeStats = TeamMatchStats(
      shots: homeShots,
      shotsOnTarget: homeSot,
      possession: possessionHome,
      corners: 3 + _rng.nextInt(8),
      fouls: 6 + _rng.nextInt(9),
    );

    final awayStats = TeamMatchStats(
      shots: awayShots,
      shotsOnTarget: awaySot,
      possession: possessionAway,
      corners: 2 + _rng.nextInt(7),
      fouls: 6 + _rng.nextInt(9),
    );

    final attendance = 25000 + _rng.nextInt(45000);

    return MatchResult(
      homeClub: homeClub,
      awayClub: awayClub,
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      homeGoalEvents: homeGoalEvents,
      awayGoalEvents: awayGoalEvents,
      homeSubstitutions: homeSubs,
      awaySubstitutions: awaySubs,
      homePlayerRatings: homeRatings,
      awayPlayerRatings: awayRatings,
      homeStats: homeStats,
      awayStats: awayStats,
      motm: bestPlayer,
      attendance: attendance,
    );
  }

  /// Checks whether a position string represents a Goalkeeper
  static bool isGoalkeeper(String pos) {
    final p = pos.toUpperCase().trim();
    return p == 'GK' || p.contains('GOAL');
  }

  /// Normalizes a squad so exactly 1 Goalkeeper starts in goal, 10 outfielders start,
  /// and any backup Goalkeeper is placed on the bench as reserve GK.
  static List<SimPlayer> normalizeSquadRoles(List<SimPlayer> squad) {
    if (squad.isEmpty) return squad;

    final gks = squad.where((p) => isGoalkeeper(p.position)).toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    final outfield = squad.where((p) => !isGoalkeeper(p.position)).toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));

    // Starter GK: highest rated GK, or fallback
    final starterGk = gks.isNotEmpty
        ? SimPlayer(name: gks[0].name, position: 'GK', overall: gks[0].overall, isStarter: true)
        : const SimPlayer(name: 'Starting Goalkeeper', position: 'GK', overall: 80, isStarter: true);

    // Starter Outfield: top 10 outfielders
    final starterOutfield = outfield.take(10).map((p) =>
        SimPlayer(name: p.name, position: p.position, overall: p.overall, isStarter: true)).toList();

    // Bench GK: 2nd GK if present
    final benchGk = gks.length > 1
        ? [SimPlayer(name: gks[1].name, position: 'GK', overall: gks[1].overall, isStarter: false)]
        : <SimPlayer>[];

    // Bench Outfield: remaining outfielders
    final benchOutfield = outfield.skip(10).map((p) =>
        SimPlayer(name: p.name, position: p.position, overall: p.overall, isStarter: false)).toList();

    // Any remaining surplus GKs (rare 3rd GK)
    final extraGks = gks.length > 2
        ? gks.skip(2).map((p) => SimPlayer(name: p.name, position: 'GK', overall: p.overall, isStarter: false)).toList()
        : <SimPlayer>[];

    return [
      starterGk,
      ...starterOutfield,
      ...benchGk,
      ...benchOutfield,
      ...extraGks,
    ];
  }

  /// Converts input squad to `List<SimPlayer>` if needed, ensuring 11 starters and bench
  List<SimPlayer> _resolveSquad(List<SimPlayer>? simPlayers, List<String> squadNames, String clubName) {
    if (simPlayers != null && simPlayers.isNotEmpty) {
      return normalizeSquadRoles(simPlayers);
    }

    if (squadNames.isNotEmpty) {
      final list = <SimPlayer>[];
      for (int i = 0; i < squadNames.length; i++) {
        final name = squadNames[i];
        final isStarter = i < 11;
        String pos = 'CM';
        if (i == 0 || i == 11) {
          pos = 'GK';
        } else if ((i >= 1 && i <= 4) || i == 12 || i == 13) {
          pos = 'CB';
        } else if ((i >= 5 && i <= 8) || i == 14 || i == 15) {
          pos = 'CM';
        } else {
          pos = 'ST';
        }

        list.add(SimPlayer(
          name: name,
          position: pos,
          overall: 78,
          isStarter: isStarter,
        ));
      }
      return normalizeSquadRoles(list);
    }

    // Default template squad if completely empty
    return [
      SimPlayer(name: '$clubName GK', position: 'GK', overall: 80, isStarter: true),
      SimPlayer(name: '$clubName LB', position: 'LB', overall: 78, isStarter: true),
      SimPlayer(name: '$clubName CB1', position: 'CB', overall: 82, isStarter: true),
      SimPlayer(name: '$clubName CB2', position: 'CB', overall: 81, isStarter: true),
      SimPlayer(name: '$clubName RB', position: 'RB', overall: 79, isStarter: true),
      SimPlayer(name: '$clubName CDM', position: 'CDM', overall: 80, isStarter: true),
      SimPlayer(name: '$clubName CM', position: 'CM', overall: 82, isStarter: true),
      SimPlayer(name: '$clubName CAM', position: 'CAM', overall: 83, isStarter: true),
      SimPlayer(name: '$clubName LW', position: 'LW', overall: 84, isStarter: true),
      SimPlayer(name: '$clubName RW', position: 'RW', overall: 83, isStarter: true),
      SimPlayer(name: '$clubName ST', position: 'ST', overall: 85, isStarter: true),
      // Bench
      SimPlayer(name: '$clubName Sub GK', position: 'GK', overall: 74, isStarter: false),
      SimPlayer(name: '$clubName Sub DEF', position: 'CB', overall: 76, isStarter: false),
      SimPlayer(name: '$clubName Sub MID', position: 'CM', overall: 77, isStarter: false),
      SimPlayer(name: '$clubName Sub FWD', position: 'ST', overall: 78, isStarter: false),
    ];
  }

  /// Generate 1-3 tactical substitutions between minutes 52 and 78
  /// Goalkeepers are NEVER substituted with outfield players (Fix 25 / User Fix 3)
  List<SubstitutionEvent> _generateSubstitutions(List<SimPlayer> squad) {
    final starters = squad.where((p) => p.isStarter).toList();
    final bench = squad.where((p) => !p.isStarter).toList();

    if (starters.isEmpty || bench.isEmpty) return const [];

    // Strictly outfield players only for both starters leaving and bench entering
    final availableStarters = List<SimPlayer>.from(starters.where((p) => !isGoalkeeper(p.position)));
    final availableBench = List<SimPlayer>.from(bench.where((p) => !isGoalkeeper(p.position)));

    if (availableStarters.isEmpty || availableBench.isEmpty) return const [];

    final subCount = 1 + _rng.nextInt(min(3, availableBench.length));
    final subMinutes = <int>{};
    while (subMinutes.length < subCount) {
      subMinutes.add(52 + _rng.nextInt(26)); // 52 to 77
    }
    final sortedMinutes = subMinutes.toList()..sort();
    final events = <SubstitutionEvent>[];

    for (final minute in sortedMinutes) {
      if (availableStarters.isEmpty || availableBench.isEmpty) break;

      // Pick outfield starter to sub off (prefer lower-rated)
      availableStarters.sort((a, b) => a.overall.compareTo(b.overall));
      final outIndex = _rng.nextInt(min(3, availableStarters.length));
      final playerOut = availableStarters.removeAt(outIndex);

      // Find compatible outfield bench sub (same general line: DEF, MID, FWD)
      SimPlayer playerIn;
      final samePos = availableBench.where((b) => _isSameCategory(b.position, playerOut.position)).toList();
      if (samePos.isNotEmpty) {
        playerIn = samePos[_rng.nextInt(samePos.length)];
        availableBench.remove(playerIn);
      } else {
        playerIn = availableBench.removeAt(_rng.nextInt(availableBench.length));
      }

      events.add(SubstitutionEvent(
        playerOut: playerOut.name,
        playerIn: playerIn.name,
        minute: minute,
      ));
    }

    return events;
  }

  bool _isSameCategory(String posA, String posB) {
    if (isGoalkeeper(posA) || isGoalkeeper(posB)) return false;
    bool isDef(String p) => const ['CB', 'LB', 'RB', 'LWB', 'RWB'].contains(p);
    bool isMid(String p) => const ['CM', 'CAM', 'CDM', 'LM', 'RM'].contains(p);
    bool isFwd(String p) => const ['ST', 'CF', 'LW', 'RW'].contains(p);

    if (isDef(posA) && isDef(posB)) return true;
    if (isMid(posA) && isMid(posB)) return true;
    if (isFwd(posA) && isFwd(posB)) return true;
    return false;
  }

  /// Generate chronological goal events with position-weighted scoring & assists
  List<GoalEvent> _generateGoalEvents({
    required int count,
    required int conceded,
    required List<SimPlayer> squad,
    required List<SimPlayer> opposingSquad,
    required String clubName,
    required List<SubstitutionEvent> subs,
  }) {
    if (count <= 0) return const [];
    final events = <GoalEvent>[];
    final minutes = <int>{};
    while (minutes.length < count) {
      minutes.add(2 + _rng.nextInt(91));
    }
    final sortedMinutes = minutes.toList()..sort();

    for (final minute in sortedMinutes) {
      // Determine active players on the pitch at this minute
      final activeSquad = _getActivePlayersAtMinute(squad, subs, minute);

      final isOwnGoal = _rng.nextDouble() < 0.025; // 2.5% chance of own goal
      final isPenalty = !isOwnGoal && (_rng.nextDouble() < 0.10); // 10% penalty chance

      if (isOwnGoal) {
        // Own goal by opposing defender
        final oppDefs = opposingSquad.where((p) => ['CB', 'LB', 'RB'].contains(p.position)).toList();
        final ogPlayer = oppDefs.isNotEmpty
            ? oppDefs[_rng.nextInt(oppDefs.length)].name
            : 'Opponent Defender';
        events.add(GoalEvent(
          scorerName: ogPlayer,
          minute: minute,
          isPenalty: false,
          isOwnGoal: true,
          assisterName: null,
        ));
        continue;
      }

      // Pick scorer using position & rating weights
      final scorer = _pickScorer(activeSquad, isPenalty, clubName);

      // Pick assist (if not penalty and ~72% chance of open-play assist)
      String? assister;
      if (!isPenalty && _rng.nextDouble() < 0.72) {
        assister = _pickAssister(activeSquad, scorer.name);
      }

      events.add(GoalEvent(
        scorerName: scorer.name,
        minute: minute,
        isPenalty: isPenalty,
        isOwnGoal: false,
        assisterName: assister,
      ));
    }

    return events;
  }

  List<SimPlayer> _getActivePlayersAtMinute(List<SimPlayer> fullSquad, List<SubstitutionEvent> subs, int minute) {
    final active = fullSquad.where((p) => p.isStarter).toList();
    for (final s in subs) {
      if (s.minute <= minute) {
        active.removeWhere((p) => p.name == s.playerOut);
        final subPlayer = fullSquad.firstWhere(
          (p) => p.name == s.playerIn,
          orElse: () => SimPlayer(name: s.playerIn, position: 'CM', overall: 75, isStarter: false),
        );
        if (!active.any((p) => p.name == subPlayer.name)) {
          active.add(subPlayer);
        }
      }
    }
    return active.isNotEmpty ? active : fullSquad;
  }

  /// Realistic position-weighted scorer selection (Fix 25 / User Fix 3)
  /// - Forwards score most, then attacking midfielders, midfielders, defenders
  /// - Higher-rated players score exponentially more
  /// - Goalkeepers have strictly < 0.1% chance of scoring
  SimPlayer _pickScorer(List<SimPlayer> activeSquad, bool isPenalty, String clubName) {
    if (activeSquad.isEmpty) {
      return SimPlayer(name: '$clubName Striker', position: 'ST', overall: 80);
    }

    if (isPenalty) {
      // Penalty taker: strictly pick highest-rated forward, attacking midfielder, or outfielder. Never GK!
      final attackingTakers = activeSquad
          .where((p) => !isGoalkeeper(p.position) && ['ST', 'CF', 'LW', 'RW', 'CAM'].contains(p.position))
          .toList();
      if (attackingTakers.isNotEmpty) {
        attackingTakers.sort((a, b) => b.overall.compareTo(a.overall));
        return attackingTakers.first;
      }
      final anyOutfielder = activeSquad.where((p) => !isGoalkeeper(p.position)).toList();
      if (anyOutfielder.isNotEmpty) {
        anyOutfielder.sort((a, b) => b.overall.compareTo(a.overall));
        return anyOutfielder.first;
      }
      return activeSquad.first;
    }

    // Weight table by position (Forwards > Wingers > Attacking Mids > Central Mids > Def Mids > Defenders >>> Goalkeepers)
    double positionWeight(String pos) {
      switch (pos) {
        case 'ST':
        case 'CF':
          return 50.0;
        case 'LW':
        case 'RW':
          return 28.0;
        case 'CAM':
          return 14.0;
        case 'CM':
        case 'LM':
        case 'RM':
          return 5.5;
        case 'CDM':
          return 1.8;
        case 'CB':
        case 'LB':
        case 'RB':
        case 'LWB':
        case 'RWB':
          return 0.8;
        case 'GK':
          return 0.0002; // Goalkeeper scoring chance strictly < 0.1%
        default:
          return 5.0;
      }
    }

    final weights = <double>[];
    double totalWeight = 0.0;
    for (final p in activeSquad) {
      final base = isGoalkeeper(p.position) ? 0.0002 : positionWeight(p.position);
      // Rating multiplier: higher rated players score significantly more (exponential 3.2 curve)
      final ovrBonus = pow((p.overall.clamp(50, 99)) / 75.0, 3.2);
      final w = base * ovrBonus;
      weights.add(w.toDouble());
      totalWeight += w;
    }

    if (totalWeight <= 0) {
      final outf = activeSquad.where((p) => !isGoalkeeper(p.position)).toList();
      return outf.isNotEmpty ? outf.first : activeSquad.first;
    }

    final roll = _rng.nextDouble() * totalWeight;
    double cumulative = 0.0;
    for (int i = 0; i < activeSquad.length; i++) {
      cumulative += weights[i];
      if (roll <= cumulative) {
        final chosen = activeSquad[i];
        // Hard-cap guard: Goalkeeper scoring probability strictly < 0.1% (< 0.001)
        if (isGoalkeeper(chosen.position)) {
          if (_rng.nextDouble() > 0.0008) {
            final outfielders = activeSquad.where((p) => !isGoalkeeper(p.position)).toList();
            if (outfielders.isNotEmpty) {
              return _pickScorer(outfielders, false, clubName);
            }
          }
        }
        return chosen;
      }
    }

    final fallback = activeSquad.where((p) => !isGoalkeeper(p.position)).toList();
    return fallback.isNotEmpty ? fallback.first : activeSquad.first;
  }

  /// Realistic assist selection
  String? _pickAssister(List<SimPlayer> activeSquad, String scorerName) {
    final candidates = activeSquad.where((p) => p.name != scorerName).toList();
    if (candidates.isEmpty) return null;

    double assistWeight(String pos) {
      switch (pos) {
        case 'CAM':
          return 35.0;
        case 'CM':
        case 'LM':
        case 'RM':
          return 25.0;
        case 'LW':
        case 'RW':
          return 22.0;
        case 'ST':
        case 'CF':
          return 14.0;
        case 'LB':
        case 'RB':
        case 'LWB':
        case 'RWB':
          return 11.0;
        case 'CDM':
          return 8.0;
        case 'CB':
          return 3.0;
        case 'GK':
          return 0.005; // Goalkeeper long goal-kick assist is exceptionally rare
        default:
          return 5.0;
      }
    }

    final weights = <double>[];
    double totalWeight = 0.0;
    for (final p in candidates) {
      final base = isGoalkeeper(p.position) ? 0.005 : assistWeight(p.position);
      final w = base * pow((p.overall.clamp(50, 99)) / 75.0, 2.5);
      weights.add(w.toDouble());
      totalWeight += w;
    }

    final roll = _rng.nextDouble() * totalWeight;
    double cumulative = 0.0;
    for (int i = 0; i < candidates.length; i++) {
      cumulative += weights[i];
      if (roll <= cumulative) {
        return candidates[i].name;
      }
    }

    return candidates.first.name;
  }

  /// Generates authentic player ratings (6.0 - 10.0 scale)
  Map<String, double> _calculatePlayerRatings({
    required List<SimPlayer> squad,
    required List<SubstitutionEvent> subs,
    required List<GoalEvent> goalsScored,
    required int goalsConceded,
  }) {
    final ratings = <String, double>{};
    final appeared = <SimPlayer>{};

    // Starters appeared
    for (final p in squad.where((s) => s.isStarter)) {
      appeared.add(p);
    }
    // Subs appeared
    for (final sub in subs) {
      final subP = squad.firstWhere(
        (p) => p.name == sub.playerIn,
        orElse: () => SimPlayer(name: sub.playerIn, position: 'CM', overall: 75, isStarter: false),
      );
      appeared.add(subP);
    }

    // Count goals and assists per player
    final goalCounts = <String, int>{};
    final assistCounts = <String, int>{};
    for (final g in goalsScored) {
      if (!g.isOwnGoal) {
        goalCounts[g.scorerName] = (goalCounts[g.scorerName] ?? 0) + 1;
      }
      if (g.assisterName != null && g.assisterName!.isNotEmpty) {
        assistCounts[g.assisterName!] = (assistCounts[g.assisterName!] ?? 0) + 1;
      }
    }

    for (final p in appeared) {
      // Base rating
      double r = 6.4 + (_rng.nextDouble() * 0.7 - 0.35); // 6.05 to 6.75 base

      // Goals bonus
      final goals = goalCounts[p.name] ?? 0;
      r += goals * 1.05;

      // Assists bonus
      final assists = assistCounts[p.name] ?? 0;
      r += assists * 0.65;

      // Clean sheet or defensive bonus
      final isDefOrGk = ['GK', 'CB', 'LB', 'RB', 'LWB', 'RWB'].contains(p.position);
      if (isDefOrGk) {
        if (goalsConceded == 0) {
          r += 0.9; // Clean sheet boost
        } else if (goalsConceded >= 2) {
          r -= (goalsConceded - 1) * 0.35;
        }
      }

      // Rating quality bonus based on player OVR
      r += (p.overall - 78) * 0.02;

      // Clamp between 4.8 and 10.0
      r = r.clamp(4.8, 10.0);
      ratings[p.name] = double.parse(r.toStringAsFixed(1));
    }

    return ratings;
  }

  /// Poisson approximation using Knuth's algorithm
  int _simulatePoisson(double lambda) {
    final l = exp(-lambda);
    double p = 1.0;
    int k = 0;
    do {
      k++;
      p *= _rng.nextDouble();
    } while (p > l);
    return k - 1;
  }
}
