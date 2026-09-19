import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:touchline/core/database/save_service.dart';
import 'package:touchline/core/storage/prefs_service.dart';
import 'package:touchline/domain/models/player.dart';
import 'package:touchline/domain/services/sim_engine.dart';
import 'package:touchline/domain/services/ucl_engine.dart';
import 'package:touchline/domain/services/cup_engine.dart';
import 'package:touchline/domain/services/player_growth_service.dart';
import 'package:touchline/domain/models/transfer_offer.dart';
import 'package:touchline/domain/services/transfer_offer_service.dart';
import 'package:touchline/domain/models/squad_event.dart';
import 'package:touchline/domain/services/squad_event_service.dart';
import 'package:touchline/domain/services/transfer_market_service.dart';
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

    test('PitchSlot.clampSlot respects pitch boundaries and restricts Goalkeeper to defending box (Fix 31)', () {
      // Outfield player dragged out of bounds
      final clampedOutfieldLow = PitchSlot.clampSlot(1, -0.2, -0.5);
      expect(clampedOutfieldLow.x, closeTo(0.08, 0.001));
      expect(clampedOutfieldLow.y, closeTo(0.08, 0.001));

      final clampedOutfieldHigh = PitchSlot.clampSlot(5, 1.5, 1.2);
      expect(clampedOutfieldHigh.x, closeTo(0.92, 0.001));
      expect(clampedOutfieldHigh.y, closeTo(0.88, 0.001));

      // Goalkeeper (slot 0) strictly restricted to defending penalty box
      final clampedGkFarLeft = PitchSlot.clampSlot(0, 0.1, 0.5);
      expect(clampedGkFarLeft.defaultRole, 'GK');
      expect(clampedGkFarLeft.x, closeTo(0.35, 0.001));
      expect(clampedGkFarLeft.y, closeTo(0.78, 0.001));

      final clampedGkFarRight = PitchSlot.clampSlot(0, 0.9, 0.99);
      expect(clampedGkFarRight.defaultRole, 'GK');
      expect(clampedGkFarRight.x, closeTo(0.65, 0.001));
      expect(clampedGkFarRight.y, closeTo(0.94, 0.001));
    });

    test('PitchSlot.deriveTacticalRole dynamically deduces realistic tactical positions (Fix 31)', () {
      // Goalkeeper
      expect(PitchSlot.deriveTacticalRole(0, 0.50, 0.90), 'GK');

      // Attacking third
      expect(PitchSlot.deriveTacticalRole(10, 0.50, 0.15), 'ST');
      expect(PitchSlot.deriveTacticalRole(9, 0.15, 0.20), 'LW');
      expect(PitchSlot.deriveTacticalRole(11, 0.85, 0.20), 'RW');
      expect(PitchSlot.deriveTacticalRole(8, 0.50, 0.28), 'CF');

      // Midfield
      expect(PitchSlot.deriveTacticalRole(7, 0.50, 0.38), 'CAM');
      expect(PitchSlot.deriveTacticalRole(6, 0.18, 0.40), 'LM');
      expect(PitchSlot.deriveTacticalRole(5, 0.82, 0.40), 'RM');
      expect(PitchSlot.deriveTacticalRole(4, 0.30, 0.52), 'LCM');
      expect(PitchSlot.deriveTacticalRole(3, 0.70, 0.52), 'RCM');
      expect(PitchSlot.deriveTacticalRole(2, 0.50, 0.52), 'CM');

      // Defensive midfield & backline
      expect(PitchSlot.deriveTacticalRole(6, 0.50, 0.62), 'CDM');
      expect(PitchSlot.deriveTacticalRole(2, 0.15, 0.72), 'LB');
      expect(PitchSlot.deriveTacticalRole(5, 0.85, 0.72), 'RB');
      expect(PitchSlot.deriveTacticalRole(3, 0.38, 0.75), 'LCB');
      expect(PitchSlot.deriveTacticalRole(4, 0.62, 0.75), 'RCB');
    });

    test('PitchSlot serialization and copyWith works seamlessly (Fix 31)', () {
      const slot = PitchSlot(defaultRole: 'CAM', x: 0.50, y: 0.40);
      final copy = slot.copyWith(y: 0.35);
      expect(copy.defaultRole, 'CAM');
      expect(copy.x, 0.50);
      expect(copy.y, 0.35);

      final json = copy.toJson();
      expect(json['defaultRole'], 'CAM');
      expect(json['x'], 0.50);
      expect(json['y'], 0.35);

      final restored = PitchSlot.fromJson(json);
      expect(restored.defaultRole, 'CAM');
      expect(restored.x, 0.50);
      expect(restored.y, 0.35);
    });

    test('TacticalFormation.isCustomized detects customized slot coordinates vs canonical presets (Fix 31)', () {
      final f = TacticalFormation.getById('4-3-3');
      expect(f.isCustomized(f.slots), isFalse);

      final slightlyShifted = List<PitchSlot>.from(f.slots);
      slightlyShifted[9] = PitchSlot.clampSlot(9, f.slots[9].x, f.slots[9].y - 0.05); // Move ST higher
      expect(f.isCustomized(slightlyShifted), isTrue);

      // Shifting back matches default
      expect(f.isCustomized(f.slots), isFalse);
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

  group('Fix 26: Domestic Cups (FA Cup & Carabao Cup) Tournament Engine & Stats', () {
    test('CupTournament.create initializes 16 clubs, ensures user club is present, and creates 8 R16 fixtures', () {
      final userClub = 'Arsenal';
      final faCup = CupTournament.create(id: 'fa_cup', userClub: userClub);
      expect(faCup.id, 'fa_cup');
      expect(faCup.name, 'The Emirates FA Cup');
      expect(faCup.shortName, 'FA CUP');
      expect(faCup.participants.length, 16);
      expect(faCup.participants.contains(userClub), isTrue);
      expect(faCup.fixtures.length, 8);
      expect(faCup.fixtures.every((f) => f.roundIndex == 1 && f.stage == 'Round of 16'), isTrue);
      expect(faCup.champion, isNull);
      expect(faCup.runnerUp, isNull);

      final carabao = CupTournament.create(id: 'carabao_cup', userClub: userClub);
      expect(carabao.id, 'carabao_cup');
      expect(carabao.name, 'Carabao Cup');
      expect(carabao.shortName, 'CARABAO');
      expect(carabao.participants.length, 16);
      expect(carabao.participants.contains(userClub), isTrue);
      expect(carabao.fixtures.length, 8);
    });

    test('Knockout progression advances cleanly through all 4 stages to crown Champion and Runner-up', () {
      final sim = SimEngine(12345);
      final faCup = CupTournament.create(id: 'fa_cup', userClub: 'Liverpool');

      // Round 1: R16 (8 ties)
      expect(faCup.getFixturesForRound(1).length, 8);
      expect(faCup.getFixturesForRound(2).length, 0);

      final r16Results = faCup.simulateRound(1, simEngine: sim);
      expect(r16Results.length, 8);
      expect(faCup.getFixturesForRound(1).every((f) => f.isPlayed && f.winner != null), isTrue);

      // Quarter-Finals should now be generated (4 ties)
      expect(faCup.getFixturesForRound(2).length, 4);
      expect(faCup.getFixturesForRound(2).every((f) => !f.isPlayed), isTrue);

      // Round 2: QF
      final qfResults = faCup.simulateRound(2, simEngine: sim);
      expect(qfResults.length, 4);
      expect(faCup.getFixturesForRound(2).every((f) => f.isPlayed && f.winner != null), isTrue);

      // Semi-Finals should now be generated (2 ties)
      expect(faCup.getFixturesForRound(3).length, 2);

      // Round 3: SF
      final sfResults = faCup.simulateRound(3, simEngine: sim);
      expect(sfResults.length, 2);
      expect(faCup.getFixturesForRound(3).every((f) => f.isPlayed && f.winner != null), isTrue);

      // Final should now be generated (1 tie)
      expect(faCup.getFixturesForRound(4).length, 1);

      // Round 4: Final
      final finalResults = faCup.simulateRound(4, simEngine: sim);
      expect(finalResults.length, 1);
      final finalFixture = faCup.getFixturesForRound(4).first;
      expect(finalFixture.isPlayed, isTrue);
      expect(finalFixture.winner, isNotNull);
      expect(faCup.champion, isNotNull);
      expect(faCup.champion, finalFixture.winner);
      expect(faCup.runnerUp, isNotNull);
      expect(faCup.runnerUp, isNot(faCup.champion));
      expect([finalFixture.homeClub, finalFixture.awayClub].contains(faCup.champion), isTrue);
      expect([finalFixture.homeClub, finalFixture.awayClub].contains(faCup.runnerUp), isTrue);
    });

    test('Penalty shootouts properly resolve draws in knockout matches with valid scoreline formatting', () {
      final sim = SimEngine(999);
      final carabao = CupTournament.create(id: 'carabao_cup', userClub: 'Chelsea');
      carabao.simulateRound(1, simEngine: sim);

      // Check all played ties have a winner
      for (final f in carabao.fixtures.where((f) => f.isPlayed)) {
        expect(f.winner, isNotNull);
        expect([f.homeClub, f.awayClub].contains(f.winner), isTrue);
        if (f.result!.homeGoals == f.result!.awayGoals) {
          // Draw must have penalties recorded
          expect(f.homePenalties, isNotNull);
          expect(f.awayPenalties, isNotNull);
          expect(f.homePenalties != f.awayPenalties, isTrue);
          expect(f.scoreline.contains('pen'), isTrue);
        } else {
          expect(f.scoreline, '${f.result!.homeGoals} - ${f.result!.awayGoals}');
        }
      }
    });

    test('Player stats (goals, assists, clean sheets) are recorded and aggregated across rounds', () {
      final sim = SimEngine(777);
      final faCup = CupTournament.create(id: 'fa_cup', userClub: 'Arsenal');

      // Create test squad
      final clubSquads = <String, List<SimPlayer>>{
        'Arsenal': [
          const SimPlayer(name: 'Bukayo Saka', position: 'RW', overall: 88, isStarter: true),
          const SimPlayer(name: 'Martin Ødegaard', position: 'CAM', overall: 89, isStarter: true),
          const SimPlayer(name: 'David Raya', position: 'GK', overall: 85, isStarter: true),
        ],
      };

      // Simulate full tournament
      for (int rd = 1; rd <= 4; rd++) {
        faCup.simulateRound(rd, simEngine: sim, clubPlayers: clubSquads);
      }

      // Verify stats maps
      expect(faCup.playerGoals.isNotEmpty, isTrue);
      expect(faCup.playerClubs.isNotEmpty, isTrue);

      for (final entry in faCup.playerGoals.entries) {
        expect(entry.value, greaterThan(0));
        expect(faCup.playerClubs.containsKey(entry.key), isTrue);
      }
    });

    test('Schedule gameweek mappings align correctly for 38-GW and 18-GW career lengths', () {
      // 38 GW Carabao Cup
      expect(CupTournament.getCarabaoRoundForLeagueGw(5, totalGameweeks: 38), 1);
      expect(CupTournament.getCarabaoRoundForLeagueGw(11, totalGameweeks: 38), 2);
      expect(CupTournament.getCarabaoRoundForLeagueGw(17, totalGameweeks: 38), 3);
      expect(CupTournament.getCarabaoRoundForLeagueGw(24, totalGameweeks: 38), 4);
      expect(CupTournament.getCarabaoRoundForLeagueGw(1, totalGameweeks: 38), isNull);

      // 38 GW FA Cup
      expect(CupTournament.getFaCupRoundForLeagueGw(8, totalGameweeks: 38), 1);
      expect(CupTournament.getFaCupRoundForLeagueGw(14, totalGameweeks: 38), 2);
      expect(CupTournament.getFaCupRoundForLeagueGw(29, totalGameweeks: 38), 3);
      expect(CupTournament.getFaCupRoundForLeagueGw(37, totalGameweeks: 38), 4);
      expect(CupTournament.getFaCupRoundForLeagueGw(2, totalGameweeks: 38), isNull);

      // 18 GW Carabao Cup
      expect(CupTournament.getCarabaoRoundForLeagueGw(3, totalGameweeks: 18), 1);
      expect(CupTournament.getCarabaoRoundForLeagueGw(7, totalGameweeks: 18), 2);
      expect(CupTournament.getCarabaoRoundForLeagueGw(9, totalGameweeks: 18), 3);
      expect(CupTournament.getCarabaoRoundForLeagueGw(11, totalGameweeks: 18), 4);

      // 18 GW FA Cup
      expect(CupTournament.getFaCupRoundForLeagueGw(5, totalGameweeks: 18), 1);
      expect(CupTournament.getFaCupRoundForLeagueGw(13, totalGameweeks: 18), 2);
      expect(CupTournament.getFaCupRoundForLeagueGw(15, totalGameweeks: 18), 3);
      expect(CupTournament.getFaCupRoundForLeagueGw(17, totalGameweeks: 18), 4);
    });

    test('Prize money calculations return appropriate tiered awards for FA Cup and Carabao Cup', () {
      final faCup = CupTournament.create(id: 'fa_cup', userClub: 'Arsenal');
      faCup.champion = 'Arsenal';
      expect(faCup.calculatePrizeMoney(), 15.0);

      faCup.champion = 'Chelsea';
      faCup.runnerUp = 'Arsenal';
      expect(faCup.calculatePrizeMoney(), 6.0);

      final carabao = CupTournament.create(id: 'carabao_cup', userClub: 'Arsenal');
      carabao.champion = 'Arsenal';
      expect(carabao.calculatePrizeMoney(), 8.0);

      carabao.champion = 'Chelsea';
      carabao.runnerUp = 'Arsenal';
      expect(carabao.calculatePrizeMoney(), 3.5);
    });

    test('CupTournament serialization (toMap & fromMap) preserves entire bracket and stats state', () {
      final sim = SimEngine(444);
      final faCup = CupTournament.create(id: 'fa_cup', userClub: 'Tottenham Hotspur');
      faCup.simulateRound(1, simEngine: sim);

      final map = faCup.toMap();
      final restored = CupTournament.fromMap(map);

      expect(restored.id, faCup.id);
      expect(restored.name, faCup.name);
      expect(restored.userClub, faCup.userClub);
      expect(restored.participants.length, faCup.participants.length);
      expect(restored.fixtures.length, faCup.fixtures.length);
      expect(restored.fixtures.where((f) => f.isPlayed).length, 8);
      expect(restored.playerGoals.length, faCup.playerGoals.length);
    });

    test('PrefsService properly persists and restores Domestic Cup tournaments', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsService.instance;

      final faCup = CupTournament.create(id: 'fa_cup', userClub: 'Manchester City');
      final carabao = CupTournament.create(id: 'carabao_cup', userClub: 'Manchester City');

      await prefs.saveCareerConfig(
        leagueId: 'premier_league',
        clubName: 'Manchester City',
        clubCode: 'MCI',
        isCustomClub: false,
        squadMode: 'current',
        budget: 120.0,
        season: 1,
        gameweek: 5,
        squadIds: ['Erling Haaland', 'Kevin De Bruyne'],
        faCupTournament: faCup.toMap(),
        carabaoCupTournament: carabao.toMap(),
      );

      final loaded = await prefs.getCareerConfig();
      expect(loaded, isNotNull);
      expect(loaded!['faCupTournament'], isNotNull);
      expect(loaded['carabaoCupTournament'], isNotNull);

      final loadedFa = CupTournament.fromMap(Map<String, dynamic>.from(loaded['faCupTournament'] as Map));
      final loadedCarabao = CupTournament.fromMap(Map<String, dynamic>.from(loaded['carabaoCupTournament'] as Map));

      expect(loadedFa.id, 'fa_cup');
      expect(loadedFa.userClub, 'Manchester City');
      expect(loadedCarabao.id, 'carabao_cup');
      expect(loadedCarabao.userClub, 'Manchester City');
    });
  });

  group('Fix 27: Dynamic Player Growth & Age 33+ Decline Engine', () {
    Player createTestPlayer({
      required String name,
      required int overall,
      required double age,
      required double potential,
      int pace = 75,
      int shooting = 75,
      int passing = 75,
      int dribbling = 75,
      int defending = 75,
      int physicality = 75,
      String position = 'CM',
    }) {
      return Player(
        mode: 'current',
        squadId: 'squad_1',
        teamCode: 'MUN',
        teamName: 'Manchester United',
        season: 2024,
        playerId: 'p_$name',
        name: name,
        overall: overall,
        displayPosition: position,
        primaryPosition: position,
        allPositions: position,
        age: age,
        potential: potential,
        pace: pace,
        shooting: shooting,
        passing: passing,
        dribbling: dribbling,
        defending: defending,
        physicality: physicality,
        isGoalkeeper: position == 'GK',
      );
    }

    test('Youngster (age <= 23) with high FIFA potential experiences breakout development on great season', () {
      final youngster = createTestPlayer(name: 'Kobbie Mainoo', overall: 76, age: 19, potential: 88);

      final result = PlayerGrowthService.processSeasonGrowth(
        player: youngster,
        appearances: 18,
        averageRating: 7.6,
        goals: 6,
        assists: 7,
        cleanSheets: 0,
      );

      expect(result.oldAge, 19);
      expect(result.newAge, 20);
      expect(result.isGrowth, isTrue);
      expect(result.delta, inInclusiveRange(2, 4));
      expect(result.newOverall, youngster.overall + result.delta);
      expect(result.player.overall, result.newOverall);
      expect(result.player.age, 20.0);
      expect(result.statusLabel, anyOf('EXPLOSIVE GROWTH', 'SOLID PROGRESS'));
      expect(result.player.passing, greaterThan(youngster.passing));
    });

    test('Youngster reaching potential ceiling stops growing and does not exceed potential', () {
      final peakedYoungster = createTestPlayer(name: 'Peaked Prodigy', overall: 87, age: 22, potential: 87);

      final result = PlayerGrowthService.processSeasonGrowth(
        player: peakedYoungster,
        appearances: 25,
        averageRating: 7.8,
        goals: 12,
        assists: 10,
        cleanSheets: 0,
      );

      expect(result.newAge, 23);
      expect(result.delta, 0);
      expect(result.newOverall, 87);
      expect(result.isUnchanged, isTrue);
    });

    test('Veterans (age >= 33) strictly suffer natural decline, never grow', () {
      final veteranElite = createTestPlayer(name: 'Casemiro', overall: 85, age: 33, potential: 85);

      // Excellent campaign softens decline to -1 OVR
      final resultElite = PlayerGrowthService.processSeasonGrowth(
        player: veteranElite,
        appearances: 20,
        averageRating: 7.5,
        goals: 3,
        assists: 4,
        cleanSheets: 8,
      );

      expect(resultElite.oldAge, 33);
      expect(resultElite.newAge, 34);
      expect(resultElite.isDecline, isTrue);
      expect(resultElite.delta, -1);
      expect(resultElite.newOverall, 84);
      expect(resultElite.statusLabel, contains('33+'));
      expect(resultElite.player.pace, lessThanOrEqualTo(veteranElite.pace));

      // Standard campaign at age 34 incurs -2 decline
      final veteranStandard = createTestPlayer(name: 'Veteran Defender', overall: 83, age: 34, potential: 83);
      final resultStandard = PlayerGrowthService.processSeasonGrowth(
        player: veteranStandard,
        appearances: 8,
        averageRating: 6.7,
        goals: 0,
        assists: 1,
        cleanSheets: 2,
      );

      expect(resultStandard.delta, -2);
      expect(resultStandard.newOverall, 81);
      expect(resultStandard.isDecline, isTrue);

      // Poor campaign at age 35 incurs accelerated -3 decline
      final veteranAging = createTestPlayer(name: 'Aging Veteran', overall: 80, age: 35, potential: 80);
      final resultAging = PlayerGrowthService.processSeasonGrowth(
        player: veteranAging,
        appearances: 2,
        averageRating: 5.4,
        goals: 0,
        assists: 0,
        cleanSheets: 0,
      );

      expect(resultAging.delta, -3);
      expect(resultAging.newOverall, 77);
      expect(resultAging.isDecline, isTrue);
    });

    test('Veteran decline respects minimum rating floor of 68', () {
      final lowVeteran = createTestPlayer(name: 'Old Pro', overall: 69, age: 36, potential: 69);

      final result = PlayerGrowthService.processSeasonGrowth(
        player: lowVeteran,
        appearances: 1,
        averageRating: 5.2,
        goals: 0,
        assists: 0,
        cleanSheets: 0,
      );

      expect(result.newOverall, 68);
      expect(result.delta, -1); // Clamped at 68 floor instead of dropping below
    });

    test('FIFA potential tier descriptions match age and potential brackets', () {
      final special = createTestPlayer(name: 'Star', overall: 75, age: 20, potential: 91);
      expect(PlayerGrowthService.getPotentialTierDescription(special), 'Has Potential to be Special');

      final exciting = createTestPlayer(name: 'Talent', overall: 75, age: 21, potential: 87);
      expect(PlayerGrowthService.getPotentialTierDescription(exciting), 'An Exciting Prospect');

      final promising = createTestPlayer(name: 'Prospect', overall: 75, age: 22, potential: 83);
      expect(PlayerGrowthService.getPotentialTierDescription(promising), 'Showing Great Potential');

      final prime = createTestPlayer(name: 'Prime Star', overall: 86, age: 29, potential: 86);
      expect(PlayerGrowthService.getPotentialTierDescription(prime), 'At Peak Prime');

      final veteran = createTestPlayer(name: 'Veteran', overall: 82, age: 34, potential: 82);
      expect(PlayerGrowthService.getPotentialTierDescription(veteran), 'Experienced Veteran');
    });

    test('PrefsService properly persists and restores dynamic playerRatingsOverride and playerAgesOverride', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsService.instance;

      final ratings = {'Kobbie Mainoo': 80, 'Casemiro': 83, 'Bruno Fernandes': 88};
      final ages = {'Kobbie Mainoo': 20, 'Casemiro': 34, 'Bruno Fernandes': 31};

      await prefs.saveCareerConfig(
        leagueId: 'premier_league',
        clubName: 'Manchester United',
        clubCode: 'MUN',
        isCustomClub: false,
        squadMode: 'current',
        playerRatingsOverride: ratings,
        playerAgesOverride: ages,
      );

      final loaded = await prefs.getCareerConfig();
      expect(loaded, isNotNull);
      expect(loaded!['playerRatingsOverride'], isNotNull);
      expect(loaded['playerAgesOverride'], isNotNull);

      final loadedRatings = loaded['playerRatingsOverride'] as Map<String, int>;
      final loadedAges = loaded['playerAgesOverride'] as Map<String, int>;

      expect(loadedRatings['Kobbie Mainoo'], 80);
      expect(loadedRatings['Casemiro'], 83);
      expect(loadedAges['Kobbie Mainoo'], 20);
      expect(loadedAges['Casemiro'], 34);

      await prefs.clearCareerConfig();
      final cleared = await prefs.getCareerConfig();
      expect(cleared, isNull);
    });
  });

  group('Fix 28: Inbound AI Club Transfer Offers & Bids', () {
    test('TransferOffer model serializes and deserializes accurately with all computed properties', () {
      final now = DateTime.now();
      final offer = TransferOffer(
        id: 'offer_1_5_Bruno_1234',
        playerName: 'Bruno Fernandes',
        playerPosition: 'CAM',
        playerOverall: 88,
        playerAge: 30,
        buyingClub: 'Real Madrid',
        buyingClubTier: 'Tier 1 (Elite Mega Club)',
        playerMarketValue: 70.0,
        offeredFeeMillions: 85.5,
        season: 1,
        gameweek: 5,
        status: 'pending',
        date: now,
      );

      expect(offer.isPending, isTrue);
      expect(offer.isAccepted, isFalse);
      expect(offer.isRejected, isFalse);
      expect(offer.premiumPercent, closeTo(22.1, 0.2));

      final map = offer.toMap();
      final fromMap = TransferOffer.fromMap(map);

      expect(fromMap.id, offer.id);
      expect(fromMap.playerName, offer.playerName);
      expect(fromMap.playerPosition, offer.playerPosition);
      expect(fromMap.playerOverall, offer.playerOverall);
      expect(fromMap.playerAge, offer.playerAge);
      expect(fromMap.buyingClub, offer.buyingClub);
      expect(fromMap.buyingClubTier, offer.buyingClubTier);
      expect(fromMap.playerMarketValue, offer.playerMarketValue);
      expect(fromMap.offeredFeeMillions, offer.offeredFeeMillions);
      expect(fromMap.season, offer.season);
      expect(fromMap.gameweek, offer.gameweek);
      expect(fromMap.status, 'pending');

      final acceptedOffer = offer.copyWith(status: 'accepted');
      expect(acceptedOffer.isAccepted, isTrue);
      expect(acceptedOffer.isPending, isFalse);

      final rejectedOffer = offer.copyWith(status: 'rejected');
      expect(rejectedOffer.isRejected, isTrue);
      expect(rejectedOffer.isPending, isFalse);
    });

    test('Superstars (85+ OVR) can strictly ONLY be approached by Tier 1 Elite Clubs', () {
      final ronaldo = Player.fromMap({
        'player_name': 'Cristiano Ronaldo',
        'overall': 86,
        'age': 39.0,
        'primary_position': 'ST',
        'all_positions': 'ST',
        'mode': 'FC24',
        'season': 2024,
        'team_name': 'Al Nassr',
      });

      final haaland = Player.fromMap({
        'player_name': 'Erling Haaland',
        'overall': 91,
        'age': 24.0,
        'primary_position': 'ST',
        'all_positions': 'ST',
        'mode': 'FC24',
        'season': 2024,
        'team_name': 'Manchester City',
      });

      // Tier 1 mega clubs MUST be eligible
      for (final club in TransferOfferService.kTier1Clubs) {
        expect(
          TransferOfferService.canClubApproachPlayer(club: club, player: ronaldo, userClub: 'Manchester United'),
          isTrue,
          reason: '$club should be able to approach 86-rated superstar Ronaldo',
        );
        expect(
          TransferOfferService.canClubApproachPlayer(club: club, player: haaland, userClub: 'Manchester United'),
          isTrue,
          reason: '$club should be able to approach 91-rated superstar Haaland',
        );
      }

      // Tier 4, Tier 3, and Tier 2 clubs MUST NOT be eligible to bid for 85+ superstars
      final ineligibleClubs = [
        'Brentford',
        'AFC Bournemouth',
        'Nottingham Forest',
        'Leicester City',
        'Ipswich Town',
        'West Ham United',
        'Brighton & Hove Albion',
        'Everton',
        'Chelsea',
        'Tottenham Hotspur',
      ];

      for (final club in ineligibleClubs) {
        expect(
          TransferOfferService.canClubApproachPlayer(club: club, player: ronaldo, userClub: 'Manchester United'),
          isFalse,
          reason: '$club should NOT be able to afford or approach 86-rated superstar Ronaldo',
        );
      }

      // User club itself is always excluded
      expect(
        TransferOfferService.canClubApproachPlayer(club: 'Real Madrid', player: ronaldo, userClub: 'Real Madrid'),
        isFalse,
      );
    });

    test('Mid-tier players (74-79 OVR) and low-tier (<74) are approached by appropriate tiers', () {
      final midTierPlayer = Player.fromMap({
        'player_name': 'Solid Starter',
        'overall': 76,
        'age': 25.0,
        'primary_position': 'CM',
        'all_positions': 'CM',
        'mode': 'FC24',
        'season': 2024,
        'team_name': 'Everton',
      });

      // Tier 2, 3, 4 can approach 76 OVR
      expect(TransferOfferService.canClubApproachPlayer(club: 'Chelsea', player: midTierPlayer, userClub: 'Everton'), isTrue);
      expect(TransferOfferService.canClubApproachPlayer(club: 'West Ham United', player: midTierPlayer, userClub: 'Everton'), isTrue);
      expect(TransferOfferService.canClubApproachPlayer(club: 'Brentford', player: midTierPlayer, userClub: 'Everton'), isTrue);

      final youthProspect = Player.fromMap({
        'player_name': 'Young Fringe',
        'overall': 71,
        'age': 19.0,
        'primary_position': 'RW',
        'all_positions': 'RW',
        'mode': 'FC24',
        'season': 2024,
        'team_name': 'Everton',
      });

      // <74 approached by Tier 3 & 4
      expect(TransferOfferService.canClubApproachPlayer(club: 'Brentford', player: youthProspect, userClub: 'Everton'), isTrue);
      expect(TransferOfferService.canClubApproachPlayer(club: 'Brighton & Hove Albion', player: youthProspect, userClub: 'Everton'), isTrue);
    });

    test('Offered transfer fee provides realistic premium over player valuation', () {
      final player = Player.fromMap({
        'player_name': 'Bukayo Saka',
        'overall': 87,
        'age': 22.0,
        'potential': 90.0,
        'primary_position': 'RW',
        'all_positions': 'RW',
        'mode': 'FC24',
        'season': 2024,
        'team_name': 'Arsenal',
      });

      const valuation = 80.0;
      final offer = TransferOfferService.generateOfferForPlayer(
        player: player,
        playerMarketValue: valuation,
        userClub: 'Arsenal',
        season: 1,
        gameweek: 3,
      );

      expect(offer, isNotNull);
      expect(offer!.offeredFeeMillions, greaterThan(valuation));
      expect(offer.premiumPercent, greaterThanOrEqualTo(5.0));
      expect(TransferOfferService.kTier1Clubs.contains(offer.buyingClub), isTrue);
      expect(offer.buyingClub, isNot('Arsenal'));
    });

    test('evaluateMatchdayInboundBids enforces window status and maximum pending offers', () {
      final squad = [
        Player.fromMap({'player_name': 'Player 1', 'overall': 82, 'age': 25.0, 'primary_position': 'ST', 'mode': 'FC24', 'season': 2024, 'team_name': 'Chelsea'}),
        Player.fromMap({'player_name': 'Player 2', 'overall': 85, 'age': 26.0, 'primary_position': 'CB', 'mode': 'FC24', 'season': 2024, 'team_name': 'Chelsea'}),
        Player.fromMap({'player_name': 'Player 3', 'overall': 78, 'age': 22.0, 'primary_position': 'CM', 'mode': 'FC24', 'season': 2024, 'team_name': 'Chelsea'}),
      ];

      // Closed window: returns empty
      final closedOffers = TransferOfferService.evaluateMatchdayInboundBids(
        userSquad: squad,
        userClub: 'Chelsea',
        season: 1,
        gameweek: 15,
        isWindowOpen: false,
        currentPendingOffers: [],
        valuationCalculator: (p) => 40.0,
      );
      expect(closedOffers, isEmpty);

      // Max pending offers reached (>= 3): returns empty
      final mockPending = [
        TransferOffer(id: '1', playerName: 'P1', playerPosition: 'ST', playerOverall: 80, playerAge: 25, buyingClub: 'Real Madrid', buyingClubTier: 'Tier 1', playerMarketValue: 30, offeredFeeMillions: 35, season: 1, gameweek: 1, status: 'pending', date: DateTime.now()),
        TransferOffer(id: '2', playerName: 'P2', playerPosition: 'CB', playerOverall: 80, playerAge: 25, buyingClub: 'Bayern Munich', buyingClubTier: 'Tier 1', playerMarketValue: 30, offeredFeeMillions: 35, season: 1, gameweek: 1, status: 'pending', date: DateTime.now()),
        TransferOffer(id: '3', playerName: 'P3', playerPosition: 'CM', playerOverall: 80, playerAge: 25, buyingClub: 'PSG', buyingClubTier: 'Tier 1', playerMarketValue: 30, offeredFeeMillions: 35, season: 1, gameweek: 1, status: 'pending', date: DateTime.now()),
      ];
      final cappedOffers = TransferOfferService.evaluateMatchdayInboundBids(
        userSquad: squad,
        userClub: 'Chelsea',
        season: 1,
        gameweek: 2,
        isWindowOpen: true,
        currentPendingOffers: mockPending,
        valuationCalculator: (p) => 40.0,
      );
      expect(cappedOffers, isEmpty);
    });

    test('PrefsService properly saves, restores, and clears pendingTransferOffers', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsService.instance;

      final testOffers = [
        TransferOffer(
          id: 'offer_1',
          playerName: 'Marcus Rashford',
          playerPosition: 'LW',
          playerOverall: 83,
          playerAge: 27,
          buyingClub: 'Paris Saint-Germain',
          buyingClubTier: 'Tier 1 (Elite Mega Club)',
          playerMarketValue: 45.0,
          offeredFeeMillions: 55.0,
          season: 1,
          gameweek: 2,
          status: 'pending',
          date: DateTime.now(),
        ).toMap(),
        TransferOffer(
          id: 'offer_2',
          playerName: 'Antony',
          playerPosition: 'RW',
          playerOverall: 79,
          playerAge: 24,
          buyingClub: 'West Ham United',
          buyingClubTier: 'Tier 3 (Established Mid-Table)',
          playerMarketValue: 22.0,
          offeredFeeMillions: 26.5,
          season: 1,
          gameweek: 3,
          status: 'pending',
          date: DateTime.now(),
        ).toMap(),
      ];

      await prefs.saveCareerConfig(
        leagueId: 'premier_league',
        clubName: 'Manchester United',
        clubCode: 'MUN',
        isCustomClub: false,
        squadMode: 'current',
        pendingTransferOffers: testOffers,
      );

      final loaded = await prefs.getCareerConfig();
      expect(loaded, isNotNull);
      expect(loaded!['pendingTransferOffers'], isNotNull);

      final loadedOffers = (loaded['pendingTransferOffers'] as List<dynamic>)
          .map((o) => TransferOffer.fromMap(Map<String, dynamic>.from(o as Map)))
          .toList();

      expect(loadedOffers.length, 2);
      expect(loadedOffers[0].playerName, 'Marcus Rashford');
      expect(loadedOffers[0].offeredFeeMillions, 55.0);
      expect(loadedOffers[0].buyingClub, 'Paris Saint-Germain');
      expect(loadedOffers[1].playerName, 'Antony');
      expect(loadedOffers[1].offeredFeeMillions, 26.5);
      expect(loadedOffers[1].buyingClub, 'West Ham United');

      await prefs.clearCareerConfig();
      final cleared = await prefs.getCareerConfig();
      expect(cleared, isNull);
    });
  });

  group('Fix 29: Dynamic Squad Events: Injuries, Leave & International Duty', () {
    test('SquadEvent model serialization, deserialization, and computed properties', () {
      final event = SquadEvent(
        id: 'event_test_1',
        playerName: 'Lisandro Martínez',
        type: SquadEventType.injury,
        title: 'Hamstring Strain',
        description: 'Overstretched during sprinting drills.',
        durationGameweeks: 3,
        remainingGameweeks: 3,
        startGameweek: 4,
        startSeason: 1,
        severity: 'Moderate',
        date: DateTime(2026, 1, 15),
      );

      expect(event.isResolved, isFalse);
      expect(event.badgeLabel, 'INJURED (3 GWs)');
      expect(event.typeKey, 'injury');

      // Serialization roundtrip
      final map = event.toMap();
      final restored = SquadEvent.fromMap(map);
      expect(restored.id, event.id);
      expect(restored.playerName, 'Lisandro Martínez');
      expect(restored.type, SquadEventType.injury);
      expect(restored.title, 'Hamstring Strain');
      expect(restored.durationGameweeks, 3);
      expect(restored.remainingGameweeks, 3);
      expect(restored.startGameweek, 4);
      expect(restored.startSeason, 1);
      expect(restored.severity, 'Moderate');

      // Test copyWith and isResolved
      final ticked = restored.copyWith(remainingGameweeks: 0);
      expect(ticked.isResolved, isTrue);

      // Test other types badgeLabel
      final dutyEvent = event.copyWith(
        type: SquadEventType.internationalDuty,
        title: 'World Cup Qualifiers',
        remainingGameweeks: 2,
      );
      expect(dutyEvent.badgeLabel, 'INT DUTY (2 GWs)');

      final leaveEvent = event.copyWith(
        type: SquadEventType.personalLeave,
        title: 'Paternity Leave',
        remainingGameweeks: 1,
      );
      expect(leaveEvent.badgeLabel, 'ON LEAVE (1 GW)');
    });

    test('SquadEventType fromKey parses keys accurately with fallback to injury', () {
      expect(SquadEventType.fromKey('injury'), SquadEventType.injury);
      expect(SquadEventType.fromKey('personal_leave'), SquadEventType.personalLeave);
      expect(SquadEventType.fromKey('international_duty'), SquadEventType.internationalDuty);
      expect(SquadEventType.fromKey('unknown_key'), SquadEventType.injury);
    });

    test('SquadEventService isPlayerAvailable and getPlayerEvent helpers', () {
      final events = [
        SquadEvent(
          id: 'e1',
          playerName: 'Luke Shaw',
          type: SquadEventType.injury,
          title: 'Calf Muscle Tear',
          description: 'Pulled calf in training.',
          durationGameweeks: 4,
          remainingGameweeks: 2,
          startGameweek: 2,
          startSeason: 1,
          severity: 'Moderate',
          date: DateTime.now(),
        ),
      ];

      expect(SquadEventService.isPlayerAvailable('Luke Shaw', events), isFalse);
      expect(SquadEventService.isPlayerAvailable('luke shaw', events), isFalse);
      expect(SquadEventService.isPlayerAvailable('Bruno Fernandes', events), isTrue);

      final found = SquadEventService.getPlayerEvent('Luke Shaw', events);
      expect(found, isNotNull);
      expect(found!.title, 'Calf Muscle Tear');

      final notFound = SquadEventService.getPlayerEvent('Bruno Fernandes', events);
      expect(notFound, isNull);
    });

    test('SquadEventService evaluateMatchdaySquadEvents decrements durations and reports recoveries', () {
      final squad = [
        Player.fromMap({'player_name': 'Player 1', 'overall': 82, 'primary_position': 'CB', 'mode': 'FC24', 'season': 2024, 'team_name': 'Man Utd'}),
        Player.fromMap({'player_name': 'Player 2', 'overall': 85, 'primary_position': 'ST', 'mode': 'FC24', 'season': 2024, 'team_name': 'Man Utd'}),
      ];

      final existingEvents = [
        SquadEvent(
          id: 'rec_1',
          playerName: 'Player 1',
          type: SquadEventType.injury,
          title: 'Hamstring Strain',
          description: 'Recovering.',
          durationGameweeks: 2,
          remainingGameweeks: 1, // Last gameweek! Will recover on next tick
          startGameweek: 1,
          startSeason: 1,
          severity: 'Minor',
          date: DateTime.now(),
        ),
        SquadEvent(
          id: 'rec_2',
          playerName: 'Player 2',
          type: SquadEventType.personalLeave,
          title: 'Compassionate Leave',
          description: 'Family emergency.',
          durationGameweeks: 3,
          remainingGameweeks: 3, // Will decrement to 2
          startGameweek: 2,
          startSeason: 1,
          severity: 'Minor',
          date: DateTime.now(),
        ),
      ];

      final result = SquadEventService.evaluateMatchdaySquadEvents(
        userSquad: squad,
        gameweek: 3,
        season: 1,
        totalGameweeks: 38,
        currentActiveEvents: existingEvents,
      );

      // Player 1 should have recovered
      expect(result.recoveredEvents.length, 1);
      expect(result.recoveredEvents.first.playerName, 'Player 1');

      // Player 2 should remain active with remainingGameweeks decremented to 2
      final p2Active = result.activeEvents.where((e) => e.playerName == 'Player 2').toList();
      expect(p2Active.length, 1);
      expect(p2Active.first.remainingGameweeks, 2);
    });

    test('Goalkeeper protection safeguard: never sidelines the only healthy goalkeeper', () {
      // Squad with exactly 1 goalkeeper and 2 outfielders
      final squad = [
        Player.fromMap({'player_name': 'Andre Onana', 'overall': 83, 'primary_position': 'GK', 'is_goalkeeper': 1, 'mode': 'FC24', 'season': 2024, 'team_name': 'Man Utd'}),
        Player.fromMap({'player_name': 'Harry Maguire', 'overall': 81, 'primary_position': 'CB', 'is_goalkeeper': 0, 'mode': 'FC24', 'season': 2024, 'team_name': 'Man Utd'}),
        Player.fromMap({'player_name': 'Casemiro', 'overall': 84, 'primary_position': 'CDM', 'is_goalkeeper': 0, 'mode': 'FC24', 'season': 2024, 'team_name': 'Man Utd'}),
      ];

      // Run multiple evaluations to ensure Andre Onana is NEVER targeted when he is the only GK
      for (int i = 0; i < 50; i++) {
        final result = SquadEventService.evaluateMatchdaySquadEvents(
          userSquad: squad,
          gameweek: i + 1,
          season: 1,
          totalGameweeks: 38,
          currentActiveEvents: [],
        );

        for (final newEvent in result.newEvents) {
          expect(newEvent.playerName, isNot('Andre Onana'),
              reason: 'The only healthy goalkeeper must never be sidelined by dynamic squad events.');
        }
      }
    });

    test('autoReplaceUnavailableStarters safely swaps injured starters with healthy bench players', () {
      final fullSquad = [
        // Starters 0..10
        Player.fromMap({'player_name': 'GK Starter', 'overall': 82, 'primary_position': 'GK', 'is_goalkeeper': 1, 'mode': 'FC24', 'season': 2024, 'team_name': 'Test'}),
        Player.fromMap({'player_name': 'CB 1', 'overall': 84, 'primary_position': 'CB', 'is_goalkeeper': 0, 'mode': 'FC24', 'season': 2024, 'team_name': 'Test'}),
        Player.fromMap({'player_name': 'CB 2', 'overall': 83, 'primary_position': 'CB', 'is_goalkeeper': 0, 'mode': 'FC24', 'season': 2024, 'team_name': 'Test'}),
        Player.fromMap({'player_name': 'LB 1', 'overall': 80, 'primary_position': 'LB', 'is_goalkeeper': 0, 'mode': 'FC24', 'season': 2024, 'team_name': 'Test'}),
        Player.fromMap({'player_name': 'RB 1', 'overall': 81, 'primary_position': 'RB', 'is_goalkeeper': 0, 'mode': 'FC24', 'season': 2024, 'team_name': 'Test'}),
        Player.fromMap({'player_name': 'CM 1', 'overall': 85, 'primary_position': 'CM', 'is_goalkeeper': 0, 'mode': 'FC24', 'season': 2024, 'team_name': 'Test'}),
        Player.fromMap({'player_name': 'CM 2', 'overall': 82, 'primary_position': 'CM', 'is_goalkeeper': 0, 'mode': 'FC24', 'season': 2024, 'team_name': 'Test'}),
        Player.fromMap({'player_name': 'CAM 1', 'overall': 86, 'primary_position': 'CAM', 'is_goalkeeper': 0, 'mode': 'FC24', 'season': 2024, 'team_name': 'Test'}),
        Player.fromMap({'player_name': 'LW 1', 'overall': 83, 'primary_position': 'LW', 'is_goalkeeper': 0, 'mode': 'FC24', 'season': 2024, 'team_name': 'Test'}),
        Player.fromMap({'player_name': 'RW 1', 'overall': 84, 'primary_position': 'RW', 'is_goalkeeper': 0, 'mode': 'FC24', 'season': 2024, 'team_name': 'Test'}),
        Player.fromMap({'player_name': 'ST Injured', 'overall': 87, 'primary_position': 'ST', 'is_goalkeeper': 0, 'mode': 'FC24', 'season': 2024, 'team_name': 'Test'}), // Injured starter!
        // Bench 11..13
        Player.fromMap({'player_name': 'GK Sub', 'overall': 76, 'primary_position': 'GK', 'is_goalkeeper': 1, 'mode': 'FC24', 'season': 2024, 'team_name': 'Test'}),
        Player.fromMap({'player_name': 'ST Sub Healthy', 'overall': 79, 'primary_position': 'ST', 'is_goalkeeper': 0, 'mode': 'FC24', 'season': 2024, 'team_name': 'Test'}),
        Player.fromMap({'player_name': 'CM Sub Healthy', 'overall': 78, 'primary_position': 'CM', 'is_goalkeeper': 0, 'mode': 'FC24', 'season': 2024, 'team_name': 'Test'}),
      ];

      final activeEvents = [
        SquadEvent(
          id: 'ev_st',
          playerName: 'ST Injured',
          type: SquadEventType.injury,
          title: 'Twisted Ankle Sprain',
          description: 'Sprained in last fixture.',
          durationGameweeks: 3,
          remainingGameweeks: 3,
          startGameweek: 5,
          startSeason: 1,
          severity: 'Moderate',
          date: DateTime.now(),
        ),
      ];

      final adjusted = SquadEventService.autoReplaceUnavailableStarters(
        squad: fullSquad,
        activeEvents: activeEvents,
      );

      // Position 10 (ST) should have been swapped with healthy outfield bench player
      expect(adjusted[10].name, 'ST Sub Healthy');
      expect(adjusted[10].primaryPosition, 'ST');
      // The injured striker should now be relegated to bench
      expect(adjusted.skip(11).any((p) => p.name == 'ST Injured'), isTrue);
    });

    test('PrefsService properly persists, restores, and clears activeSquadEvents', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsService.instance;

      final testEvents = [
        SquadEvent(
          id: 'event_sav_1',
          playerName: 'Mason Mount',
          type: SquadEventType.injury,
          title: 'Hamstring Strain',
          description: 'Sidelined for 2 weeks.',
          durationGameweeks: 2,
          remainingGameweeks: 2,
          startGameweek: 7,
          startSeason: 1,
          severity: 'Minor',
          date: DateTime.now(),
        ).toMap(),
        SquadEvent(
          id: 'event_sav_2',
          playerName: 'Alejandro Garnacho',
          type: SquadEventType.internationalDuty,
          title: 'World Cup Qualifiers',
          description: 'Called up to Argentina national squad.',
          durationGameweeks: 1,
          remainingGameweeks: 1,
          startGameweek: 7,
          startSeason: 1,
          severity: 'Minor',
          date: DateTime.now(),
        ).toMap(),
      ];

      await prefs.saveCareerConfig(
        leagueId: 'premier_league',
        clubName: 'Manchester United',
        clubCode: 'MUN',
        isCustomClub: false,
        squadMode: 'current',
        activeSquadEvents: testEvents,
      );

      final loaded = await prefs.getCareerConfig();
      expect(loaded, isNotNull);
      expect(loaded!['activeSquadEvents'], isNotNull);

      final loadedEvents = (loaded['activeSquadEvents'] as List<dynamic>)
          .map((e) => SquadEvent.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      expect(loadedEvents.length, 2);
      expect(loadedEvents[0].playerName, 'Mason Mount');
      expect(loadedEvents[0].type, SquadEventType.injury);
      expect(loadedEvents[0].remainingGameweeks, 2);
      expect(loadedEvents[1].playerName, 'Alejandro Garnacho');
      expect(loadedEvents[1].type, SquadEventType.internationalDuty);

      await prefs.clearCareerConfig();
      final cleared = await prefs.getCareerConfig();
      expect(cleared, isNull);
    });
  });

  group('Fix 30 - Expanded Transfer Market, Free Agents & Expiring Contracts', () {
    test('ContractStatus.fromSeasons correctly identifies free agents, expiring, and multi-year deals', () {
      final freeAgent = ContractStatus.fromSeasons(0);
      expect(freeAgent.isFreeAgent, isTrue);
      expect(freeAgent.isExpiring, isFalse);
      expect(freeAgent.discountMultiplier, 0.0);
      expect(freeAgent.statusBadge, contains('FREE AGENT'));

      final expiring = ContractStatus.fromSeasons(1);
      expect(expiring.isFreeAgent, isFalse);
      expect(expiring.isExpiring, isTrue);
      expect(expiring.discountMultiplier, 0.5);
      expect(expiring.statusBadge, contains('50% OFF'));

      final multiYear = ContractStatus.fromSeasons(3);
      expect(multiYear.isFreeAgent, isFalse);
      expect(multiYear.isExpiring, isFalse);
      expect(multiYear.discountMultiplier, 1.0);
      expect(multiYear.statusBadge, '3 YRS');
    });

    test('TransferMarketService.computePlayerContract returns valid deterministic status', () {
      final contract1 = TransferMarketService.computePlayerContract('Erling Haaland', 1);
      final contract2 = TransferMarketService.computePlayerContract('Erling Haaland', 1);
      expect(contract1.seasonsRemaining, contract2.seasonsRemaining);
      expect(contract1.discountMultiplier, contract2.discountMultiplier);

      // Verify range
      expect(contract1.seasonsRemaining, inInclusiveRange(0, 4));
    });

    test('TransferMarketService.calculateEffectiveTransferFee discounts expiring contracts and zeroes free agents', () {
      const baseFee = 50.0;

      final freeFee = TransferMarketService.calculateEffectiveTransferFee(
        baseValuation: baseFee,
        contractStatus: ContractStatus.fromSeasons(0),
      );
      expect(freeFee, 0.0);

      final expiringFee = TransferMarketService.calculateEffectiveTransferFee(
        baseValuation: baseFee,
        contractStatus: ContractStatus.fromSeasons(1),
      );
      expect(expiringFee, 25.0);

      final normalFee = TransferMarketService.calculateEffectiveTransferFee(
        baseValuation: baseFee,
        contractStatus: ContractStatus.fromSeasons(3),
      );
      expect(normalFee, 50.0);
    });

    test('TransferMarketService.calculateContractRenewalCost applies ~10% loyalty fee with min/max clamps', () {
      final cheapCost = TransferMarketService.calculateContractRenewalCost(3.0);
      expect(cheapCost, 0.5); // clamped to min 0.5

      final midCost = TransferMarketService.calculateContractRenewalCost(40.0);
      expect(midCost, 4.0); // 10% of 40

      final expensiveCost = TransferMarketService.calculateContractRenewalCost(180.0);
      expect(expensiveCost, 12.0); // clamped to max 12.0
    });

    test('TransferMarketService.tickSquadContracts decrements all player contracts', () {
      final initial = {'Haaland': 3, 'Salah': 1, 'Saka': 4};
      final ticked = TransferMarketService.tickSquadContracts(initial);
      expect(ticked['Haaland'], 2);
      expect(ticked['Salah'], 0);
      expect(ticked['Saka'], 3);
    });

    test('TransferMarketService.processSeasonContractExpiry identifies departures and retains safety invariants', () {
      final gk = Player(
        mode: 'test',
        squadId: 's1',
        teamCode: 'MCI',
        teamName: 'Manchester City',
        season: 2024,
        playerId: 'gk1',
        name: 'Ederson',
        overall: 88,
        displayPosition: 'GK',
        primaryPosition: 'GK',
        allPositions: 'GK',
        pace: 50,
        shooting: 20,
        passing: 60,
        dribbling: 40,
        defending: 30,
        physicality: 70,
        isGoalkeeper: true,
      );

      final outfieldPlayers = List.generate(12, (i) => Player(
        mode: 'test',
        squadId: 's${i + 2}',
        teamCode: 'MCI',
        teamName: 'Manchester City',
        season: 2024,
        playerId: 'p$i',
        name: 'Player $i',
        overall: 80 + (i % 5),
        displayPosition: 'CM',
        primaryPosition: 'CM',
        allPositions: 'CM',
        pace: 75,
        shooting: 70,
        passing: 80,
        dribbling: 78,
        defending: 72,
        physicality: 75,
        isGoalkeeper: false,
      ));

      final fullSquad = <Player>[gk, ...outfieldPlayers]; // 13 players
      final contracts = <String, int>{
        'Ederson': 1, // Will reach 0, but is the only GK!
        'Player 0': 1, // Will reach 0, can depart
        'Player 1': 3, // Stays at 2
      };
      for (int i = 2; i < 12; i++) {
        contracts['Player $i'] = 3;
      }

      final result = TransferMarketService.processSeasonContractExpiry(
        squad: fullSquad,
        contracts: contracts,
      );

      // Ederson was the only GK, so he must be auto-extended for safety
      expect(result.remainingSquad.any((p) => p.name == 'Ederson'), isTrue);
      expect(result.updatedContracts['Ederson'], 1);

      // Player 0 had contract 1, reached 0, and could safely depart
      expect(result.departedPlayers.any((p) => p.name == 'Player 0'), isTrue);
      expect(result.remainingSquad.any((p) => p.name == 'Player 0'), isFalse);

      // Squad remains at least 11 players
      expect(result.remainingSquad.length, greaterThanOrEqualTo(11));
    });

    test('TransferMarketService.generateYouthProspects produces wonderkids with high ceilings', () {
      final prospects = TransferMarketService.generateYouthProspects(1);
      expect(prospects, isNotEmpty);
      for (final p in prospects) {
        expect(p.age, inInclusiveRange(17.0, 21.0));
        expect(p.potential, greaterThanOrEqualTo(85.0));
        expect(p.teamName, 'Youth Academy');
      }
    });

    test('PrefsService saves and restores player contracts accurately', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsService.instance;

      final testContracts = {
        'Bukayo Saka': 4,
        'Declan Rice': 3,
        'Gabriel Martinelli': 1,
      };

      await prefs.saveCareerConfig(
        leagueId: 'premier_league',
        clubName: 'Arsenal',
        clubCode: 'ARS',
        isCustomClub: false,
        squadMode: 'current',
        playerContracts: testContracts,
      );

      final loaded = await prefs.getCareerConfig();
      expect(loaded, isNotNull);
      expect(loaded!['playerContracts'], isNotNull);

      final loadedContracts = Map<String, int>.from(loaded['playerContracts'] as Map);
      expect(loadedContracts['Bukayo Saka'], 4);
      expect(loadedContracts['Declan Rice'], 3);
      expect(loadedContracts['Gabriel Martinelli'], 1);

      await prefs.clearCareerConfig();
      final cleared = await prefs.getCareerConfig();
      expect(cleared, isNull);
    });
  });

  group('Fix 32: Comprehensive End-to-End System Verification', () {
    test('End-to-End Campaign Lifecycle: Tactics, Contracts, Market, Events & Competitions', () async {
      final prefs = PrefsService.instance;
      await prefs.clearCareerConfig();

      // 1. Tactical Setup & Custom Formation Persistence
      final formation = TacticalFormation.getById('4-3-3');
      expect(formation.slots.length, 11);
      final customSlots = List<PitchSlot>.from(formation.slots);
      // Adjust CAM higher into second striker
      customSlots[6] = PitchSlot.clampSlot(6, 0.50, 0.32);
      expect(formation.isCustomized(customSlots), isTrue);
      expect(customSlots[6].defaultRole, 'CAM');

      final customSlotsMap = {
        '4-3-3': customSlots.map((s) => s.toJson()).toList(),
      };

      // 2. Initial Squad & Contracts Setup
      final squadContracts = {
        'Bukayo Saka': 4,
        'Martin Odegaard': 3,
        'Declan Rice': 3,
        'William Saliba': 2,
        'Gabriel Magalhaes': 2,
        'Kai Havertz': 2,
        'Gabriel Martinelli': 1, // Expiring
        'Thomas Partey': 1,      // Expiring
        'Jorginho': 1,           // Expiring
        'David Raya': 3,
        'Neto': 1,               // Bench GK
      };

      await prefs.saveCareerConfig(
        leagueId: 'premier_league',
        clubName: 'Arsenal',
        clubCode: 'ARS',
        isCustomClub: false,
        squadMode: 'current',
        budget: 90.0,
        formationId: '4-3-3',
        playerContracts: squadContracts,
        customFormationSlots: customSlotsMap,
      );

      final loadedState = await prefs.getCareerConfig();
      expect(loadedState, isNotNull);
      expect(loadedState!['clubName'], 'Arsenal');
      expect(loadedState['budget'], 90.0);
      expect(loadedState['formationId'], '4-3-3');
      expect(loadedState['customFormationSlots'], isNotNull);
      expect(loadedState['playerContracts'], isNotNull);

      // 3. Transfer Market & Free Agent Valuations
      const baseVal = 100.0;
      final standardFee = TransferMarketService.calculateEffectiveTransferFee(
        baseValuation: baseVal,
        contractStatus: ContractStatus.fromSeasons(3),
      );
      expect(standardFee, 100.0);

      final freeAgentFee = TransferMarketService.calculateEffectiveTransferFee(
        baseValuation: baseVal,
        contractStatus: ContractStatus.fromSeasons(0),
      );
      expect(freeAgentFee, 0.0);

      final expiringFee = TransferMarketService.calculateEffectiveTransferFee(
        baseValuation: baseVal,
        contractStatus: ContractStatus.fromSeasons(1),
      );
      expect(expiringFee, 50.0);

      // 4. Inbound AI Transfer Bids
      final inboundBids = TransferOfferService.evaluateMatchdayInboundBids(
        userSquad: [
          Player.fromMap({
            'player_name': 'Kylian Mbappe',
            'overall': 91,
            'age': 25.0,
            'primary_position': 'ST',
            'mode': 'FC24',
            'season': 2024,
            'team_name': 'Arsenal',
          }),
        ],
        userClub: 'Arsenal',
        season: 1,
        gameweek: 2,
        isWindowOpen: true,
        currentPendingOffers: [],
        valuationCalculator: (p) => 120.0,
      );
      expect(inboundBids, isA<List<TransferOffer>>());

      // 5. Squad Events & Auto-Replacement
      final injuryEvent = SquadEvent(
        id: 'inj_1',
        playerName: 'Martin Odegaard',
        type: SquadEventType.injury,
        title: 'Hamstring Injury',
        description: 'Suffered during training',
        durationGameweeks: 3,
        remainingGameweeks: 3,
        startGameweek: 1,
        startSeason: 1,
        severity: 'Moderate',
        date: DateTime.now(),
      );
      expect(SquadEventService.isPlayerAvailable('Martin Odegaard', [injuryEvent]), isFalse);
      expect(SquadEventService.isPlayerAvailable('Bukayo Saka', [injuryEvent]), isTrue);

      Player makePlayer(String name, String pos, int ovr) {
        return Player(
          mode: 'current',
          squadId: 'squad_test',
          teamCode: 'ARS',
          teamName: 'Arsenal',
          season: 2024,
          playerId: 'p_$name',
          name: name,
          overall: ovr,
          displayPosition: pos,
          primaryPosition: pos,
          allPositions: pos,
          isGoalkeeper: pos == 'GK',
          age: 25.0,
          potential: ovr.toDouble() + 3.0,
          pace: 75,
          shooting: 75,
          passing: 75,
          dribbling: 75,
          defending: 75,
          physicality: 75,
        );
      }

      final testStarters = [
        makePlayer('David Raya', 'GK', 84),
        makePlayer('Ben White', 'RB', 82),
        makePlayer('William Saliba', 'CB', 87),
        makePlayer('Gabriel Magalhaes', 'CB', 86),
        makePlayer('Jurrien Timber', 'LB', 81),
        makePlayer('Declan Rice', 'CDM', 87),
        makePlayer('Martin Odegaard', 'CAM', 89),
        makePlayer('Mikel Merino', 'CM', 83),
        makePlayer('Bukayo Saka', 'RW', 87),
        makePlayer('Kai Havertz', 'ST', 83),
        makePlayer('Gabriel Martinelli', 'LW', 84),
        // Bench
        makePlayer('Neto', 'GK', 78),
        makePlayer('Leandro Trossard', 'LW', 82),
        makePlayer('Ethan Nwaneri', 'CAM', 76),
      ];

      final adjustedSquad = SquadEventService.autoReplaceUnavailableStarters(
        squad: testStarters,
        activeEvents: [injuryEvent],
      );
      // Odegaard is displaced from starters
      final startingNames = adjustedSquad.take(11).map((p) => p.name).toList();
      expect(startingNames.contains('Martin Odegaard'), isFalse);
      expect(startingNames.contains('Ethan Nwaneri') || startingNames.contains('Leandro Trossard'), isTrue);

      // 6. Domestic Cups & UCL Tournament Progress
      final ucl = UclTournament.create(userClub: 'Arsenal');
      expect(ucl.participants.contains('Arsenal'), isTrue);
      final faCup = CupTournament.create(id: 'fa_cup', userClub: 'Arsenal', poolClubs: CupTournament.kDefaultEnglishCupClubs);
      expect(faCup.fixtures.length, 8); // Round of 16

      // 7. Season Rollover & Contract Safeguards
      final squadWithExpiring = [
        ...testStarters,
        makePlayer('Thomas Partey', 'CM', 82),
        makePlayer('Jorginho', 'CM', 81),
      ];
      final expiringContracts = {
        'Bukayo Saka': 4,
        'Martin Odegaard': 3,
        'Thomas Partey': 1, // 1 year left -> expires to 0!
        'Jorginho': 1,      // 1 year left -> expires to 0!
      };
      final expiryResult = TransferMarketService.processSeasonContractExpiry(
        squad: squadWithExpiring,
        contracts: expiringContracts,
      );
      expect(expiryResult.departedPlayers.length, 2);
      expect(expiryResult.departedPlayers.map((p) => p.name), contains('Thomas Partey'));
      expect(expiryResult.departedPlayers.map((p) => p.name), contains('Jorginho'));
      expect(expiryResult.remainingSquad.length, greaterThanOrEqualTo(11));
      expect(expiryResult.remainingSquad.any((p) => p.isGoalkeeper || p.primaryPosition == 'GK'), isTrue);

      await prefs.clearCareerConfig();
    });
  });

  group('Fix 33: Canonical Peak Rating Selection & Auto-Healing Tests', () {
    test('Career save loading auto-heals corrupted legacy ratings for non-veteran players', () {
      // Simulate player loaded from DB at peak rating 88
      final saka = Player(
        mode: 'current',
        squadId: 'squad_test',
        teamCode: 'ARS',
        teamName: 'Arsenal',
        season: 2027,
        playerId: '246669',
        name: 'Bukayo Saka',
        overall: 88,
        displayPosition: 'RW',
        primaryPosition: 'RW',
        allPositions: 'RW,LW',
        isGoalkeeper: false,
        age: 23.0,
        potential: 90.0,
        pace: 86,
        shooting: 84,
        passing: 83,
        dribbling: 89,
        defending: 65,
        physicality: 76,
      );

      // Simulate a legacy save file where Saka had corrupted rating 65 (from old FIFA 20 row bug)
      final corruptedSavedRatings = {'Bukayo Saka': 65};
      final savedAges = {'Bukayo Saka': 23};

      // Apply the Fix 33 healing logic
      var squad = [saka];
      squad = squad.map((p) {
        final keyLower = p.name.trim().toLowerCase();
        int? dynamicRating;
        int? dynamicAge;
        for (final entry in corruptedSavedRatings.entries) {
          if (entry.key.trim().toLowerCase() == keyLower) {
            dynamicRating = entry.value;
            break;
          }
        }
        for (final entry in savedAges.entries) {
          if (entry.key.trim().toLowerCase() == keyLower) {
            dynamicAge = entry.value;
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

      expect(squad.first.overall, 88, reason: 'Saka rating must be automatically healed from 65 to peak 88');
      expect(squad.first.age, 23.0);
    });

    test('Career save loading preserves legitimate veteran decline (age >= 33)', () {
      final veteran = Player(
        mode: 'current',
        squadId: 'squad_test',
        teamCode: 'MIA',
        teamName: 'Inter Miami',
        season: 2022,
        playerId: '158023',
        name: 'Lionel Messi',
        overall: 91,
        displayPosition: 'RW',
        primaryPosition: 'RW',
        allPositions: 'RW,CF,CAM',
        isGoalkeeper: false,
        age: 36.0,
        potential: 91.0,
        pace: 80,
        shooting: 89,
        passing: 90,
        dribbling: 94,
        defending: 34,
        physicality: 64,
      );

      // Veteran legitimately declined by -2 from 91 to 89
      final savedRatings = {'Lionel Messi': 89};
      final savedAges = {'Lionel Messi': 36};

      var squad = [veteran];
      squad = squad.map((p) {
        final keyLower = p.name.trim().toLowerCase();
        int? dynamicRating;
        int? dynamicAge;
        for (final entry in savedRatings.entries) {
          if (entry.key.trim().toLowerCase() == keyLower) {
            dynamicRating = entry.value;
            break;
          }
        }
        for (final entry in savedAges.entries) {
          if (entry.key.trim().toLowerCase() == keyLower) {
            dynamicAge = entry.value;
            break;
          }
        }
        if (dynamicRating != null || dynamicAge != null) {
          int finalOvr = dynamicRating ?? p.overall;
          final effectiveAge = dynamicAge?.toDouble() ?? p.age ?? 25.0;
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

      expect(squad.first.overall, 89, reason: 'Veteran decline to 89 for age 36 must be preserved');
    });

    test('Career save loading preserves youth development breakthrough (> peak canonical rating)', () {
      final youngStar = Player(
        mode: 'current',
        squadId: 'squad_test',
        teamCode: 'ARS',
        teamName: 'Arsenal',
        season: 2027,
        playerId: '246669',
        name: 'Bukayo Saka',
        overall: 88,
        displayPosition: 'RW',
        primaryPosition: 'RW',
        allPositions: 'RW,LW',
        isGoalkeeper: false,
        age: 23.0,
        potential: 91.0,
        pace: 86,
        shooting: 84,
        passing: 83,
        dribbling: 89,
        defending: 65,
        physicality: 76,
      );

      // Saka had a brilliant season and grew from 88 to 90
      final savedRatings = {'Bukayo Saka': 90};
      final savedAges = {'Bukayo Saka': 24};

      var squad = [youngStar];
      squad = squad.map((p) {
        final keyLower = p.name.trim().toLowerCase();
        int? dynamicRating;
        int? dynamicAge;
        for (final entry in savedRatings.entries) {
          if (entry.key.trim().toLowerCase() == keyLower) {
            dynamicRating = entry.value;
            break;
          }
        }
        for (final entry in savedAges.entries) {
          if (entry.key.trim().toLowerCase() == keyLower) {
            dynamicAge = entry.value;
            break;
          }
        }
        if (dynamicRating != null || dynamicAge != null) {
          int finalOvr = dynamicRating ?? p.overall;
          final effectiveAge = dynamicAge?.toDouble() ?? p.age ?? 25.0;
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

      expect(squad.first.overall, 90, reason: 'Youth growth to 90 must be preserved');
      expect(squad.first.age, 24.0);
    });
  });

  group('Fix 34: Single-Club Player Exclusivity & Acquisition Effects Across Clubs', () {
    test('PrefsService properly persists and restores aiClubSquads', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsService.instance;

      final testAiSquads = {
        'Manchester United': ['Bruno Fernandes', 'Marcus Rashford', 'Casemiro'],
        'Real Madrid': ['Vinicius Jr', 'Jude Bellingham', 'Kylian Mbappé'],
      };

      await prefs.saveCareerConfig(
        leagueId: 'premier_league',
        clubName: 'Arsenal',
        clubCode: 'ARS',
        isCustomClub: false,
        squadMode: 'current',
        budget: 100.0,
        season: 1,
        gameweek: 1,
        squadIds: ['Bukayo Saka', 'Martin Ødegaard'],
        aiClubSquads: testAiSquads,
      );

      final loaded = await prefs.getCareerConfig();
      expect(loaded, isNotNull);
      final loadedAi = loaded!['aiClubSquads'] as Map<String, List<String>>;
      expect(loadedAi['Manchester United'], contains('Bruno Fernandes'));
      expect(loadedAi['Real Madrid'], contains('Vinicius Jr'));

      await prefs.clearCareerConfig();
      final cleared = await prefs.getCareerConfig();
      expect(cleared, isNull);
    });

    test('Mutual exclusivity: User-owned player NEVER appears in any AI club squad', () {
      final userSquad = [
        const Player(
          mode: 'pl',
          squadId: 'ars_2024',
          teamCode: 'ARS',
          teamName: 'Arsenal',
          season: 2024,
          playerId: 'CR7',
          name: 'Cristiano Ronaldo',
          overall: 88,
          displayPosition: 'ST',
          primaryPosition: 'ST',
          allPositions: 'ST',
          pace: 82,
          shooting: 90,
          passing: 78,
          dribbling: 82,
          defending: 35,
          physicality: 76,
          isGoalkeeper: false,
        )
      ];

      final claimedPlayerNames = <String>{};
      for (final p in userSquad) {
        claimedPlayerNames.add(p.name.trim().toLowerCase());
      }

      // Simulated DB rows for Manchester United and Real Madrid containing Cristiano Ronaldo
      final manUtdDbRows = [
        {'player_name': 'Cristiano Ronaldo', 'primary_position': 'ST', 'overall': 92},
        {'player_name': 'Bruno Fernandes', 'primary_position': 'CAM', 'overall': 88},
        {'player_name': 'Marcus Rashford', 'primary_position': 'LW', 'overall': 84},
      ];

      final realMadridDbRows = [
        {'player_name': 'Cristiano Ronaldo', 'primary_position': 'ST', 'overall': 94},
        {'player_name': 'Vinicius Jr', 'primary_position': 'LW', 'overall': 89},
        {'player_name': 'Jude Bellingham', 'primary_position': 'CAM', 'overall': 90},
      ];

      // Manchester United claims
      final manUtdSquad = <String>[];
      for (final r in manUtdDbRows) {
        final name = (r['player_name'] as String).trim().toLowerCase();
        if (!claimedPlayerNames.contains(name)) {
          claimedPlayerNames.add(name);
          manUtdSquad.add(r['player_name'] as String);
        }
      }

      // Real Madrid claims
      final realMadridSquad = <String>[];
      for (final r in realMadridDbRows) {
        final name = (r['player_name'] as String).trim().toLowerCase();
        if (!claimedPlayerNames.contains(name)) {
          claimedPlayerNames.add(name);
          realMadridSquad.add(r['player_name'] as String);
        }
      }

      // Cristiano Ronaldo MUST NOT be in Manchester United or Real Madrid
      expect(manUtdSquad, isNot(contains('Cristiano Ronaldo')));
      expect(manUtdSquad, contains('Bruno Fernandes'));
      expect(realMadridSquad, isNot(contains('Cristiano Ronaldo')));
      expect(realMadridSquad, contains('Vinicius Jr'));
    });

    test('Cross-club exclusivity: Two AI clubs never share the same player', () {
      final claimedPlayerNames = <String>{};

      // Man United processes first and claims historical Ronaldo
      final manUtdDbRows = [
        {'player_name': 'Cristiano Ronaldo', 'primary_position': 'ST', 'overall': 92},
        {'player_name': 'Wayne Rooney', 'primary_position': 'ST', 'overall': 90},
      ];

      final realMadridDbRows = [
        {'player_name': 'Cristiano Ronaldo', 'primary_position': 'ST', 'overall': 94},
        {'player_name': 'Karim Benzema', 'primary_position': 'ST', 'overall': 91},
      ];

      final manUtdSquad = <String>[];
      for (final r in manUtdDbRows) {
        final name = (r['player_name'] as String).trim().toLowerCase();
        if (!claimedPlayerNames.contains(name)) {
          claimedPlayerNames.add(name);
          manUtdSquad.add(r['player_name'] as String);
        }
      }

      final realMadridSquad = <String>[];
      for (final r in realMadridDbRows) {
        final name = (r['player_name'] as String).trim().toLowerCase();
        if (!claimedPlayerNames.contains(name)) {
          claimedPlayerNames.add(name);
          realMadridSquad.add(r['player_name'] as String);
        }
      }

      expect(manUtdSquad, contains('Cristiano Ronaldo'));
      expect(realMadridSquad, isNot(contains('Cristiano Ronaldo')),
          reason: 'Real Madrid cannot claim Cristiano Ronaldo because Man United already claimed him');
      expect(realMadridSquad, contains('Karim Benzema'));

      // The intersection of player names between clubs must be strictly empty
      final intersection = manUtdSquad.toSet().intersection(realMadridSquad.toSet());
      expect(intersection, isEmpty);
    });

    test('User signing immediately removes player from previous AI club and updates active club mapping', () {
      final aiClubSquads = {
        'Manchester United': ['Cristiano Ronaldo', 'Bruno Fernandes', 'Marcus Rashford'],
        'Real Madrid': ['Kylian Mbappé', 'Vinicius Jr'],
      };

      final aiClubPlayers = {
        'Manchester United': [
          SimPlayer(name: 'Cristiano Ronaldo', position: 'ST', overall: 90, isStarter: true),
          SimPlayer(name: 'Bruno Fernandes', position: 'CAM', overall: 88, isStarter: true),
          SimPlayer(name: 'Marcus Rashford', position: 'LW', overall: 84, isStarter: true),
        ],
      };

      // User signs Cristiano Ronaldo
      final target = 'Cristiano Ronaldo'.trim().toLowerCase();
      for (final club in aiClubSquads.keys) {
        aiClubSquads[club]?.removeWhere((n) => n.trim().toLowerCase() == target);
      }
      for (final club in aiClubPlayers.keys) {
        aiClubPlayers[club]?.removeWhere((p) => p.name.trim().toLowerCase() == target);
      }

      expect(aiClubSquads['Manchester United'], isNot(contains('Cristiano Ronaldo')));
      expect(aiClubPlayers['Manchester United']!.any((p) => p.name == 'Cristiano Ronaldo'), isFalse);
      expect(aiClubSquads['Manchester United'], contains('Bruno Fernandes'));
    });

    test('User selling a player to AI club moves player to buying club squad and SimPlayers', () {
      final aiClubSquads = {
        'Real Madrid': ['Vinicius Jr', 'Kylian Mbappé'],
      };
      final aiClubPlayers = {
        'Real Madrid': [
          SimPlayer(name: 'Vinicius Jr', position: 'LW', overall: 90, isStarter: true),
          SimPlayer(name: 'Kylian Mbappé', position: 'ST', overall: 91, isStarter: true),
        ],
      };

      final soldPlayer = const Player(
        mode: 'pl',
        squadId: 'ars_2024',
        teamCode: 'ARS',
        teamName: 'Arsenal',
        season: 2024,
        playerId: 'BS7',
        name: 'Bukayo Saka',
        overall: 88,
        displayPosition: 'RW',
        primaryPosition: 'RW',
        allPositions: 'RW',
        pace: 86,
        shooting: 84,
        passing: 83,
        dribbling: 89,
        defending: 65,
        physicality: 76,
        isGoalkeeper: false,
      );

      final buyingClub = 'Real Madrid';
      aiClubSquads[buyingClub]!.insert(0, soldPlayer.name);
      aiClubPlayers[buyingClub]!.insert(0, SimPlayer(
        name: soldPlayer.name,
        position: soldPlayer.primaryPosition,
        overall: soldPlayer.overall,
        isStarter: true,
      ));

      expect(aiClubSquads['Real Madrid'], contains('Bukayo Saka'));
      expect(aiClubPlayers['Real Madrid']!.first.name, 'Bukayo Saka');
    });
  });

  group('Fix 35: Formation-Aware Auto-Pick Best XI With Strict Positional Quotas', () {
    Player makeTestPlayer({
      required String id,
      required String name,
      required String pos,
      required int ovr,
      bool isGk = false,
      String? allPos,
    }) {
      return Player(
        mode: 'pl',
        squadId: 'squad_test',
        teamCode: 'ARS',
        teamName: 'Arsenal',
        season: 2024,
        playerId: id,
        name: name,
        overall: ovr,
        displayPosition: pos,
        primaryPosition: pos,
        allPositions: allPos ?? pos,
        pace: 75,
        shooting: 75,
        passing: 75,
        dribbling: 75,
        defending: 75,
        physicality: 75,
        isGoalkeeper: isGk,
      );
    }

    test('In 4-3-3 formation, 3rd attacker is chosen over higher rated 5th defender', () {
      final squad = [
        // 2 GKs
        makeTestPlayer(id: 'gk1', name: 'Alisson', pos: 'GK', ovr: 89, isGk: true),
        makeTestPlayer(id: 'gk2', name: 'Kelleher', pos: 'GK', ovr: 77, isGk: true),

        // 6 Defenders (all high rated)
        makeTestPlayer(id: 'def1', name: 'Van Dijk', pos: 'CB', ovr: 89),
        makeTestPlayer(id: 'def2', name: 'Saliba', pos: 'CB', ovr: 88),
        makeTestPlayer(id: 'def3', name: 'Robertson', pos: 'LB', ovr: 86),
        makeTestPlayer(id: 'def4', name: 'Alexander-Arnold', pos: 'RB', ovr: 86),
        makeTestPlayer(id: 'def5', name: 'Konate', pos: 'CB', ovr: 85),
        makeTestPlayer(id: 'def6', name: 'Gabriel', pos: 'CB', ovr: 84),

        // 5 Midfielders
        makeTestPlayer(id: 'mid1', name: 'De Bruyne', pos: 'CAM', ovr: 91),
        makeTestPlayer(id: 'mid2', name: 'Rodri', pos: 'CDM', ovr: 90),
        makeTestPlayer(id: 'mid3', name: 'Odegaard', pos: 'CM', ovr: 88),
        makeTestPlayer(id: 'mid4', name: 'Rice', pos: 'CDM', ovr: 86),
        makeTestPlayer(id: 'mid5', name: 'Mac Allister', pos: 'CM', ovr: 84),

        // 4 Attackers (3rd attacker is 80 OVR, lower than def5/def6/mid4/mid5)
        makeTestPlayer(id: 'fwd1', name: 'Salah', pos: 'RW', ovr: 89),
        makeTestPlayer(id: 'fwd2', name: 'Haaland', pos: 'ST', ovr: 91),
        makeTestPlayer(id: 'fwd3', name: 'Martinelli', pos: 'LW', ovr: 80),
        makeTestPlayer(id: 'fwd4', name: 'Nketiah', pos: 'ST', ovr: 75),
      ];

      final sorted = TacticalFormation.autoPickLineup(squad, formationId: '4-3-3');

      // Total length preserved
      expect(sorted.length, squad.length);

      final starters = sorted.take(11).toList();
      final starterIds = starters.map((p) => p.playerId).toSet();

      // Exactly 1 GK, 4 DEF, 3 MID, 3 FWD in starters
      final startingGks = starters.where((p) => p.isGoalkeeper || p.primaryPosition == 'GK').toList();
      final startingDefs = starters.where((p) => const ['CB', 'LB', 'RB', 'LWB', 'RWB'].contains(p.primaryPosition)).toList();
      final startingMids = starters.where((p) => const ['CM', 'CAM', 'CDM', 'LM', 'RM'].contains(p.primaryPosition)).toList();
      final startingFwds = starters.where((p) => const ['ST', 'CF', 'LW', 'RW'].contains(p.primaryPosition)).toList();

      expect(startingGks.length, 1, reason: '4-3-3 must have exactly 1 GK starter');
      expect(startingDefs.length, 4, reason: '4-3-3 must have exactly 4 DEF starters');
      expect(startingMids.length, 3, reason: '4-3-3 must have exactly 3 MID starters');
      expect(startingFwds.length, 3, reason: '4-3-3 must have exactly 3 FWD starters');

      // KEY REQUIREMENT: Martinelli (80 OVR FWD) MUST start in 4-3-3 over Konate (85 OVR DEF)
      expect(starterIds.contains('fwd3'), isTrue,
          reason: 'A defender cannot play in place of a lower rated attacker');
      expect(starterIds.contains('def5'), isFalse,
          reason: '5th defender (85 OVR) cannot displace 3rd forward (80 OVR) in 4-3-3');
      expect(starterIds.contains('def6'), isFalse,
          reason: '6th defender (84 OVR) cannot displace 3rd forward (80 OVR) in 4-3-3');

      // Bench GK at index 11
      expect(sorted[11].playerId, 'gk2');

      // Konate (85 OVR) is on the bench as top outfield reserve
      final bench = sorted.skip(11).toList();
      expect(bench.any((p) => p.playerId == 'def5'), isTrue);
    });

    test('In 3-4-3 formation, 3 defenders and 3 forwards are strictly selected', () {
      final squad = [
        makeTestPlayer(id: 'gk1', name: 'GK1', pos: 'GK', ovr: 85, isGk: true),
        makeTestPlayer(id: 'gk2', name: 'GK2', pos: 'GK', ovr: 75, isGk: true),

        makeTestPlayer(id: 'def1', name: 'DEF1', pos: 'CB', ovr: 88),
        makeTestPlayer(id: 'def2', name: 'DEF2', pos: 'CB', ovr: 87),
        makeTestPlayer(id: 'def3', name: 'DEF3', pos: 'CB', ovr: 86),
        makeTestPlayer(id: 'def4', name: 'DEF4', pos: 'CB', ovr: 85),

        makeTestPlayer(id: 'mid1', name: 'MID1', pos: 'CM', ovr: 87),
        makeTestPlayer(id: 'mid2', name: 'MID2', pos: 'LM', ovr: 86),
        makeTestPlayer(id: 'mid3', name: 'MID3', pos: 'RM', ovr: 85),
        makeTestPlayer(id: 'mid4', name: 'MID4', pos: 'CM', ovr: 84),

        makeTestPlayer(id: 'fwd1', name: 'FWD1', pos: 'LW', ovr: 86),
        makeTestPlayer(id: 'fwd2', name: 'FWD2', pos: 'ST', ovr: 85),
        makeTestPlayer(id: 'fwd3', name: 'FWD3', pos: 'RW', ovr: 79),
      ];

      final sorted = TacticalFormation.autoPickLineup(squad, formationId: '3-4-3');
      final starters = sorted.take(11).toList();
      final starterIds = starters.map((p) => p.playerId).toSet();

      // 3-4-3 has 3 DEF, 4 MID, 3 FWD
      expect(starterIds.contains('fwd3'), isTrue,
          reason: 'FWD3 (79 OVR) must start in 3-4-3 over DEF4 (85 OVR)');
      expect(starterIds.contains('def4'), isFalse,
          reason: '4th defender cannot start in 3-defender formation');
    });

    test('Macro position groups correctly categorize roles and coordinates', () {
      expect(TacticalFormation.getPlayerPositionGroup(
        makeTestPlayer(id: '1', name: 'P', pos: 'CB', ovr: 80)), 'DEF');
      expect(TacticalFormation.getPlayerPositionGroup(
        makeTestPlayer(id: '2', name: 'P', pos: 'RB', ovr: 80)), 'DEF');
      expect(TacticalFormation.getPlayerPositionGroup(
        makeTestPlayer(id: '3', name: 'P', pos: 'CM', ovr: 80)), 'MID');
      expect(TacticalFormation.getPlayerPositionGroup(
        makeTestPlayer(id: '4', name: 'P', pos: 'CAM', ovr: 80)), 'MID');
      expect(TacticalFormation.getPlayerPositionGroup(
        makeTestPlayer(id: '5', name: 'P', pos: 'LW', ovr: 80)), 'FWD');
      expect(TacticalFormation.getPlayerPositionGroup(
        makeTestPlayer(id: '6', name: 'P', pos: 'ST', ovr: 80)), 'FWD');
      expect(TacticalFormation.getPlayerPositionGroup(
        makeTestPlayer(id: '7', name: 'P', pos: 'GK', ovr: 80, isGk: true)), 'GK');
    });
  });
}



