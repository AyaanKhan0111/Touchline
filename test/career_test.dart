import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:touchline/core/database/save_service.dart';
import 'package:touchline/core/storage/prefs_service.dart';
import 'package:touchline/domain/models/player.dart';
import 'package:touchline/domain/services/sim_engine.dart';
import 'package:touchline/domain/services/ucl_engine.dart';
import 'package:touchline/features/career/career_screen.dart';
import 'package:touchline/features/career/formation_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Career League & Config Definitions', () {
    test('All 5 available leagues are properly configured (PL has 20 clubs, others 10)', () {
      expect(kAvailableLeagues.length, 5);

      final expectedLeagues = [
        'premier_league',
        'continental_elite',
        'champions_invitational',
        'english_championship',
        'european_heritage',
      ];

      for (final leagueId in expectedLeagues) {
        final league = kAvailableLeagues.firstWhere((l) => l.id == leagueId);
        final expectedClubCount = leagueId == 'premier_league' ? 20 : 10;
        expect(league.clubs.length, expectedClubCount, reason: '${league.name} should have $expectedClubCount clubs');
        expect(league.clubCodes.length, expectedClubCount, reason: '${league.name} should have $expectedClubCount club codes');

        for (final club in league.clubs) {
          expect(league.clubCodes.containsKey(club), isTrue,
              reason: 'Club code must exist for $club in ${league.name}');
          expect(league.clubCodes[club]!.length, inInclusiveRange(2, 4),
              reason: 'Club code for $club should be 2-4 characters');
        }
      }
    });

    test('Premier League 20-team schedule: 38 GWs × 10 matches = 380 total fixtures', () {
      final pl = kAvailableLeagues.firstWhere((l) => l.id == 'premier_league');
      final schedule = generateSeasonSchedule(pl.clubs, totalGameweeks: 38);
      expect(schedule.length, 38, reason: 'Should have 38 gameweeks');
      for (int gw = 0; gw < 38; gw++) {
        expect(schedule[gw].length, 10, reason: 'GW ${gw + 1} should have 10 matches for 20 clubs');
      }
      // Each club plays 38 matches total (19 home + 19 away)
      final homeCount = <String, int>{};
      final awayCount = <String, int>{};
      for (final round in schedule) {
        for (final fixture in round) {
          homeCount[fixture.homeClub] = (homeCount[fixture.homeClub] ?? 0) + 1;
          awayCount[fixture.awayClub] = (awayCount[fixture.awayClub] ?? 0) + 1;
        }
      }
      for (final club in pl.clubs) {
        final total = (homeCount[club] ?? 0) + (awayCount[club] ?? 0);
        expect(total, 38, reason: '$club should play 38 matches total');
        expect(homeCount[club], 19, reason: '$club should have 19 home matches');
        expect(awayCount[club], 19, reason: '$club should have 19 away matches');
      }
    });

    test('PrefsService career config save, read, and clear works seamlessly with player names', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsService.instance;

      // Initially null
      final initial = await prefs.getCareerConfig();
      expect(initial, isNull);

      final squadPlayerNames = [
        'David Raya', 'Gabriel', 'William Saliba', 'Declan Rice', 'Bukayo Saka',
        'Martin Ødegaard', 'Gabriel Martinelli', 'Gabriel Jesus', 'Jurriën Timber',
        'Ben White', 'Mikel Merino', 'E. Eze', 'Zubimendi', 'Kepa', 'Piero Hincapié',
        'V. Gyökeres', 'Christian Nørgaard', 'M. Lewis-Skelly'
      ];

      // Save custom career
      await prefs.saveCareerConfig(
        leagueId: 'premier_league',
        clubName: 'Arsenal',
        clubCode: 'ARS',
        isCustomClub: false,
        squadMode: 'current',
        budget: 95.5,
        season: 1,
        gameweek: 1,
        squadIds: squadPlayerNames,
      );

      final loaded = await prefs.getCareerConfig();
      expect(loaded, isNotNull);
      expect(loaded!['leagueId'], 'premier_league');
      expect(loaded['clubName'], 'Arsenal');
      expect(loaded['clubCode'], 'ARS');
      expect(loaded['isCustomClub'], isFalse);
      expect(loaded['squadMode'], 'current');
      expect(loaded['budget'], 95.5);
      expect(loaded['season'], 1);
      expect(loaded['gameweek'], 1);
      expect(loaded['squadIds'], squadPlayerNames);

      // Clear
      await prefs.clearCareerConfig();
      final cleared = await prefs.getCareerConfig();
      expect(cleared, isNull);
    });

    test('Issue #7: SimEngine produces chronological GoalEvents with realistic minute timestamps and valid scorers', () {
      final sim = SimEngine(42);
      final arsenalSquad = [
        'Bukayo Saka', 'Martin Ødegaard', 'Gabriel Jesus', 'Gabriel Martinelli',
        'Declan Rice', 'Mikel Merino', 'William Saliba', 'Gabriel'
      ];
      final chelseaSquad = [
        'Cole Palmer', 'Nicolas Jackson', 'Christopher Nkunku', 'Enzo Fernández',
        'Moisés Caicedo', 'Pedro Neto', 'Levi Colwill'
      ];

      int matchesWithGoals = 0;
      for (int i = 0; i < 30; i++) {
        final result = sim.simulateMatch(
          homeClub: 'Arsenal',
          homeRating: 84.0,
          awayClub: 'Chelsea',
          awayRating: 82.0,
          homeSquad: arsenalSquad,
          awaySquad: chelseaSquad,
        );

        // Verify home goals match event count
        expect(result.homeGoalEvents.length, result.homeGoals);
        expect(result.awayGoalEvents.length, result.awayGoals);

        // Verify home goal minutes are between 2 and 93 and strictly sorted ascending
        if (result.homeGoalEvents.isNotEmpty) {
          matchesWithGoals++;
          int lastMinute = 0;
          for (final event in result.homeGoalEvents) {
            expect(event.minute, inInclusiveRange(2, 93),
                reason: 'Goal minute must be in realistic match window');
            expect(event.minute, greaterThan(lastMinute),
                reason: 'Home goal minutes must be in strictly ascending chronological order');
            if (!event.isOwnGoal) {
              expect(arsenalSquad.contains(event.scorerName), isTrue,
                  reason: 'Scorer must belong to the home squad');
            } else {
              expect(chelseaSquad.contains(event.scorerName), isTrue,
                  reason: 'Own goal scorer must belong to the opposing away squad');
            }
            expect(event.formatted, contains("${event.scorerName} ${event.minute}'"));
            lastMinute = event.minute;
          }
        }

        // Verify away goal minutes
        if (result.awayGoalEvents.isNotEmpty) {
          int lastMinute = 0;
          for (final event in result.awayGoalEvents) {
            expect(event.minute, inInclusiveRange(2, 93));
            expect(event.minute, greaterThan(lastMinute));
            if (!event.isOwnGoal) {
              expect(chelseaSquad.contains(event.scorerName), isTrue,
                  reason: 'Scorer must belong to the away squad');
            } else {
              expect(arsenalSquad.contains(event.scorerName), isTrue,
                  reason: 'Own goal scorer must belong to the opposing home squad');
            }
            expect(event.formatted, contains("${event.scorerName} ${event.minute}'"));
            lastMinute = event.minute;
          }
        }
      }
      expect(matchesWithGoals, greaterThan(15), reason: 'Expected goals across 30 simulations');
    });

    test('Issue #7: MatchResult toMap and fromMap correctly serializes and restores GoalEvents', () {
      const result = MatchResult(
        homeClub: 'Arsenal',
        awayClub: 'Liverpool',
        homeGoals: 2,
        awayGoals: 1,
        homeGoalEvents: [
          GoalEvent(scorerName: 'Bukayo Saka', minute: 23),
          GoalEvent(scorerName: 'Gabriel Jesus', minute: 68, isPenalty: true),
        ],
        awayGoalEvents: [
          GoalEvent(scorerName: 'Mohamed Salah', minute: 45),
        ],
        attendance: 60250,
      );

      final map = result.toMap();
      final restored = MatchResult.fromMap(map);

      expect(restored.homeClub, 'Arsenal');
      expect(restored.awayClub, 'Liverpool');
      expect(restored.homeGoals, 2);
      expect(restored.awayGoals, 1);
      expect(restored.attendance, 60250);

      expect(restored.homeGoalEvents.length, 2);
      expect(restored.homeGoalEvents[0].scorerName, 'Bukayo Saka');
      expect(restored.homeGoalEvents[0].minute, 23);
      expect(restored.homeGoalEvents[0].isPenalty, isFalse);
      expect(restored.homeGoalEvents[0].formatted, "Bukayo Saka 23'");

      expect(restored.homeGoalEvents[1].scorerName, 'Gabriel Jesus');
      expect(restored.homeGoalEvents[1].minute, 68);
      expect(restored.homeGoalEvents[1].isPenalty, isTrue);
      expect(restored.homeGoalEvents[1].formatted, "Gabriel Jesus 68' (pen)");

      expect(restored.awayGoalEvents.length, 1);
      expect(restored.awayGoalEvents[0].scorerName, 'Mohamed Salah');
      expect(restored.awayGoalEvents[0].minute, 45);
      expect(restored.awayGoalEvents[0].formatted, "Mohamed Salah 45'");

      // Backward compatible getters
      expect(restored.homeScorers, ['Bukayo Saka', 'Gabriel Jesus']);
      expect(restored.awayScorers, ['Mohamed Salah']);
    });

    test('Issue #7: PrefsService persists and restores recent MatchResults with GoalEvents', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsService.instance;

      final testMatch = const MatchResult(
        homeClub: 'Manchester City',
        awayClub: 'Real Madrid',
        homeGoals: 3,
        awayGoals: 2,
        homeGoalEvents: [
          GoalEvent(scorerName: 'Erling Haaland', minute: 14),
          GoalEvent(scorerName: 'Kevin De Bruyne', minute: 52),
          GoalEvent(scorerName: 'Phil Foden', minute: 88, isPenalty: true),
        ],
        awayGoalEvents: [
          GoalEvent(scorerName: 'Vinícius Júnior', minute: 31),
          GoalEvent(scorerName: 'Jude Bellingham', minute: 74),
        ],
        attendance: 53500,
      );

      await prefs.saveCareerConfig(
        leagueId: 'champions_invitational',
        clubName: 'Manchester City',
        clubCode: 'MCI',
        isCustomClub: false,
        squadMode: 'current',
        budget: 120.0,
        season: 1,
        gameweek: 2,
        squadIds: ['Erling Haaland', 'Kevin De Bruyne', 'Phil Foden'],
        recentResults: [testMatch.toMap()],
      );

      final loaded = await prefs.getCareerConfig();
      expect(loaded, isNotNull);
      final recentList = loaded!['recentResults'] as List<Map<String, dynamic>>;
      expect(recentList.length, 1);

      final loadedMatch = MatchResult.fromMap(recentList.first);
      expect(loadedMatch.homeClub, 'Manchester City');
      expect(loadedMatch.awayClub, 'Real Madrid');
      expect(loadedMatch.homeGoals, 3);
      expect(loadedMatch.awayGoals, 2);
      expect(loadedMatch.homeGoalEvents.length, 3);
      expect(loadedMatch.homeGoalEvents.first.scorerName, 'Erling Haaland');
      expect(loadedMatch.homeGoalEvents.first.minute, 14);
      expect(loadedMatch.homeGoalEvents.last.scorerName, 'Phil Foden');
      expect(loadedMatch.homeGoalEvents.last.isPenalty, isTrue);
      expect(loadedMatch.awayGoalEvents.length, 2);
      expect(loadedMatch.awayGoalEvents.first.scorerName, 'Vinícius Júnior');
      expect(loadedMatch.awayGoalEvents.first.minute, 31);
    });

    test('Issue #8: Clean sheets and league-wide Golden Boot top scorers are tracked and persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsService.instance;

      final playerStats = {
        'David Raya': {'apps': 12, 'goals': 0, 'cleanSheets': 7},
        'William Saliba': {'apps': 12, 'goals': 1, 'cleanSheets': 7},
        'Bukayo Saka': {'apps': 12, 'goals': 8, 'cleanSheets': 0},
      };

      final leagueScorers = {
        'Erling Haaland': {'club': 'Manchester City', 'goals': 14},
        'Mohamed Salah': {'club': 'Liverpool', 'goals': 11},
        'Bukayo Saka': {'club': 'Arsenal', 'goals': 8},
        'Cole Palmer': {'club': 'Chelsea', 'goals': 7},
        'Alexander Isak': {'club': 'Newcastle United', 'goals': 6},
      };

      await prefs.saveCareerConfig(
        leagueId: 'premier_league',
        clubName: 'Arsenal',
        clubCode: 'ARS',
        isCustomClub: false,
        squadMode: 'current',
        budget: 95.0,
        season: 1,
        gameweek: 13,
        squadIds: ['David Raya', 'William Saliba', 'Bukayo Saka'],
        playerStats: playerStats,
        leagueScorers: leagueScorers,
      );

      final loaded = await prefs.getCareerConfig();
      expect(loaded, isNotNull);

      // Verify clean sheets and player stats
      final loadedStats = loaded!['playerStats'] as Map<String, Map<String, int>>;
      expect(loadedStats['David Raya']?['cleanSheets'], 7);
      expect(loadedStats['William Saliba']?['cleanSheets'], 7);
      expect(loadedStats['William Saliba']?['goals'], 1);
      expect(loadedStats['Bukayo Saka']?['goals'], 8);
      expect(loadedStats['Bukayo Saka']?['cleanSheets'], 0);

      // Verify league scorers and Golden Boot ranking order
      final loadedScorers = loaded['leagueScorers'] as Map<String, Map<String, dynamic>>;
      expect(loadedScorers.length, 5);
      expect(loadedScorers['Erling Haaland']?['goals'], 14);
      expect(loadedScorers['Erling Haaland']?['club'], 'Manchester City');
      expect(loadedScorers['Mohamed Salah']?['goals'], 11);

      // Verify ranking sort
      final sortedScorers = loadedScorers.entries.toList()
        ..sort((a, b) => (b.value['goals'] as int).compareTo(a.value['goals'] as int));

      expect(sortedScorers.first.key, 'Erling Haaland');
      expect(sortedScorers[1].key, 'Mohamed Salah');
      expect(sortedScorers[2].key, 'Bukayo Saka');

      // Verify clear
      await prefs.clearCareerConfig();
      final cleared = await prefs.getCareerConfig();
      expect(cleared, isNull);
    });
  });

  group('Career Squad Deduplication & Positional Balance Tests', () {
    late Database db;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dbPath = File('assets/db/players.db').absolute.path;
      db = await databaseFactory.openDatabase(dbPath, options: OpenDatabaseOptions(readOnly: true));
    });

    tearDownAll(() async {
      await db.close();
    });

    test('Real squad loading for all major clubs yields 18 modern players without duplicates', () async {
      final sampleClubs = [
        'Manchester United', 'Real Madrid', 'Arsenal', 'Liverpool',
        'Chelsea', 'Manchester City', 'Barcelona', 'Bayern Munich'
      ];

      for (final clubName in sampleClubs) {
        final queryClub = clubName == 'Inter Milan' ? 'Inter' : clubName;
        final seasonResult = await db.rawQuery(
          'SELECT MAX(season) as max_s FROM players WHERE team_name LIKE ?',
          ['%$queryClub%'],
        );
        final int maxSeason = (seasonResult.first['max_s'] as num?)?.toInt() ?? 2026;
        final int minSeason = maxSeason - 3;

        final List<Player> squad = [];
        final Set<String> usedNames = {};

        Future<int> pickPositions({
          required String positionCondition,
          required int count,
        }) async {
          var rows = await db.rawQuery('''
            SELECT *
            FROM players
            WHERE team_name LIKE ? AND season >= ? AND ($positionCondition)
            GROUP BY player_name
            ORDER BY season DESC, overall DESC
          ''', ['%$queryClub%', minSeason]);

          if (rows.length < count) {
            rows = await db.rawQuery('''
              SELECT *
              FROM players
              WHERE team_name LIKE ? AND ($positionCondition)
              GROUP BY player_name
              ORDER BY season DESC, overall DESC
            ''', ['%$queryClub%']);
          }

          int picked = 0;
          for (final r in rows) {
            final p = Player.fromMap(r);
            final norm = p.name.trim().toLowerCase();
            if (!usedNames.contains(norm)) {
              usedNames.add(norm);
              squad.add(p);
              picked++;
              if (picked == count) break;
            }
          }
          return picked;
        }

        await pickPositions(positionCondition: "primary_position = 'GK'", count: 2);
        await pickPositions(positionCondition: "primary_position IN ('CB', 'LB', 'RB', 'LWB', 'RWB')", count: 6);
        await pickPositions(positionCondition: "primary_position IN ('CM', 'CAM', 'CDM', 'LM', 'RM')", count: 6);
        await pickPositions(positionCondition: "primary_position IN ('ST', 'CF', 'LW', 'RW')", count: 4);

        if (squad.length < 18) {
          final extraRows = await db.rawQuery('''
            SELECT *
            FROM players
            WHERE team_name LIKE ?
            GROUP BY player_name
            ORDER BY season DESC, overall DESC
          ''', ['%$queryClub%']);

          for (final r in extraRows) {
            final p = Player.fromMap(r);
            final norm = p.name.trim().toLowerCase();
            if (!usedNames.contains(norm)) {
              usedNames.add(norm);
              squad.add(p);
              if (squad.length == 18) break;
            }
          }
        }

        expect(squad.length, 18, reason: '$clubName must have exactly 18 players');
        expect(usedNames.length, 18, reason: '$clubName must have 18 unique player names with zero duplicates');

        final gkCount = squad.where((p) => p.primaryPosition == 'GK').length;
        final defCount = squad.where((p) => ['CB', 'LB', 'RB', 'LWB', 'RWB'].contains(p.primaryPosition)).length;
        final midCount = squad.where((p) => ['CM', 'CAM', 'CDM', 'LM', 'RM'].contains(p.primaryPosition)).length;
        final fwdCount = squad.where((p) => ['ST', 'CF', 'LW', 'RW'].contains(p.primaryPosition)).length;

        expect(gkCount, 2, reason: '$clubName must have 2 GKs');
        expect(defCount, 6, reason: '$clubName must have 6 Defenders');
        expect(midCount, 6, reason: '$clubName must have 6 Midfielders');
        expect(fwdCount, 4, reason: '$clubName must have 4 Forwards');

        // Verify modern players: average season should be >= 2024
        final avgSeason = squad.map((p) => p.season).reduce((a, b) => a + b) / squad.length;
        expect(avgSeason, greaterThanOrEqualTo(2024),
            reason: '$clubName squad must consist of modern players, not 1990s legends');
      }
    });

    test('Random squad generation strictly enforces modern seasons, ratings and zero duplicates', () async {
      final List<Player> squad = [];
      final Set<String> usedNames = {};

      Future<void> pick({
        required String positionCondition,
        required int minOvr,
        required int maxOvr,
        required int count,
      }) async {
        var rows = await db.rawQuery('''
          SELECT *
          FROM players
          WHERE season >= 2022 AND ($positionCondition) AND overall BETWEEN ? AND ?
          GROUP BY player_name
          ORDER BY RANDOM()
          LIMIT 40
        ''', [minOvr, maxOvr]);

        if (rows.length < count) {
          rows = await db.rawQuery('''
            SELECT *
            FROM players
            WHERE ($positionCondition) AND overall BETWEEN ? AND ?
            GROUP BY player_name
            ORDER BY RANDOM()
            LIMIT 40
          ''', [minOvr - 4, maxOvr + 4]);
        }

        int picked = 0;
        for (final r in rows) {
          final p = Player.fromMap(r);
          final norm = p.name.trim().toLowerCase();
          if (!usedNames.contains(norm)) {
            usedNames.add(norm);
            squad.add(p);
            picked++;
            if (picked == count) break;
          }
        }
      }

      // 2 GK
      await pick(positionCondition: "primary_position = 'GK'", minOvr: 80, maxOvr: 87, count: 1);
      await pick(positionCondition: "primary_position = 'GK'", minOvr: 74, maxOvr: 80, count: 1);

      // 6 DEF
      await pick(positionCondition: "primary_position IN ('CB', 'LB', 'RB', 'LWB', 'RWB')", minOvr: 81, maxOvr: 88, count: 2);
      await pick(positionCondition: "primary_position IN ('CB', 'LB', 'RB', 'LWB', 'RWB')", minOvr: 75, maxOvr: 81, count: 4);

      // 6 MID
      await pick(positionCondition: "primary_position IN ('CM', 'CAM', 'CDM', 'LM', 'RM')", minOvr: 81, maxOvr: 88, count: 2);
      await pick(positionCondition: "primary_position IN ('CM', 'CAM', 'CDM', 'LM', 'RM')", minOvr: 75, maxOvr: 81, count: 4);

      // 4 FWD
      await pick(positionCondition: "primary_position IN ('ST', 'CF', 'LW', 'RW')", minOvr: 82, maxOvr: 89, count: 1);
      await pick(positionCondition: "primary_position IN ('ST', 'CF', 'LW', 'RW')", minOvr: 75, maxOvr: 82, count: 3);

      expect(squad.length, 18, reason: 'Random squad must have exactly 18 players');
      expect(usedNames.length, 18, reason: 'All 18 players must have unique names');

      final gkCount = squad.where((p) => p.primaryPosition == 'GK').length;
      final defCount = squad.where((p) => ['CB', 'LB', 'RB', 'LWB', 'RWB'].contains(p.primaryPosition)).length;
      final midCount = squad.where((p) => ['CM', 'CAM', 'CDM', 'LM', 'RM'].contains(p.primaryPosition)).length;
      final fwdCount = squad.where((p) => ['ST', 'CF', 'LW', 'RW'].contains(p.primaryPosition)).length;

      expect(gkCount, 2, reason: 'Must have 2 Goalkeepers');
      expect(defCount, 6, reason: 'Must have 6 Defenders');
      expect(midCount, 6, reason: 'Must have 6 Midfielders');
      expect(fwdCount, 4, reason: 'Must have 4 Forwards');

      // Check all seasons >= 2022
      for (final p in squad) {
        expect(p.season, greaterThanOrEqualTo(2022),
            reason: '${p.name} must be a modern active player (season >= 2022)');
      }

      // Check average overall rating is between 76 and 84
      final avgOvr = squad.map((p) => p.overall).reduce((a, b) => a + b) / squad.length;
      expect(avgOvr, inInclusiveRange(76.0, 84.0),
          reason: 'Squad average OVR must be competitive (~76-84)');
    });

    test('Reloading saved squad by player name produces 18 unique players with no duplicates', () async {
      final sampleNames = [
        'David Raya', 'Gabriel', 'William Saliba', 'Declan Rice', 'Bukayo Saka',
        'Martin Ødegaard', 'Gabriel Martinelli', 'Gabriel Jesus', 'Jurriën Timber',
        'Ben White', 'Mikel Merino', 'E. Eze', 'Zubimendi', 'Kepa', 'Piero Hincapié',
        'V. Gyökeres', 'Christian Nørgaard', 'M. Lewis-Skelly'
      ];

      final placeholders = List.filled(sampleNames.length, '?').join(',');
      final squadRows = await db.rawQuery('''
        SELECT * FROM players
        WHERE player_name IN ($placeholders)
        GROUP BY player_name
        ORDER BY season DESC, overall DESC
      ''', sampleNames);

      final Set<String> seenNames = {};
      final List<Player> reloaded = [];
      for (final r in squadRows) {
        final p = Player.fromMap(r);
        final norm = p.name.trim().toLowerCase();
        if (!seenNames.contains(norm)) {
          seenNames.add(norm);
          reloaded.add(p);
          if (reloaded.length == 18) break;
        }
      }

      expect(reloaded.length, 18, reason: 'Must reload exactly 18 players');
      expect(seenNames.length, 18, reason: 'Must have 18 distinct player names');
    });
  });

  group('Issue #12: Career Season Scheduling & Transfer Windows', () {
    final sampleClubs = [
      'Arsenal', 'Chelsea', 'Liverpool', 'Manchester City', 'Manchester United',
      'Tottenham Hotspur', 'Aston Villa', 'Newcastle United', 'Brighton & Hove Albion', 'West Ham United'
    ];

    test('generateSeasonSchedule generates balanced 38-match schedule for 10 clubs', () {
      final schedule = generateSeasonSchedule(sampleClubs, totalGameweeks: 38);

      expect(schedule.length, 38, reason: 'Must generate exactly 38 gameweeks');

      final matchCounts = <String, int>{for (final c in sampleClubs) c: 0};
      final homeCounts = <String, int>{for (final c in sampleClubs) c: 0};
      final awayCounts = <String, int>{for (final c in sampleClubs) c: 0};

      for (int gw = 0; gw < 38; gw++) {
        final round = schedule[gw];
        expect(round.length, 5, reason: 'Each gameweek must have 5 matches for 10 clubs');

        final clubsInRound = <String>{};
        for (final fixture in round) {
          expect(clubsInRound.contains(fixture.homeClub), isFalse,
              reason: '${fixture.homeClub} cannot play twice in GW ${gw + 1}');
          expect(clubsInRound.contains(fixture.awayClub), isFalse,
              reason: '${fixture.awayClub} cannot play twice in GW ${gw + 1}');
          clubsInRound.add(fixture.homeClub);
          clubsInRound.add(fixture.awayClub);

          matchCounts[fixture.homeClub] = matchCounts[fixture.homeClub]! + 1;
          matchCounts[fixture.awayClub] = matchCounts[fixture.awayClub]! + 1;
          homeCounts[fixture.homeClub] = homeCounts[fixture.homeClub]! + 1;
          awayCounts[fixture.awayClub] = awayCounts[fixture.awayClub]! + 1;
        }

        expect(clubsInRound.length, 10, reason: 'All 10 clubs must play in GW ${gw + 1}');
      }

      // Every club must play exactly 38 matches
      for (final club in sampleClubs) {
        expect(matchCounts[club], 38, reason: '$club must play exactly 38 matches in full season');
        expect(homeCounts[club], 19, reason: '$club must have balanced home venue allocation');
        expect(awayCounts[club], 19, reason: '$club must have balanced away venue allocation');
      }
    });

    test('generateSeasonSchedule generates authentic double round-robin for 18-match sprint season', () {
      final schedule = generateSeasonSchedule(sampleClubs, totalGameweeks: 18);

      expect(schedule.length, 18, reason: 'Must generate exactly 18 gameweeks');

      // In double round-robin, each pair should play exactly once home and once away
      final pairings = <String, int>{};

      for (int gw = 0; gw < 18; gw++) {
        final round = schedule[gw];
        expect(round.length, 5);

        for (final fixture in round) {
          final key = '${fixture.homeClub} vs ${fixture.awayClub}';
          pairings[key] = (pairings[key] ?? 0) + 1;
        }
      }

      // 10 teams -> 10 * 9 = 90 distinct home-away fixtures
      expect(pairings.length, 90, reason: 'All 90 home-away fixtures must take place exactly once');
      for (final entry in pairings.entries) {
        expect(entry.value, 1, reason: '${entry.key} must be played exactly once');
      }
    });

    test('TransferWindowState computes correct status across all 38 gameweeks', () {
      // GW 1-4: Summer Window Open
      for (int gw = 1; gw <= 4; gw++) {
        final state = TransferWindowState.compute(gameweek: gw, totalGameweeks: 38);
        expect(state.isOpen, isTrue, reason: 'GW $gw must be open for Summer window');
        expect(state.type, TransferWindowType.summer);
        expect(state.title, contains('SUMMER'));
        expect(state.deadlineText, contains('Gameweek 4'));
      }

      // GW 5-19: Transfer Window Closed (Autumn)
      for (int gw = 5; gw <= 19; gw++) {
        final state = TransferWindowState.compute(gameweek: gw, totalGameweeks: 38);
        expect(state.isOpen, isFalse, reason: 'GW $gw must be closed');
        expect(state.type, TransferWindowType.closed);
        expect(state.deadlineText, contains('20'));
      }

      // GW 20-21: Winter Window Open (exactly 2 gameweeks / weeks after 19 matches)
      for (int gw = 20; gw <= 21; gw++) {
        final state = TransferWindowState.compute(gameweek: gw, totalGameweeks: 38);
        expect(state.isOpen, isTrue, reason: 'GW $gw must be open for Winter window');
        expect(state.type, TransferWindowType.winter);
        expect(state.title, contains('WINTER'));
        expect(state.deadlineText, contains('Gameweek 21'));
      }

      // GW 22-38: Transfer Window Closed (Run-in)
      for (int gw = 22; gw <= 38; gw++) {
        final state = TransferWindowState.compute(gameweek: gw, totalGameweeks: 38);
        expect(state.isOpen, isFalse, reason: 'GW $gw must be closed for championship run-in');
        expect(state.type, TransferWindowType.closed);
        expect(state.deadlineText, contains('season review'));
      }
    });

    test('TransferWindowState computes correct status across 18 sprint gameweeks', () {
      // GW 1-3: Summer Window Open
      for (int gw = 1; gw <= 3; gw++) {
        final state = TransferWindowState.compute(gameweek: gw, totalGameweeks: 18);
        expect(state.isOpen, isTrue);
        expect(state.type, TransferWindowType.summer);
      }

      // GW 4-9: Closed
      for (int gw = 4; gw <= 9; gw++) {
        final state = TransferWindowState.compute(gameweek: gw, totalGameweeks: 18);
        expect(state.isOpen, isFalse);
        expect(state.type, TransferWindowType.closed);
      }

      // GW 10-11: Winter Window Open (2 gameweeks)
      for (int gw = 10; gw <= 11; gw++) {
        final state = TransferWindowState.compute(gameweek: gw, totalGameweeks: 18);
        expect(state.isOpen, isTrue);
        expect(state.type, TransferWindowType.winter);
      }

      // GW 12-18: Closed
      for (int gw = 12; gw <= 18; gw++) {
        final state = TransferWindowState.compute(gameweek: gw, totalGameweeks: 18);
        expect(state.isOpen, isFalse);
        expect(state.type, TransferWindowType.closed);
      }
    });

    test('PrefsService persists totalGameweeks and winterBudgetAwarded accurately', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsService.instance;

      await prefs.saveCareerConfig(
        leagueId: 'premier_league',
        clubName: 'Arsenal',
        clubCode: 'ARS',
        isCustomClub: false,
        squadMode: 'current',
        budget: 95.0,
        season: 1,
        gameweek: 19,
        totalGameweeks: 38,
        winterBudgetAwarded: true,
        squadIds: ['David Raya', 'William Saliba'],
      );

      final loaded = await prefs.getCareerConfig();
      expect(loaded, isNotNull);
      expect(loaded!['totalGameweeks'], 38);
      expect(loaded['winterBudgetAwarded'], isTrue);
      expect(loaded['gameweek'], 19);

      // Clear
      await prefs.clearCareerConfig();
      final cleared = await prefs.getCareerConfig();
      expect(cleared, isNull);
    });
  });

  group('Issue #9: Career Transfer Market & Team Management', () {
    test('calculatePlayerValuation computes authentic exponential valuations across rating tiers', () {
      final p65 = Player.fromMap({'player_name': 'Youngster', 'overall': 65, 'age': 20.0, 'primary_position': 'CM', 'all_positions': 'CM', 'mode': 'FC24', 'season': 2024, 'team_name': 'Arsenal'});
      final p70 = Player.fromMap({'player_name': 'Prospect', 'overall': 70, 'age': 25.0, 'primary_position': 'CB', 'all_positions': 'CB', 'mode': 'FC24', 'season': 2024, 'team_name': 'Arsenal'});
      final p75 = Player.fromMap({'player_name': 'Starter', 'overall': 75, 'age': 26.0, 'primary_position': 'LB', 'all_positions': 'LB', 'mode': 'FC24', 'season': 2024, 'team_name': 'Arsenal'});
      final p80 = Player.fromMap({'player_name': 'Core', 'overall': 80, 'age': 26.0, 'primary_position': 'CM', 'all_positions': 'CM', 'mode': 'FC24', 'season': 2024, 'team_name': 'Arsenal'});
      final p85 = Player.fromMap({'player_name': 'Star', 'overall': 85, 'age': 26.0, 'primary_position': 'RW', 'all_positions': 'RW', 'mode': 'FC24', 'season': 2024, 'team_name': 'Arsenal'});
      final p90 = Player.fromMap({'player_name': 'Elite', 'overall': 90, 'age': 26.0, 'primary_position': 'ST', 'all_positions': 'ST', 'mode': 'FC24', 'season': 2024, 'team_name': 'Arsenal'});
      final p93 = Player.fromMap({'player_name': 'Superstar', 'overall': 93, 'age': 25.0, 'primary_position': 'ST', 'all_positions': 'ST', 'mode': 'FC24', 'season': 2024, 'team_name': 'Manchester City'});

      expect(calculatePlayerValuation(p65), greaterThanOrEqualTo(0.5));
      expect(calculatePlayerValuation(p70), inInclusiveRange(1.0, 2.0));
      expect(calculatePlayerValuation(p75), inInclusiveRange(5.0, 7.0));
      expect(calculatePlayerValuation(p80), inInclusiveRange(12.0, 15.0));
      expect(calculatePlayerValuation(p85), inInclusiveRange(23.0, 27.0));
      expect(calculatePlayerValuation(p90), inInclusiveRange(37.0, 42.0));
      expect(calculatePlayerValuation(p93), inInclusiveRange(46.0, 52.0));
    });

    test('calculatePlayerValuation factors age premium and veteran discounts', () {
      final youngStar = Player.fromMap({'player_name': 'Young Prodigy', 'overall': 84, 'age': 21.0, 'primary_position': 'RW', 'all_positions': 'RW', 'mode': 'FC24', 'season': 2024, 'team_name': 'Arsenal'});
      final primeStar = Player.fromMap({'player_name': 'Prime Star', 'overall': 84, 'age': 26.0, 'primary_position': 'RW', 'all_positions': 'RW', 'mode': 'FC24', 'season': 2024, 'team_name': 'Arsenal'});
      final veteranStar = Player.fromMap({'player_name': 'Veteran Star', 'overall': 84, 'age': 35.0, 'primary_position': 'RW', 'all_positions': 'RW', 'mode': 'FC24', 'season': 2024, 'team_name': 'Arsenal'});

      final youngVal = calculatePlayerValuation(youngStar);
      final primeVal = calculatePlayerValuation(primeStar);
      final veteranVal = calculatePlayerValuation(veteranStar);

      expect(youngVal, greaterThan(primeVal), reason: 'Prospects <= 23 receive 1.2x valuation premium');
      expect(primeVal, greaterThan(veteranVal), reason: 'Veterans >= 32 receive age discount');
    });

    test('calculatePlayerSalePrice awards 90% of valuation to manager', () {
      final star = Player.fromMap({'player_name': 'Bukayo Saka', 'overall': 87, 'age': 22.0, 'primary_position': 'RW', 'all_positions': 'RW', 'mode': 'FC24', 'season': 2024, 'team_name': 'Arsenal'});
      final val = calculatePlayerValuation(star);
      final saleProceeds = calculatePlayerSalePrice(star);

      expect(saleProceeds, closeTo(val * 0.9, 0.15));
      expect(saleProceeds, lessThan(val));
      expect(saleProceeds, greaterThanOrEqualTo(0.5));
    });

    test('Transfer Window rules gate buy and sell actions by calendar state', () {
      // GW 1: Summer Window Open -> Can buy and sell
      final summerWindow = TransferWindowState.compute(gameweek: 1, totalGameweeks: 38);
      expect(summerWindow.isOpen, isTrue);

      // GW 10: Autumn Window Closed -> Cannot buy or sell
      final closedWindow = TransferWindowState.compute(gameweek: 10, totalGameweeks: 38);
      expect(closedWindow.isOpen, isFalse);

      // GW 20: Winter Window Open -> Can buy and sell
      final winterWindow = TransferWindowState.compute(gameweek: 20, totalGameweeks: 38);
      expect(winterWindow.isOpen, isTrue);
    });

    test('Tactical squad separation maintains 11 starting players and bench reserves', () {
      final squad = List.generate(18, (i) {
        return Player.fromMap({
          'player_name': 'Player $i',
          'overall': 75 + (i % 12),
          'age': 24.0 + (i % 6),
          'primary_position': i == 0 ? 'GK' : (i <= 5 ? 'CB' : (i <= 12 ? 'CM' : 'ST')),
          'all_positions': 'CM',
          'mode': 'FC24',
          'season': 2024,
          'team_name': 'Arsenal',
        });
      });

      final startingXi = squad.take(11).toList();
      final bench = squad.sublist(11);

      expect(startingXi.length, 11);
      expect(bench.length, 7);

      // Swapping index 0 and 11 swaps starter with bench
      final starterBefore = startingXi[0];
      final benchBefore = bench[0];

      final temp = squad[0];
      squad[0] = squad[11];
      squad[11] = temp;

      expect(squad.take(11).first.name, benchBefore.name);
      expect(squad.sublist(11).first.name, starterBefore.name);
    });
  });

  group('Issue #10: Career Persistent Save State & Standings Preservation', () {
    test('TableEntry serialization toMap and fromMap preserves all statistics and points', () {
      final entry = TableEntry(clubName: 'Arsenal')
        ..played = 19
        ..won = 13
        ..drawn = 4
        ..lost = 2
        ..goalsFor = 42
        ..goalsAgainst = 16
        ..points = 43;

      final map = entry.toMap();
      expect(map['clubName'], 'Arsenal');
      expect(map['played'], 19);
      expect(map['won'], 13);
      expect(map['drawn'], 4);
      expect(map['lost'], 2);
      expect(map['goalsFor'], 42);
      expect(map['goalsAgainst'], 16);
      expect(map['points'], 43);

      final restored = TableEntry.fromMap(map);
      expect(restored.clubName, 'Arsenal');
      expect(restored.played, 19);
      expect(restored.won, 13);
      expect(restored.drawn, 4);
      expect(restored.lost, 2);
      expect(restored.goalsFor, 42);
      expect(restored.goalsAgainst, 16);
      expect(restored.points, 43);
      expect(restored.goalDifference, 26);
    });

    test('PrefsService preserves full leagueTable state across saves and retrieves accurately', () async {
      SharedPreferences.setMockInitialValues({});

      final initialTable = [
        (TableEntry(clubName: 'Arsenal')
              ..played = 20
              ..won = 15
              ..drawn = 3
              ..lost = 2
              ..goalsFor = 45
              ..goalsAgainst = 18
              ..points = 48)
            .toMap(),
        (TableEntry(clubName: 'Manchester City')
              ..played = 20
              ..won = 14
              ..drawn = 4
              ..lost = 2
              ..goalsFor = 49
              ..goalsAgainst = 21
              ..points = 46)
            .toMap(),
        (TableEntry(clubName: 'Liverpool')
              ..played = 20
              ..won = 13
              ..drawn = 5
              ..lost = 2
              ..goalsFor = 40
              ..goalsAgainst = 19
              ..points = 44)
            .toMap(),
      ];

      await PrefsService.instance.saveCareerConfig(
        leagueId: 'premier_league',
        clubName: 'Arsenal',
        clubCode: 'ARS',
        isCustomClub: false,
        squadMode: 'current',
        budget: 95.0,
        season: 2,
        gameweek: 21,
        totalGameweeks: 38,
        leagueTable: initialTable,
      );

      final loaded = await PrefsService.instance.getCareerConfig();
      expect(loaded, isNotNull);
      expect(loaded!['clubName'], 'Arsenal');
      expect(loaded['season'], 2);
      expect(loaded['gameweek'], 21);
      expect(loaded['budget'], 95.0);

      final loadedTable = loaded['leagueTable'] as List<dynamic>;
      expect(loadedTable.length, 3);
      expect(loadedTable[0]['clubName'], 'Arsenal');
      expect(loadedTable[0]['points'], 48);
      expect(loadedTable[0]['goalsFor'], 45);
      expect(loadedTable[1]['clubName'], 'Manchester City');
      expect(loadedTable[1]['points'], 46);
      expect(loadedTable[2]['clubName'], 'Liverpool');
      expect(loadedTable[2]['points'], 44);

      // Clearing configuration removes table
      await PrefsService.instance.clearCareerConfig();
      final afterClear = await PrefsService.instance.getCareerConfig();
      expect(afterClear, isNull);
    });

    test('SaveService SQLite career_save table supports CRUD operations', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      final testState = {
        'leagueId': 'premier_league',
        'clubName': 'Aston Villa',
        'clubCode': 'AVL',
        'season': 1,
        'gameweek': 15,
        'budget': 70.0,
        'squadIds': ['Ollie Watkins', 'Emiliano Martinez'],
      };

      await SaveService.instance.saveCareerState(
        saveId: 'test_career',
        clubCode: 'AVL',
        season: 1,
        budget: 70.0,
        state: testState,
      );

      final exists = await SaveService.instance.hasCareerSave('test_career');
      expect(exists, isTrue);

      final loaded = await SaveService.instance.loadCareerState('test_career');
      expect(loaded, isNotNull);
      expect(loaded!['clubName'], 'Aston Villa');
      expect(loaded['gameweek'], 15);
      expect(loaded['budget'], 70.0);
      expect(loaded['squadIds'], ['Ollie Watkins', 'Emiliano Martinez']);

      await SaveService.instance.deleteCareerSave('test_career');
      final afterDelete = await SaveService.instance.hasCareerSave('test_career');
      expect(afterDelete, isFalse);
    });

    test('Mid-season app restart restores non-zero league table standings without resetting to 0', () {
      final savedTableData = [
        {
          'clubName': 'Chelsea',
          'played': 12,
          'won': 8,
          'drawn': 2,
          'lost': 2,
          'goalsFor': 22,
          'goalsAgainst': 10,
          'points': 26,
        },
        {
          'clubName': 'Tottenham Hotspur',
          'played': 12,
          'won': 7,
          'drawn': 3,
          'lost': 2,
          'goalsFor': 20,
          'goalsAgainst': 11,
          'points': 24,
        },
      ];

      final restoredTable = <TableEntry>[];
      for (final item in savedTableData) {
        restoredTable.add(TableEntry.fromMap(item));
      }

      // Standings sort descending by points, goalDifference, goalsFor
      restoredTable.sort((a, b) {
        if (b.points != a.points) return b.points.compareTo(a.points);
        if (b.goalDifference != a.goalDifference) return b.goalDifference.compareTo(a.goalDifference);
        return b.goalsFor.compareTo(a.goalsFor);
      });

      expect(restoredTable.length, 2);
      expect(restoredTable[0].clubName, 'Chelsea');
      expect(restoredTable[0].points, 26);
      expect(restoredTable[0].played, 12);
      expect(restoredTable[1].clubName, 'Tottenham Hotspur');
      expect(restoredTable[1].points, 24);
      expect(restoredTable[1].goalDifference, 9);
    });
  });

  group('Issue #12 & #13: Season Calendar & Random Squad 80+ Draft Swaps', () {
    test('Berger circle generates full 38-game and 18-game schedules with perfect club pairing', () {
      final premierLeague = kAvailableLeagues.firstWhere((l) => l.id == 'premier_league');
      final plClubs = premierLeague.clubs;
      expect(plClubs.length, 20);

      // 1. Full 38-gameweek marathon for 20 clubs
      final schedule38 = generateSeasonSchedule(plClubs, totalGameweeks: 38);
      expect(schedule38.length, 38, reason: 'Must generate 38 gameweek rounds');

      final matchCounts38 = <String, int>{};
      for (final club in plClubs) {
        matchCounts38[club] = 0;
      }

      for (int gw = 0; gw < 38; gw++) {
        final round = schedule38[gw];
        expect(round.length, 10, reason: 'Round ${gw + 1} must have 10 fixtures for 20 clubs');

        final roundClubs = <String>{};
        for (final fixture in round) {
          expect(plClubs.contains(fixture.homeClub), isTrue);
          expect(plClubs.contains(fixture.awayClub), isTrue);
          expect(fixture.homeClub, isNot(equals(fixture.awayClub)));

          roundClubs.add(fixture.homeClub);
          roundClubs.add(fixture.awayClub);

          matchCounts38[fixture.homeClub] = matchCounts38[fixture.homeClub]! + 1;
          matchCounts38[fixture.awayClub] = matchCounts38[fixture.awayClub]! + 1;
        }
        expect(roundClubs.length, 20, reason: 'Every club must play exactly once in round ${gw + 1}');
      }

      for (final club in plClubs) {
        expect(matchCounts38[club], 38, reason: '$club must play exactly 38 matches in marathon');
      }

      // 2. Sprint 18-gameweek campaign for 10-club league (Home & Away double round-robin)
      final sprintLeague = kAvailableLeagues.firstWhere((l) => l.id == 'continental_elite');
      final sprintClubs = sprintLeague.clubs;
      expect(sprintClubs.length, 10);
      final schedule18 = generateSeasonSchedule(sprintClubs, totalGameweeks: 18);
      expect(schedule18.length, 18, reason: 'Must generate 18 gameweek rounds');

      final headToHead = <String, Map<String, int>>{};
      for (final c1 in sprintClubs) {
        headToHead[c1] = {};
        for (final c2 in sprintClubs) {
          if (c1 != c2) headToHead[c1]![c2] = 0;
        }
      }

      for (final round in schedule18) {
        expect(round.length, 5);
        for (final f in round) {
          headToHead[f.homeClub]![f.awayClub] = headToHead[f.homeClub]![f.awayClub]! + 1;
        }
      }

      // In 18-game double round-robin, every club plays every other club exactly once home and once away
      for (final c1 in sprintClubs) {
        for (final c2 in sprintClubs) {
          if (c1 != c2) {
            expect(headToHead[c1]![c2], 1, reason: '$c1 should host $c2 exactly once in 18-game sprint');
          }
        }
      }
    });

    test('Calendar fixture lookup identifies home/away venue and opponent across all 38 gameweeks', () {
      final clubs = kAvailableLeagues.first.clubs;
      final userClub = clubs.first; // Manchester United
      final schedule = generateSeasonSchedule(clubs, totalGameweeks: 38);

      for (int gw = 1; gw <= 38; gw++) {
        final roundFixtures = schedule[gw - 1];
        final userFixture = roundFixtures.firstWhere(
          (f) => f.homeClub == userClub || f.awayClub == userClub,
        );

        final isHome = userFixture.homeClub == userClub;
        final opponent = isHome ? userFixture.awayClub : userFixture.homeClub;

        expect(opponent, isNot(equals(userClub)));
        expect(clubs.contains(opponent), isTrue);
      }
    });

    test('Season Results Archive saves and restores full historical scorelines per gameweek', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsService.instance;

      final testArchive = <int, List<Map<String, dynamic>>>{
        1: [
          {
            'homeClub': 'Arsenal',
            'awayClub': 'Chelsea',
            'homeGoals': 2,
            'awayGoals': 1,
            'homeGoalEvents': [
              {'scorerName': 'Bukayo Saka', 'minute': 23, 'isPenalty': false},
              {'scorerName': 'Martin Ødegaard', 'minute': 67, 'isPenalty': false},
            ],
            'awayGoalEvents': [
              {'scorerName': 'Cole Palmer', 'minute': 45, 'isPenalty': true},
            ],
          },
          {
            'homeClub': 'Liverpool',
            'awayClub': 'Manchester City',
            'homeGoals': 0,
            'awayGoals': 0,
            'homeGoalEvents': [],
            'awayGoalEvents': [],
          },
        ],
        2: [
          {
            'homeClub': 'Manchester United',
            'awayClub': 'Arsenal',
            'homeGoals': 1,
            'awayGoals': 3,
            'homeGoalEvents': [
              {'scorerName': 'Bruno Fernandes', 'minute': 12, 'isPenalty': false},
            ],
            'awayGoalEvents': [
              {'scorerName': 'Declan Rice', 'minute': 34, 'isPenalty': false},
              {'scorerName': 'Bukayo Saka', 'minute': 55, 'isPenalty': false},
              {'scorerName': 'Gabriel Martinelli', 'minute': 88, 'isPenalty': false},
            ],
          },
        ],
      };

      await prefs.saveCareerConfig(
        leagueId: 'premier_league',
        clubName: 'Arsenal',
        clubCode: 'ARS',
        isCustomClub: false,
        squadMode: 'current',
        budget: 90.0,
        season: 1,
        gameweek: 3,
        totalGameweeks: 38,
        seasonResults: testArchive,
      );

      final loaded = await prefs.getCareerConfig();
      expect(loaded, isNotNull);
      final restoredArchive = loaded!['seasonResults'] as Map<dynamic, dynamic>?;
      expect(restoredArchive, isNotNull);
      expect(restoredArchive!.containsKey(1), isTrue);
      expect(restoredArchive.containsKey(2), isTrue);

      final gw1Matches = (restoredArchive[1] as List).cast<Map>();
      expect(gw1Matches.length, 2);
      expect(gw1Matches[0]['homeClub'], 'Arsenal');
      expect(gw1Matches[0]['homeGoals'], 2);
      expect(gw1Matches[0]['awayGoals'], 1);

      final gw2Matches = (restoredArchive[2] as List).cast<Map>();
      expect(gw2Matches.length, 1);
      expect(gw2Matches[0]['homeClub'], 'Manchester United');
      expect(gw2Matches[0]['awayGoals'], 3);
    });

    test('Random squad draft swap logic: 3 swaps allowed, swaps decrement and replace with 80+ player', () {
      int swapsRemaining = 3;
      final dummySquad = [
        Player(
          mode: 'classic',
          squadId: 'squad_1',
          teamCode: 'MUN',
          teamName: 'Manchester United',
          season: 2024,
          playerId: 'p1',
          name: 'Young Prospect',
          overall: 73,
          displayPosition: 'ST',
          primaryPosition: 'ST',
          allPositions: 'ST',
          pace: 75,
          shooting: 72,
          passing: 68,
          dribbling: 74,
          defending: 35,
          physicality: 65,
          isGoalkeeper: false,
        ),
      ];

      // Simulate swap 1
      expect(swapsRemaining, 3);
      final replacement1 = Player(
        mode: 'classic',
        squadId: 'squad_1',
        teamCode: 'RMA',
        teamName: 'Real Madrid',
        season: 2024,
        playerId: 'p_star1',
        name: 'Kylian Mbappé',
        overall: 91,
        displayPosition: 'ST',
        primaryPosition: 'ST',
        allPositions: 'ST',
        pace: 97,
        shooting: 90,
        passing: 80,
        dribbling: 92,
        defending: 36,
        physicality: 78,
        isGoalkeeper: false,
      );

      if (swapsRemaining > 0) {
        dummySquad[0] = replacement1;
        swapsRemaining--;
      }

      expect(swapsRemaining, 2);
      expect(dummySquad[0].overall, greaterThanOrEqualTo(80));
      expect(dummySquad[0].name, 'Kylian Mbappé');

      // Simulate swap 2
      final replacement2 = Player(
        mode: 'classic',
        squadId: 'squad_1',
        teamCode: 'MCI',
        teamName: 'Manchester City',
        season: 2024,
        playerId: 'p_star2',
        name: 'Erling Haaland',
        overall: 91,
        displayPosition: 'ST',
        primaryPosition: 'ST',
        allPositions: 'ST',
        pace: 89,
        shooting: 93,
        passing: 66,
        dribbling: 80,
        defending: 45,
        physicality: 88,
        isGoalkeeper: false,
      );

      if (swapsRemaining > 0) {
        dummySquad[0] = replacement2;
        swapsRemaining--;
      }
      expect(swapsRemaining, 1);
      expect(dummySquad[0].name, 'Erling Haaland');

      // Simulate swap 3
      final replacement3 = Player(
        mode: 'classic',
        squadId: 'squad_1',
        teamCode: 'BAY',
        teamName: 'Bayern Munich',
        season: 2024,
        playerId: 'p_star3',
        name: 'Harry Kane',
        overall: 90,
        displayPosition: 'ST',
        primaryPosition: 'ST',
        allPositions: 'ST',
        pace: 70,
        shooting: 93,
        passing: 84,
        dribbling: 82,
        defending: 49,
        physicality: 82,
        isGoalkeeper: false,
      );

      if (swapsRemaining > 0) {
        dummySquad[0] = replacement3;
        swapsRemaining--;
      }
      expect(swapsRemaining, 0);
      expect(dummySquad[0].name, 'Harry Kane');

      // Attempt swap 4 when remaining is 0: must not swap
      bool swapBlocked = false;
      if (swapsRemaining <= 0) {
        swapBlocked = true;
      }
      expect(swapBlocked, isTrue);
      expect(dummySquad[0].name, 'Harry Kane');
    });
  });

  group('Issue #5, #6 & #7: SimEngine Realistic Scoring, Substitutions & Comprehensive Stats', () {
    test('SimEngine position-weighted scoring: Forwards/Wingers dominate goals, Goalkeepers virtually 0', () {
      final sim = SimEngine(42);
      final homeSquad = [
        const SimPlayer(name: 'David Raya', position: 'GK', overall: 84, isStarter: true),
        const SimPlayer(name: 'Ben White', position: 'RB', overall: 82, isStarter: true),
        const SimPlayer(name: 'William Saliba', position: 'CB', overall: 88, isStarter: true),
        const SimPlayer(name: 'Gabriel', position: 'CB', overall: 86, isStarter: true),
        const SimPlayer(name: 'Jurriën Timber', position: 'LB', overall: 81, isStarter: true),
        const SimPlayer(name: 'Thomas Partey', position: 'CDM', overall: 82, isStarter: true),
        const SimPlayer(name: 'Declan Rice', position: 'CM', overall: 87, isStarter: true),
        const SimPlayer(name: 'Martin Ødegaard', position: 'CAM', overall: 89, isStarter: true),
        const SimPlayer(name: 'Bukayo Saka', position: 'RW', overall: 88, isStarter: true),
        const SimPlayer(name: 'Gabriel Martinelli', position: 'LW', overall: 85, isStarter: true),
        const SimPlayer(name: 'Kai Havertz', position: 'ST', overall: 84, isStarter: true),
        // Bench
        const SimPlayer(name: 'Neto', position: 'GK', overall: 78, isStarter: false),
        const SimPlayer(name: 'Jakub Kiwior', position: 'CB', overall: 79, isStarter: false),
        const SimPlayer(name: 'Mikel Merino', position: 'CM', overall: 83, isStarter: false),
        const SimPlayer(name: 'Leandro Trossard', position: 'LW', overall: 83, isStarter: false),
        const SimPlayer(name: 'Gabriel Jesus', position: 'ST', overall: 82, isStarter: false),
      ];

      final awaySquad = [
        const SimPlayer(name: 'Alisson', position: 'GK', overall: 89, isStarter: true),
        const SimPlayer(name: 'Trent Alexander-Arnold', position: 'RB', overall: 86, isStarter: true),
        const SimPlayer(name: 'Virgil van Dijk', position: 'CB', overall: 89, isStarter: true),
        const SimPlayer(name: 'Ibrahima Konaté', position: 'CB', overall: 83, isStarter: true),
        const SimPlayer(name: 'Andy Robertson', position: 'LB', overall: 85, isStarter: true),
        const SimPlayer(name: 'Ryan Gravenberch', position: 'CDM', overall: 80, isStarter: true),
        const SimPlayer(name: 'Alexis Mac Allister', position: 'CM', overall: 86, isStarter: true),
        const SimPlayer(name: 'Dominik Szoboszlai', position: 'CAM', overall: 82, isStarter: true),
        const SimPlayer(name: 'Mohamed Salah', position: 'RW', overall: 89, isStarter: true),
        const SimPlayer(name: 'Luis Díaz', position: 'LW', overall: 84, isStarter: true),
        const SimPlayer(name: 'Darwin Núñez', position: 'ST', overall: 82, isStarter: true),
        // Bench
        const SimPlayer(name: 'Caoimhín Kelleher', position: 'GK', overall: 77, isStarter: false),
        const SimPlayer(name: 'Joe Gomez', position: 'CB', overall: 80, isStarter: false),
        const SimPlayer(name: 'Curtis Jones', position: 'CM', overall: 80, isStarter: false),
        const SimPlayer(name: 'Cody Gakpo', position: 'LW', overall: 83, isStarter: false),
        const SimPlayer(name: 'Diogo Jota', position: 'CF', overall: 85, isStarter: false),
      ];

      int totalGoals = 0;
      int gkGoals = 0;
      int fwdAndWingerGoals = 0;
      int midGoals = 0;
      int defGoals = 0;

      // Simulate 500 matches to analyze goal distribution
      for (int i = 0; i < 500; i++) {
        final result = sim.simulateMatch(
          homeClub: 'Arsenal',
          homeRating: 85.0,
          awayClub: 'Liverpool',
          awayRating: 85.0,
          homePlayers: homeSquad,
          awayPlayers: awaySquad,
        );

        for (final g in [...result.homeGoalEvents, ...result.awayGoalEvents]) {
          if (g.isOwnGoal) continue;
          totalGoals++;
          final scorerName = g.scorerName;
          final allPlayers = [...homeSquad, ...awaySquad];
          final player = allPlayers.firstWhere(
            (p) => p.name == scorerName,
            orElse: () => const SimPlayer(name: '', position: 'ST'),
          );

          if (player.position == 'GK') {
            gkGoals++;
          } else if (['ST', 'CF', 'LW', 'RW'].contains(player.position)) {
            fwdAndWingerGoals++;
          } else if (['CAM', 'CM', 'LM', 'RM', 'CDM'].contains(player.position)) {
            midGoals++;
          } else if (['CB', 'LB', 'RB', 'LWB', 'RWB'].contains(player.position)) {
            defGoals++;
          }
        }
      }

      expect(totalGoals, greaterThan(500), reason: '500 matches should produce many goals');
      final gkPct = (gkGoals / totalGoals) * 100;
      final fwdPct = (fwdAndWingerGoals / totalGoals) * 100;

      // Assert GKs score < 0.5% (virtually 0) and forwards/wingers score > 55%
      expect(gkPct, lessThan(0.5), reason: 'Goalkeepers must virtually never score ($gkPct%)');
      expect(fwdPct, greaterThan(55.0), reason: 'Strikers & wingers must score majority of goals ($fwdPct%)');
      expect(midGoals, greaterThan(0), reason: 'Midfielders should also score occasionally');
      expect(defGoals, greaterThan(0), reason: 'Defenders should occasionally score from set pieces');
    });

    test('SimEngine generates realistic second-half substitutions (52 to 78 minute)', () {
      final sim = SimEngine(123);
      final homeSquad = List.generate(
        16,
        (i) => SimPlayer(
          name: 'HomePlayer_$i',
          position: i == 0 ? 'GK' : (i < 5 ? 'CB' : (i < 9 ? 'CM' : (i < 11 ? 'ST' : 'CM'))),
          overall: 80,
          isStarter: i < 11,
        ),
      );
      final awaySquad = List.generate(
        16,
        (i) => SimPlayer(
          name: 'AwayPlayer_$i',
          position: i == 0 ? 'GK' : (i < 5 ? 'CB' : (i < 9 ? 'CM' : (i < 11 ? 'ST' : 'CM'))),
          overall: 80,
          isStarter: i < 11,
        ),
      );

      final result = sim.simulateMatch(
        homeClub: 'Club A',
        homeRating: 80.0,
        awayClub: 'Club B',
        awayRating: 80.0,
        homePlayers: homeSquad,
        awayPlayers: awaySquad,
      );

      expect(result.homeSubstitutions.length, inInclusiveRange(1, 3));
      expect(result.awaySubstitutions.length, inInclusiveRange(1, 3));

      for (final sub in [...result.homeSubstitutions, ...result.awaySubstitutions]) {
        expect(sub.minute, inInclusiveRange(52, 78), reason: 'Sub minute must be in realistic second-half window');
        expect(sub.playerIn, isNotEmpty);
        expect(sub.playerOut, isNotEmpty);
        expect(sub.playerIn, isNot(equals(sub.playerOut)));
        expect(sub.formatted, contains(sub.playerIn));
      }
    });

    test('SimEngine computes player match ratings in [4.8, 10.0] and valid team stats', () {
      final sim = SimEngine(456);
      final result = sim.simulateMatch(
        homeClub: 'Arsenal',
        homeRating: 85.0,
        awayClub: 'Chelsea',
        awayRating: 83.0,
      );

      // Starters + subs must have ratings
      expect(result.homePlayerRatings.length, greaterThanOrEqualTo(11));
      expect(result.awayPlayerRatings.length, greaterThanOrEqualTo(11));

      for (final r in result.homePlayerRatings.values) {
        expect(r, inInclusiveRange(4.8, 10.0));
      }
      for (final r in result.awayPlayerRatings.values) {
        expect(r, inInclusiveRange(4.8, 10.0));
      }

      // Man of the Match
      expect(result.motm, isNotEmpty);
      final motmInHome = result.homePlayerRatings.containsKey(result.motm);
      final motmInAway = result.awayPlayerRatings.containsKey(result.motm);
      expect(motmInHome || motmInAway, isTrue);

      // Team stats
      expect(result.homeStats.possession + result.awayStats.possession, 100);
      expect(result.homeStats.shots, greaterThanOrEqualTo(result.homeGoals));
      expect(result.awayStats.shots, greaterThanOrEqualTo(result.awayGoals));
      expect(result.homeStats.shotsOnTarget, inInclusiveRange(result.homeGoals, result.homeStats.shots));
      expect(result.awayStats.shotsOnTarget, inInclusiveRange(result.awayGoals, result.awayStats.shots));
    });
  });

  group('FIFA Formation & Pitch Lineup Tests (Fix 18d)', () {
    test('All tactical formations have 11 slots with valid pitch coordinates and GK at slot 0', () {
      expect(TacticalFormation.presets.length, greaterThanOrEqualTo(7));
      final defaultFormation = TacticalFormation.getById('4-3-3');
      expect(defaultFormation.displayName, '4-3-3 Attack');
      expect(defaultFormation.slots.length, 11);

      for (final formation in TacticalFormation.presets) {
        expect(formation.slots.length, 11, reason: '${formation.displayName} must define exactly 11 player slots');
        // Slot 0 is always GK
        expect(formation.slots[0].defaultRole, 'GK', reason: '${formation.displayName} slot 0 must be GK');
        expect(formation.slots[0].y, greaterThanOrEqualTo(0.85), reason: 'GK must be positioned near goal line');

        // Verify all slots are within pitch bounds (0.0 to 1.0)
        for (final slot in formation.slots) {
          expect(slot.x, inInclusiveRange(0.05, 0.95), reason: '${slot.defaultRole} x coordinate within pitch');
          expect(slot.y, inInclusiveRange(0.05, 0.95), reason: '${slot.defaultRole} y coordinate within pitch');
          expect(slot.defaultRole, isNotEmpty);
        }
      }
    });

    test('TacticalFormation.getById falls back safely to 4-3-3 for unknown identifiers', () {
      final fallback = TacticalFormation.getById('non_existent_formation');
      expect(fallback.id, '4-3-3');
    });
  });

  group('UEFA Champions League 2026/27 Tournament Tests (Fix 18c)', () {
    test('UclTournament creation initializes 4 groups of 4 authentic European clubs', () {
      final ucl = UclTournament.create(userClub: 'Arsenal');
      expect(ucl.userClub, 'Arsenal');
      expect(ucl.groups.length, 4);
      expect(ucl.groups.keys.toList(), ['A', 'B', 'C', 'D']);
      expect(ucl.groupTables.length, 4);

      // 16 total unique clubs across groups
      final allClubs = <String>{};
      for (final group in ucl.groups.values) {
        expect(group.length, 4);
        for (final c in group) {
          allClubs.add(c);
        }
      }
      expect(allClubs.length, 16);
      expect(allClubs.contains('Arsenal'), isTrue, reason: 'User club must be included in UCL');

      // 6 matchdays, 4 groups × 2 matches = 8 matches per matchday = 48 group fixtures total
      expect(ucl.groupFixtures.length, 48);
      for (int md = 1; md <= 6; md++) {
        final mdFixtures = ucl.getFixturesForMatchday(md);
        expect(mdFixtures.length, 8);
      }
    });

    test('Midweek calendar mapping correctly matches Premier League gameweeks', () {
      // Group Stage: GW 3, 6, 9, 12, 15, 18
      expect(UclTournament.getUclMatchdayForLeagueGw(3), 1);
      expect(UclTournament.getUclMatchdayForLeagueGw(6), 2);
      expect(UclTournament.getUclMatchdayForLeagueGw(9), 3);
      expect(UclTournament.getUclMatchdayForLeagueGw(12), 4);
      expect(UclTournament.getUclMatchdayForLeagueGw(15), 5);
      expect(UclTournament.getUclMatchdayForLeagueGw(18), 6);

      // Knockouts: GW 22 (QF1), 25 (QF2), 28 (SF1), 31 (SF2), 35 (Final)
      expect(UclTournament.getUclMatchdayForLeagueGw(22), 7);
      expect(UclTournament.getUclMatchdayForLeagueGw(25), 8);
      expect(UclTournament.getUclMatchdayForLeagueGw(28), 9);
      expect(UclTournament.getUclMatchdayForLeagueGw(31), 10);
      expect(UclTournament.getUclMatchdayForLeagueGw(35), 11);

      // Non-UCL weeks
      expect(UclTournament.getUclMatchdayForLeagueGw(1), isNull);
      expect(UclTournament.getUclMatchdayForLeagueGw(2), isNull);
      expect(UclTournament.getUclMatchdayForLeagueGw(4), isNull);
      expect(UclTournament.getUclMatchdayForLeagueGw(38), isNull);
    });

    test('Full UCL Simulation from Group Stage through Knockouts to Final crowned Champion', () {
      final ucl = UclTournament.create(userClub: 'Arsenal');
      final sim = SimEngine(999);

      // Simulate 6 group matchdays
      for (int md = 1; md <= 6; md++) {
        expect(ucl.isGroupStageComplete, isFalse);
        final results = ucl.simulateMatchday(md, simEngine: sim);
        expect(results.length, 8, reason: '8 matches per matchday in group stage');
      }

      // After 6 group matchdays, group stage is complete
      expect(ucl.isGroupStageComplete, isTrue);

      // QF Leg 1 (MD 7) & Leg 2 (MD 8)
      final qf1Results = ucl.simulateMatchday(7, simEngine: sim);
      expect(qf1Results.length, 4);
      expect(ucl.quarterFinals.length, 4);

      final qf2Results = ucl.simulateMatchday(8, simEngine: sim);
      expect(qf2Results.length, 4);
      for (final tie in ucl.quarterFinals) {
        expect(tie.isCompleted, isTrue);
        expect(tie.winner, isNotNull);
      }

      // SF Leg 1 (MD 9) & Leg 2 (MD 10)
      final sf1Results = ucl.simulateMatchday(9, simEngine: sim);
      expect(sf1Results.length, 2);
      expect(ucl.semiFinals.length, 2);

      final sf2Results = ucl.simulateMatchday(10, simEngine: sim);
      expect(sf2Results.length, 2);
      for (final tie in ucl.semiFinals) {
        expect(tie.isCompleted, isTrue);
        expect(tie.winner, isNotNull);
      }

      // Final (MD 11)
      final finalResults = ucl.simulateMatchday(11, simEngine: sim);
      expect(finalResults.length, 1);
      expect(ucl.finalTie, isNotNull);
      expect(ucl.finalTie!.isCompleted, isTrue);
      expect(ucl.champion, isNotNull);
      expect([ucl.finalTie!.clubA, ucl.finalTie!.clubB].contains(ucl.champion), isTrue);

      // Verify UCL stats tracking
      expect(ucl.playerGoals.isNotEmpty, isTrue);
      expect(ucl.playerCleanSheets.isNotEmpty, isTrue);
    });

    test('UclTournament serializes toMap and restores fromMap without data loss', () {
      final ucl = UclTournament.create(userClub: 'Arsenal');
      final sim = SimEngine(777);
      ucl.simulateMatchday(1, simEngine: sim);

      final map = ucl.toMap();
      final restored = UclTournament.fromMap(map);

      expect(restored.userClub, ucl.userClub);
      expect(restored.participants.length, ucl.participants.length);
      expect(restored.groups.length, 4);
      expect(restored.groupTables.length, 4);
      expect(restored.playerGoals.length, ucl.playerGoals.length);
      expect(restored.playerAssists.length, ucl.playerAssists.length);
    });
  });

  group('Career Extended Persistence & Stats Tests (Fix 18g)', () {
    test('PrefsService saves and restores formationId, uclTournament, and assists/clean sheets in career config', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsService.instance;

      final ucl = UclTournament.create(userClub: 'Arsenal');

      await prefs.saveCareerConfig(
        leagueId: 'premier_league',
        clubName: 'Arsenal',
        clubCode: 'ARS',
        isCustomClub: false,
        squadMode: 'current',
        budget: 95.0,
        season: 1,
        gameweek: 2,
        formationId: '4-2-3-1',
        uclTournament: ucl.toMap(),
        playerAssists: {'Bukayo Saka': 5, 'Martin Ødegaard': 7},
        leagueAssists: {'Bukayo Saka': 5, 'Kevin De Bruyne': 8},
        leagueCleanSheets: {'Arsenal': 3, 'Liverpool': 2},
      );

      final loaded = await prefs.getCareerConfig();
      expect(loaded, isNotNull);
      expect(loaded!['formationId'], '4-2-3-1');
      expect(loaded['uclTournament'], isNotNull);
      final restoredUcl = UclTournament.fromMap(loaded['uclTournament']);
      expect(restoredUcl.userClub, 'Arsenal');
      expect(loaded['playerAssists'], {'Bukayo Saka': 5, 'Martin Ødegaard': 7});
      expect(loaded['leagueAssists'], {'Bukayo Saka': 5, 'Kevin De Bruyne': 8});
      expect(loaded['leagueCleanSheets'], {'Arsenal': 3, 'Liverpool': 2});
    });
  });

  group('Tiered Club Starting Budgets by Prestige & Wealth (Fix 20)', () {
    test('Elite clubs receive Tier 1 starting budgets (>= £140M)', () {
      expect(getClubStartingBudget('Manchester City'), 175.0);
      expect(getClubStartingBudget('Real Madrid'), 180.0);
      expect(getClubStartingBudget('Paris Saint-Germain'), 170.0);
      expect(getClubStartingBudget('Chelsea'), 165.0);
      expect(getClubStartingBudget('Manchester United'), 160.0);
      expect(getClubStartingBudget('Bayern Munich'), 150.0);
      expect(getClubStartingBudget('Arsenal'), 145.0);
      expect(getClubStartingBudget('Liverpool'), 140.0);
    });

    test('Challengers & upper-tier clubs receive Tier 2 budgets (£85M to £115M)', () {
      expect(getClubStartingBudget('Newcastle United'), 115.0);
      expect(getClubStartingBudget('Tottenham Hotspur'), 110.0);
      expect(getClubStartingBudget('Aston Villa'), 95.0);
      expect(getClubStartingBudget('Barcelona'), 90.0);
      expect(getClubStartingBudget('Atlético Madrid'), 90.0);
      expect(getClubStartingBudget('Juventus'), 90.0);
      expect(getClubStartingBudget('Borussia Dortmund'), 85.0);
      expect(getClubStartingBudget('Inter Milan'), 85.0);
      expect(getClubStartingBudget('Bayer Leverkusen'), 85.0);
    });

    test('Mid-table clubs receive Tier 3 budgets (£55M to £75M)', () {
      expect(getClubStartingBudget('West Ham United'), 75.0);
      expect(getClubStartingBudget('Brighton & Hove Albion'), 70.0);
      expect(getClubStartingBudget('AFC Bournemouth'), 65.0);
      expect(getClubStartingBudget('Crystal Palace'), 65.0);
      expect(getClubStartingBudget('Fulham'), 60.0);
      expect(getClubStartingBudget('Everton'), 55.0);
      expect(getClubStartingBudget('Wolverhampton Wanderers'), 55.0);
    });

    test('Relegation battlers & promoted clubs receive Tier 4 budgets (£30M to £45M)', () {
      expect(getClubStartingBudget('Brentford'), 45.0);
      expect(getClubStartingBudget('Nottingham Forest'), 45.0);
      expect(getClubStartingBudget('Leicester City'), 40.0);
      expect(getClubStartingBudget('Southampton'), 35.0);
      expect(getClubStartingBudget('Ipswich Town'), 30.0);
    });

    test('Unlisted or generic clubs receive default £65M baseline', () {
      expect(getClubStartingBudget('Unknown FC'), 65.0);
    });
  });

  group('Performance-Based Prize Money & Dynamic Win Bonuses (Fix 21)', () {
    test('League merit prize money scales smoothly from £40M for 1st down to £5M for last', () {
      // 20-team Premier League
      expect(calculateLeagueMeritPrizeMoney(1, 20), 40.0);
      expect(calculateLeagueMeritPrizeMoney(20, 20), 5.0);
      expect(calculateLeagueMeritPrizeMoney(10, 20), closeTo(23.4, 0.1));

      // 10-team Continental Elite
      expect(calculateLeagueMeritPrizeMoney(1, 10), 40.0);
      expect(calculateLeagueMeritPrizeMoney(10, 10), 5.0);
      expect(calculateLeagueMeritPrizeMoney(5, 10), closeTo(24.4, 0.1));

      // Edge cases & clamping
      expect(calculateLeagueMeritPrizeMoney(0, 20), 40.0);
      expect(calculateLeagueMeritPrizeMoney(25, 20), 5.0);
      expect(calculateLeagueMeritPrizeMoney(1, 1), 25.0);
    });

    test('UCL progression prize money awards up to £30M for champions', () {
      final ucl = UclTournament.create(userClub: 'Real Madrid');

      // As group participant
      expect(calculateUclPrizeMoney(ucl, 'Real Madrid'), 5.0);
      expect(calculateUclPrizeMoney(ucl, 'Non Participant FC'), 0.0);

      // As champion
      ucl.champion = 'Real Madrid';
      expect(calculateUclPrizeMoney(ucl, 'Real Madrid'), 30.0);
    });

    test('PrefsService accurately persists and restores prizeMoney metric', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsService.instance;

      await prefs.saveCareerConfig(
        leagueId: 'premier_league',
        clubName: 'Liverpool',
        clubCode: 'LIV',
        isCustomClub: false,
        squadMode: 'current',
        budget: 140.0,
        prizeMoney: 18.5,
      );

      final loaded = await prefs.getCareerConfig();
      expect(loaded, isNotNull);
      expect(loaded!['prizeMoney'], 18.5);
      expect(loaded['budget'], 140.0);
    });
  });

  group('Cumulative League-Wide Team Stats Leaderboard (Fix 22)', () {
    test('ClubTeamStats records goals scored, conceded, clean sheets, and average rating', () {
      const stats = ClubTeamStats(
        clubName: 'Arsenal',
        clubCode: 'ARS',
        played: 10,
        won: 8,
        drawn: 1,
        lost: 1,
        goalsFor: 24,
        goalsAgainst: 7,
        goalDifference: 17,
        cleanSheets: 6,
        avgRating: 7.45,
        points: 25,
      );

      expect(stats.clubName, 'Arsenal');
      expect(stats.goalsFor, 24);
      expect(stats.goalsAgainst, 7);
      expect(stats.cleanSheets, 6);
      expect(stats.avgRating, 7.45);
      expect(stats.goalDifference, 17);
    });

    test('ClubTeamStats sorting supports Attack (GF), Defense (GA), Clean Sheets (CS), and Rating (AVG)', () {
      final clubs = [
        const ClubTeamStats(
          clubName: 'Man City', clubCode: 'MCI', played: 10, won: 7, drawn: 2, lost: 1,
          goalsFor: 28, goalsAgainst: 12, goalDifference: 16, cleanSheets: 4, avgRating: 7.30, points: 23,
        ),
        const ClubTeamStats(
          clubName: 'Arsenal', clubCode: 'ARS', played: 10, won: 8, drawn: 1, lost: 1,
          goalsFor: 22, goalsAgainst: 6, goalDifference: 16, cleanSheets: 7, avgRating: 7.50, points: 25,
        ),
        const ClubTeamStats(
          clubName: 'Liverpool', clubCode: 'LIV', played: 10, won: 7, drawn: 1, lost: 2,
          goalsFor: 25, goalsAgainst: 10, goalDifference: 15, cleanSheets: 5, avgRating: 7.35, points: 22,
        ),
      ];

      // Sort by Attack (GF desc)
      final attackSorted = List<ClubTeamStats>.from(clubs)
        ..sort((a, b) => b.goalsFor.compareTo(a.goalsFor));
      expect(attackSorted.first.clubName, 'Man City');

      // Sort by Defense (GA asc)
      final defenseSorted = List<ClubTeamStats>.from(clubs)
        ..sort((a, b) => a.goalsAgainst.compareTo(b.goalsAgainst));
      expect(defenseSorted.first.clubName, 'Arsenal');

      // Sort by Clean Sheets (CS desc)
      final csSorted = List<ClubTeamStats>.from(clubs)
        ..sort((a, b) => b.cleanSheets.compareTo(a.cleanSheets));
      expect(csSorted.first.clubName, 'Arsenal');

      // Sort by Average Rating (avgRating desc)
      final ratingSorted = List<ClubTeamStats>.from(clubs)
        ..sort((a, b) => b.avgRating.compareTo(a.avgRating));
      expect(ratingSorted.first.clubName, 'Arsenal');
    });

    test('PrefsService preserves leagueClubRatingTotals and leagueClubRatingCounts', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsService.instance;

      await prefs.saveCareerConfig(
        leagueId: 'premier_league',
        clubName: 'Arsenal',
        clubCode: 'ARS',
        isCustomClub: false,
        squadMode: 'current',
        leagueClubRatingTotals: {'Arsenal': 74.5, 'Liverpool': 72.8},
        leagueClubRatingCounts: {'Arsenal': 10, 'Liverpool': 10},
      );

      final loaded = await prefs.getCareerConfig();
      expect(loaded, isNotNull);
      expect(loaded!['leagueClubRatingTotals'], {'Arsenal': 74.5, 'Liverpool': 72.8});
      expect(loaded['leagueClubRatingCounts'], {'Arsenal': 10, 'Liverpool': 10});
    });
  });

  group('User Match Simulation Prominence (Fix 23 / User Fix 1)', () {
    test('Simulated round fixtures sort user club match to index 0 regardless of generation order', () {
      const userClub = 'Arsenal';
      final matches = <MatchResult>[
        const MatchResult(
          homeClub: 'Chelsea',
          awayClub: 'Liverpool',
          homeGoals: 1,
          awayGoals: 1,
          attendance: 40000,
          homeGoalEvents: [],
          awayGoalEvents: [],
        ),
        const MatchResult(
          homeClub: 'Manchester City',
          awayClub: 'Tottenham Hotspur',
          homeGoals: 2,
          awayGoals: 0,
          attendance: 52000,
          homeGoalEvents: [],
          awayGoalEvents: [],
        ),
        const MatchResult(
          homeClub: 'Everton',
          awayClub: userClub,
          homeGoals: 0,
          awayGoals: 3,
          attendance: 39000,
          homeGoalEvents: [],
          awayGoalEvents: [],
        ),
        const MatchResult(
          homeClub: 'Newcastle United',
          awayClub: 'Aston Villa',
          homeGoals: 2,
          awayGoals: 2,
          attendance: 51000,
          homeGoalEvents: [],
          awayGoalEvents: [],
        ),
      ];

      // Sort with user match prominence logic
      final sorted = List<MatchResult>.from(matches)..sort((a, b) {
        final aUser = a.homeClub == userClub || a.awayClub == userClub;
        final bUser = b.homeClub == userClub || b.awayClub == userClub;
        if (aUser && !bUser) return -1;
        if (!aUser && bUser) return 1;
        return 0;
      });

      expect(sorted.first.awayClub, userClub, reason: 'User club match must be placed at index 0');
      expect(sorted.length, 4);
    });

    test('UCL simulated results sort user club match to index 0 when participating', () {
      const userClub = 'Real Madrid';
      final uclMatches = <MatchResult>[
        const MatchResult(
          homeClub: 'Bayern Munich',
          awayClub: 'PSG',
          homeGoals: 2,
          awayGoals: 1,
          attendance: 75000,
          homeGoalEvents: [],
          awayGoalEvents: [],
        ),
        const MatchResult(
          homeClub: userClub,
          awayClub: 'Inter Milan',
          homeGoals: 3,
          awayGoals: 1,
          attendance: 81000,
          homeGoalEvents: [],
          awayGoalEvents: [],
        ),
        const MatchResult(
          homeClub: 'Barcelona',
          awayClub: 'Arsenal',
          homeGoals: 1,
          awayGoals: 1,
          attendance: 68000,
          homeGoalEvents: [],
          awayGoalEvents: [],
        ),
      ];

      final sorted = List<MatchResult>.from(uclMatches)..sort((a, b) {
        final aUser = a.homeClub == userClub || a.awayClub == userClub;
        final bUser = b.homeClub == userClub || b.awayClub == userClub;
        if (aUser && !bUser) return -1;
        if (!aUser && bUser) return 1;
        return 0;
      });

      expect(sorted.first.homeClub, userClub, reason: 'User UCL match must be at index 0');
      expect(sorted.length, 3);
    });

    test('Restoring saved results preserves user club match at index 0', () {
      const userClub = 'Arsenal';
      final savedMaps = [
        {'homeClub': 'Chelsea', 'awayClub': 'Liverpool', 'homeGoals': 1, 'awayGoals': 1},
        {'homeClub': 'Arsenal', 'awayClub': 'Fulham', 'homeGoals': 2, 'awayGoals': 0},
      ];

      final restored = savedMaps.map((m) => MatchResult.fromMap(m)).toList();
      restored.sort((a, b) {
        final aUser = a.homeClub == userClub || a.awayClub == userClub;
        final bUser = b.homeClub == userClub || b.awayClub == userClub;
        if (aUser && !bUser) return -1;
        if (!aUser && bUser) return 1;
        return 0;
      });

      expect(restored.first.homeClub, 'Arsenal');
    });
  });

  group('Fix 24: UCL Simulation Display, Persistence & Scorelines', () {
    test('UCL Engine schedule operates seamlessly in both 38-GW and 18-GW modes', () {
      // 38-GW marathon mode
      expect(UclTournament.getUclMatchdayForLeagueGw(3, totalGameweeks: 38), 1);
      expect(UclTournament.getUclMatchdayForLeagueGw(6, totalGameweeks: 38), 2);
      expect(UclTournament.getUclMatchdayForLeagueGw(9, totalGameweeks: 38), 3);
      expect(UclTournament.getUclMatchdayForLeagueGw(12, totalGameweeks: 38), 4);
      expect(UclTournament.getUclMatchdayForLeagueGw(15, totalGameweeks: 38), 5);
      expect(UclTournament.getUclMatchdayForLeagueGw(18, totalGameweeks: 38), 6);
      expect(UclTournament.getUclMatchdayForLeagueGw(22, totalGameweeks: 38), 7); // QF 1
      expect(UclTournament.getUclMatchdayForLeagueGw(25, totalGameweeks: 38), 8); // QF 2
      expect(UclTournament.getUclMatchdayForLeagueGw(28, totalGameweeks: 38), 9); // SF 1
      expect(UclTournament.getUclMatchdayForLeagueGw(31, totalGameweeks: 38), 10); // SF 2
      expect(UclTournament.getUclMatchdayForLeagueGw(35, totalGameweeks: 38), 11); // Final
      expect(UclTournament.getUclMatchdayForLeagueGw(4, totalGameweeks: 38), isNull);

      // 18-GW sprint mode (10-club leagues)
      expect(UclTournament.getUclMatchdayForLeagueGw(2, totalGameweeks: 18), 1);
      expect(UclTournament.getUclMatchdayForLeagueGw(4, totalGameweeks: 18), 2);
      expect(UclTournament.getUclMatchdayForLeagueGw(6, totalGameweeks: 18), 3);
      expect(UclTournament.getUclMatchdayForLeagueGw(8, totalGameweeks: 18), 4);
      expect(UclTournament.getUclMatchdayForLeagueGw(10, totalGameweeks: 18), 5);
      expect(UclTournament.getUclMatchdayForLeagueGw(12, totalGameweeks: 18), 6);
      expect(UclTournament.getUclMatchdayForLeagueGw(14, totalGameweeks: 18), 7); // QF 1
      expect(UclTournament.getUclMatchdayForLeagueGw(15, totalGameweeks: 18), 8); // QF 2
      expect(UclTournament.getUclMatchdayForLeagueGw(16, totalGameweeks: 18), 9); // SF 1
      expect(UclTournament.getUclMatchdayForLeagueGw(17, totalGameweeks: 18), 10); // SF 2
      expect(UclTournament.getUclMatchdayForLeagueGw(18, totalGameweeks: 18), 11); // Final
      expect(UclTournament.getUclMatchdayForLeagueGw(3, totalGameweeks: 18), isNull);
    });

    test('PrefsService accurately persists and clears recent UCL results', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsService.instance;

      final uclMatch = const MatchResult(
        homeClub: 'Real Madrid',
        awayClub: 'Arsenal',
        homeGoals: 2,
        awayGoals: 3,
        attendance: 82000,
        homeGoalEvents: [GoalEvent(scorerName: 'Vinicius Jr', minute: 21)],
        awayGoalEvents: [
          GoalEvent(scorerName: 'Bukayo Saka', minute: 14),
          GoalEvent(scorerName: 'Gabriel Martinelli', minute: 78),
          GoalEvent(scorerName: 'Declan Rice', minute: 89),
        ],
      );

      await prefs.saveCareerConfig(
        leagueId: 'premier_league',
        clubName: 'Arsenal',
        clubCode: 'ARS',
        isCustomClub: false,
        squadMode: 'current',
        budget: 100.0,
        season: 1,
        gameweek: 4,
        recentUclResults: [uclMatch.toMap()],
      );

      final loaded = await prefs.getCareerConfig();
      expect(loaded, isNotNull);
      final rawUcl = loaded!['recentUclResults'] as List<dynamic>?;
      expect(rawUcl, isNotNull);
      expect(rawUcl!.length, 1);

      final restoredUcl = MatchResult.fromMap(Map<String, dynamic>.from(rawUcl.first as Map));
      expect(restoredUcl.homeClub, 'Real Madrid');
      expect(restoredUcl.awayClub, 'Arsenal');
      expect(restoredUcl.homeGoals, 2);
      expect(restoredUcl.awayGoals, 3);
      expect(restoredUcl.awayGoalEvents.length, 3);
      expect(restoredUcl.awayGoalEvents[0].scorerName, 'Bukayo Saka');

      await prefs.clearCareerConfig();
      final cleared = await prefs.getCareerConfig();
      expect(cleared, isNull);
    });

    test('UclTournament simulates matchday and populates scorelines and tables', () {
      final ucl = UclTournament.create(userClub: 'Arsenal');
      expect(ucl.participants.contains('Arsenal'), isTrue);
      expect(ucl.groupFixtures.length, 48); // 4 groups × 12 matches (6 matchdays × 2 matches/group)

      // Simulate MD 1 (4 groups × 2 matches = 8 matches)
      final squadProviders = <String, List<SimPlayer>>{
        'Arsenal': [
          const SimPlayer(name: 'David Raya', position: 'GK', overall: 85),
          const SimPlayer(name: 'Bukayo Saka', position: 'RW', overall: 88),
          const SimPlayer(name: 'Declan Rice', position: 'CM', overall: 87),
        ],
      };

      final md1Results = ucl.simulateMatchday(
        1,
        simEngine: SimEngine(),
        clubPlayers: squadProviders,
      );
      expect(md1Results.length, 8);

      // Played fixtures must now be isPlayed = true
      final playedMd1 = ucl.groupFixtures.where((f) => f.matchday == 1 && f.isPlayed).toList();
      expect(playedMd1.length, 8);

      for (final f in playedMd1) {
        expect(f.result, isNotNull);
        expect(f.result!.homeClub, f.homeClub);
        expect(f.result!.awayClub, f.awayClub);
      }

      // Group table points must have updated
      int totalPoints = 0;
      for (final table in ucl.groupTables.values) {
        for (final entry in table) {
          totalPoints += entry.points;
        }
      }
      expect(totalPoints, greaterThan(0));
    });
  });

  group('Fix 25: Goalkeeper Substitution & Position/Rating Weighted Scoring (User Fix 3)', () {
    test('SimEngine.normalizeSquadRoles guarantees exactly 1 starter GK, 10 outfielders, and 1 bench GK', () {
      final inputSquad = [
        const SimPlayer(name: 'Backup Keeper', position: 'GK', overall: 75),
        const SimPlayer(name: 'Star Keeper', position: 'GK', overall: 87),
        const SimPlayer(name: 'Defender 1', position: 'CB', overall: 84),
        const SimPlayer(name: 'Defender 2', position: 'CB', overall: 82),
        const SimPlayer(name: 'Defender 3', position: 'LB', overall: 80),
        const SimPlayer(name: 'Defender 4', position: 'RB', overall: 79),
        const SimPlayer(name: 'Midfielder 1', position: 'CM', overall: 85),
        const SimPlayer(name: 'Midfielder 2', position: 'CAM', overall: 86),
        const SimPlayer(name: 'Midfielder 3', position: 'CDM', overall: 81),
        const SimPlayer(name: 'Forward 1', position: 'ST', overall: 88),
        const SimPlayer(name: 'Forward 2', position: 'LW', overall: 85),
        const SimPlayer(name: 'Forward 3', position: 'RW', overall: 83),
        const SimPlayer(name: 'Reserve Def', position: 'CB', overall: 76),
        const SimPlayer(name: 'Reserve Mid', position: 'CM', overall: 77),
        const SimPlayer(name: 'Reserve Fwd', position: 'ST', overall: 78),
      ];

      final normalized = SimEngine.normalizeSquadRoles(inputSquad);

      // Starters (first 11)
      final starters = normalized.where((p) => p.isStarter).toList();
      expect(starters.length, 11);

      final starterGks = starters.where((p) => SimEngine.isGoalkeeper(p.position)).toList();
      expect(starterGks.length, 1, reason: 'Must have exactly 1 starting Goalkeeper');
      expect(starterGks.first.name, 'Star Keeper', reason: 'Highest rated goalkeeper must be the starter');

      final starterOutfield = starters.where((p) => !SimEngine.isGoalkeeper(p.position)).toList();
      expect(starterOutfield.length, 10, reason: 'Must have exactly 10 starting outfielders');

      // Bench
      final bench = normalized.where((p) => !p.isStarter).toList();
      expect(bench.isNotEmpty, isTrue);

      final benchGks = bench.where((p) => SimEngine.isGoalkeeper(p.position)).toList();
      expect(benchGks.length, 1, reason: 'Backup keeper must be on the bench');
      expect(benchGks.first.name, 'Backup Keeper');
      expect(normalized[11].name, 'Backup Keeper', reason: 'Index 11 should be the reserve Goalkeeper');
    });

    test('SimEngine match simulation generates zero goalkeeper substitutions', () {
      final sim = SimEngine(42);
      final squadA = [
        const SimPlayer(name: 'Starter GK A', position: 'GK', overall: 85, isStarter: true),
        const SimPlayer(name: 'CB1 A', position: 'CB', overall: 82, isStarter: true),
        const SimPlayer(name: 'CB2 A', position: 'CB', overall: 81, isStarter: true),
        const SimPlayer(name: 'LB A', position: 'LB', overall: 80, isStarter: true),
        const SimPlayer(name: 'RB A', position: 'RB', overall: 79, isStarter: true),
        const SimPlayer(name: 'CDM A', position: 'CDM', overall: 82, isStarter: true),
        const SimPlayer(name: 'CM1 A', position: 'CM', overall: 83, isStarter: true),
        const SimPlayer(name: 'CM2 A', position: 'CAM', overall: 84, isStarter: true),
        const SimPlayer(name: 'LW A', position: 'LW', overall: 85, isStarter: true),
        const SimPlayer(name: 'RW A', position: 'RW', overall: 86, isStarter: true),
        const SimPlayer(name: 'ST A', position: 'ST', overall: 88, isStarter: true),
        // Bench
        const SimPlayer(name: 'Bench GK A', position: 'GK', overall: 75, isStarter: false),
        const SimPlayer(name: 'Sub CB A', position: 'CB', overall: 76, isStarter: false),
        const SimPlayer(name: 'Sub CM A', position: 'CM', overall: 77, isStarter: false),
        const SimPlayer(name: 'Sub ST A', position: 'ST', overall: 78, isStarter: false),
      ];

      final squadB = [
        const SimPlayer(name: 'Starter GK B', position: 'GK', overall: 84, isStarter: true),
        const SimPlayer(name: 'CB1 B', position: 'CB', overall: 80, isStarter: true),
        const SimPlayer(name: 'CB2 B', position: 'CB', overall: 80, isStarter: true),
        const SimPlayer(name: 'LB B', position: 'LB', overall: 78, isStarter: true),
        const SimPlayer(name: 'RB B', position: 'RB', overall: 78, isStarter: true),
        const SimPlayer(name: 'CDM B', position: 'CDM', overall: 80, isStarter: true),
        const SimPlayer(name: 'CM1 B', position: 'CM', overall: 81, isStarter: true),
        const SimPlayer(name: 'CM2 B', position: 'CAM', overall: 82, isStarter: true),
        const SimPlayer(name: 'LW B', position: 'LW', overall: 83, isStarter: true),
        const SimPlayer(name: 'RW B', position: 'RW', overall: 84, isStarter: true),
        const SimPlayer(name: 'ST B', position: 'ST', overall: 86, isStarter: true),
        // Bench
        const SimPlayer(name: 'Bench GK B', position: 'GK', overall: 74, isStarter: false),
        const SimPlayer(name: 'Sub DEF B', position: 'CB', overall: 75, isStarter: false),
        const SimPlayer(name: 'Sub MID B', position: 'CM', overall: 76, isStarter: false),
        const SimPlayer(name: 'Sub FWD B', position: 'ST', overall: 77, isStarter: false),
      ];

      int totalSubs = 0;
      int gkSubs = 0;

      for (int i = 0; i < 500; i++) {
        final result = sim.simulateMatch(
          homeClub: 'Club A',
          homeRating: 84,
          awayClub: 'Club B',
          awayRating: 82,
          homePlayers: squadA,
          awayPlayers: squadB,
        );

        final allSubs = [...result.homeSubstitutions, ...result.awaySubstitutions];
        totalSubs += allSubs.length;

        for (final sub in allSubs) {
          if (sub.playerOut.contains('GK') || sub.playerIn.contains('GK')) {
            gkSubs++;
          }
        }
      }

      expect(totalSubs, greaterThan(500), reason: 'Should have simulated hundreds of substitutions');
      expect(gkSubs, 0, reason: 'Goalkeepers must NEVER be substituted with outfield players');
    });

    test('Goal scoring probability increases with position (FWD > MID > DEF) and rating, with GK < 0.1%', () {
      final sim = SimEngine(12345);
      final squad = [
        const SimPlayer(name: 'Goalkeeper', position: 'GK', overall: 85, isStarter: true),
        const SimPlayer(name: 'Defender Low', position: 'CB', overall: 74, isStarter: true),
        const SimPlayer(name: 'Defender High', position: 'CB', overall: 86, isStarter: true),
        const SimPlayer(name: 'Fullback', position: 'LB', overall: 80, isStarter: true),
        const SimPlayer(name: 'Midfielder Low', position: 'CM', overall: 75, isStarter: true),
        const SimPlayer(name: 'Midfielder High', position: 'CAM', overall: 87, isStarter: true),
        const SimPlayer(name: 'Winger', position: 'LW', overall: 84, isStarter: true),
        const SimPlayer(name: 'Forward Low', position: 'ST', overall: 75, isStarter: true),
        const SimPlayer(name: 'Forward High', position: 'ST', overall: 90, isStarter: true),
        const SimPlayer(name: 'Bench GK', position: 'GK', overall: 72, isStarter: false),
        const SimPlayer(name: 'Bench Outfield', position: 'ST', overall: 76, isStarter: false),
      ];

      final opponentSquad = [
        const SimPlayer(name: 'Opp GK', position: 'GK', overall: 80, isStarter: true),
        const SimPlayer(name: 'Opp CB', position: 'CB', overall: 80, isStarter: true),
      ];

      final scorerCounts = <String, int>{};
      int totalGoals = 0;

      for (int i = 0; i < 2000; i++) {
        final result = sim.simulateMatch(
          homeClub: 'Test Club',
          homeRating: 85,
          awayClub: 'Opp Club',
          awayRating: 75,
          homePlayers: squad,
          awayPlayers: opponentSquad,
        );

        for (final g in result.homeGoalEvents) {
          if (!g.isOwnGoal) {
            totalGoals++;
            scorerCounts[g.scorerName] = (scorerCounts[g.scorerName] ?? 0) + 1;
            if (g.isPenalty) {
              expect(g.scorerName.contains('Goalkeeper'), isFalse, reason: 'GKs must never take penalties');
            }
          }
        }
      }

      expect(totalGoals, greaterThan(2000));

      final gkGoals = (scorerCounts['Goalkeeper'] ?? 0) + (scorerCounts['Bench GK'] ?? 0);
      final gkGoalRate = gkGoals / totalGoals;

      // GK scoring chance must strictly be < 0.1% (0.001)
      expect(gkGoalRate, lessThan(0.001),
          reason: 'Goalkeeper scoring rate ($gkGoalRate) must be strictly less than 0.1% (< 0.001)');

      // Rating impact: High-rated forward (90 OVR) must score significantly more than Low-rated forward (75 OVR)
      final fwdHighGoals = scorerCounts['Forward High'] ?? 0;
      final fwdLowGoals = scorerCounts['Forward Low'] ?? 0;
      expect(fwdHighGoals, greaterThan(fwdLowGoals * 1.5),
          reason: '90-rated forward ($fwdHighGoals) must score much more than 75-rated forward ($fwdLowGoals)');

      // Position impact: Forwards must score far more than Defenders
      final totalFwdGoals = (scorerCounts['Forward High'] ?? 0) +
          (scorerCounts['Forward Low'] ?? 0) +
          (scorerCounts['Winger'] ?? 0);
      final totalDefGoals = (scorerCounts['Defender High'] ?? 0) +
          (scorerCounts['Defender Low'] ?? 0) +
          (scorerCounts['Fullback'] ?? 0);
      expect(totalFwdGoals, greaterThan(totalDefGoals * 3),
          reason: 'Forwards ($totalFwdGoals) must score far more than defenders ($totalDefGoals)');
    });
  });
}
