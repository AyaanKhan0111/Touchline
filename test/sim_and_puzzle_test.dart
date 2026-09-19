import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:touchline/domain/models/player.dart';
import 'package:touchline/domain/services/puzzle_generator.dart';
import 'package:touchline/domain/services/rarity_calculator.dart';
import 'package:touchline/domain/services/sim_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SimEngine Tests', () {
    test('Deterministic simulation with fixed seed produces identical result', () {
      final sim1 = SimEngine(42);
      final res1 = sim1.simulateMatch(
        homeClub: 'Arsenal',
        homeRating: 84.0,
        awayClub: 'Chelsea',
        awayRating: 82.0,
      );

      final sim2 = SimEngine(42);
      final res2 = sim2.simulateMatch(
        homeClub: 'Arsenal',
        homeRating: 84.0,
        awayClub: 'Chelsea',
        awayRating: 82.0,
      );

      expect(res1.homeGoals, res2.homeGoals);
      expect(res1.awayGoals, res2.awayGoals);
      expect(res1.scoreLine, res2.scoreLine);
    });

    test('TableEntry computes points, goal difference, and record correctly', () {
      final table = TableEntry(clubName: 'Liverpool');
      table.recordResult(scored: 3, conceded: 1); // Win
      table.recordResult(scored: 2, conceded: 2); // Draw
      table.recordResult(scored: 0, conceded: 1); // Loss

      expect(table.played, 3);
      expect(table.won, 1);
      expect(table.drawn, 1);
      expect(table.lost, 1);
      expect(table.goalsFor, 5);
      expect(table.goalsAgainst, 4);
      expect(table.goalDifference, 1);
      expect(table.points, 4); // 3 + 1 + 0
    });
  });

  group('RarityCalculator Tests', () {
    test('Obviousness heuristic increases with OVR, prestige, and recency', () {
      final messi = Player.fromMap({
        'mode': 'EA Sports FC 27',
        'season': 2027,
        'overall': 90,
        'intl_reputation': 5.0,
      });

      final unknown = Player.fromMap({
        'mode': 'European League',
        'season': 1998,
        'overall': 72,
        'intl_reputation': 1.0,
      });

      final messiWeight = RarityCalculator.calculateObviousness(messi);
      final unknownWeight = RarityCalculator.calculateObviousness(unknown);

      expect(messiWeight, greaterThan(unknownWeight));
    });

    test('Rarity score calculation', () {
      final star = Player.fromMap({'overall': 92, 'mode': 'EA Sports FC 27', 'season': 2027});
      final obscure = Player.fromMap({'overall': 75, 'mode': 'Premier League', 'season': 1996});

      final starRarity = RarityCalculator.calculateRarityScore(star, [star, obscure]);
      final obscureRarity = RarityCalculator.calculateRarityScore(obscure, [star, obscure]);

      // Star should have higher percentage (more common pick), obscure should be lower percentage
      expect(starRarity, greaterThan(obscureRarity));
    });
  });

  group('Grid Solvability Tests', () {
    late Database db;

    setUp(() async {
      final dbPath = File('assets/db/players.db').absolute.path;
      db = await databaseFactory.openDatabase(dbPath, options: OpenDatabaseOptions(readOnly: true));
    });

    tearDown(() async {
      await db.close();
    });

    test('Pre-configured fallback grid has >= 3 valid answers for every intersection', () async {
      final grid = await PuzzleGenerator.generateValidGrid(12345, db);

      for (final r in grid.rowCategories) {
        for (final c in grid.colCategories) {
          final count = await PuzzleGenerator.getValidAnswersCount(db, r, c);
          expect(count, greaterThanOrEqualTo(3),
              reason: 'Cell intersection ${r.title} × ${c.title} must have >= 3 valid answers');
        }
      }
    });

    test('Player satisfies multi-club intersections across their entire career', () async {
      const rmaCategory = GridCategory(
        id: 'club_rma',
        title: 'Real Madrid',
        subtitle: 'Played for Club',
        sqlCondition: 'team_name LIKE ?',
        sqlArgs: ['%Real Madrid%'],
      );

      const munCategory = GridCategory(
        id: 'club_mun',
        title: 'Manchester United',
        subtitle: 'Played for Club',
        sqlCondition: 'team_name LIKE ?',
        sqlArgs: ['%Manchester United%'],
      );

      const cheCategory = GridCategory(
        id: 'club_che',
        title: 'Chelsea',
        subtitle: 'Played for Club',
        sqlCondition: 'team_name LIKE ?',
        sqlArgs: ['%Chelsea%'],
      );

      const mciCategory = GridCategory(
        id: 'club_mci',
        title: 'Manchester City',
        subtitle: 'Played for Club',
        sqlCondition: 'team_name LIKE ?',
        sqlArgs: ['%Manchester City%'],
      );

      // 1. Both clubs have valid intersection count >= 3
      final rmaMunCount = await PuzzleGenerator.getValidAnswersCount(db, rmaCategory, munCategory);
      expect(rmaMunCount, greaterThanOrEqualTo(3), reason: 'RMA × MUN must have >= 3 players (CR7, Casemiro, Varane)');

      final cheMciCount = await PuzzleGenerator.getValidAnswersCount(db, cheCategory, mciCategory);
      expect(cheMciCount, greaterThanOrEqualTo(3), reason: 'CHE × MCI must have >= 3 players (Lampard, Sterling, Palmer)');

      // 2. Validate individual players
      final cr7 = Player.fromMap({'name': 'Cristiano Ronaldo', 'player_id': '20801', 'overall': 94});
      final cr7Valid = await PuzzleGenerator.validatePlayerForCell(db, cr7, rmaCategory, munCategory);
      expect(cr7Valid, isTrue, reason: 'Cristiano Ronaldo played for both Real Madrid and Manchester United');

      final lampard = Player.fromMap({'name': 'Frank Lampard', 'player_id': '5471', 'overall': 90});
      final lampardValid = await PuzzleGenerator.validatePlayerForCell(db, lampard, cheCategory, mciCategory);
      expect(lampardValid, isTrue, reason: 'Frank Lampard played for both Chelsea and Manchester City');

      // 3. Negative check
      final messi = Player.fromMap({'name': 'Lionel Messi', 'player_id': '158023', 'overall': 94});
      final messiInvalid = await PuzzleGenerator.validatePlayerForCell(db, messi, rmaCategory, munCategory);
      expect(messiInvalid, isFalse, reason: 'Lionel Messi never played for Real Madrid or Manchester United');
    });

    test('Mohamed Salah validates across career for Liverpool, 85+ OVR, and Egypt', () async {
      const livCategory = GridCategory(
        id: 'club_liv',
        title: 'Liverpool',
        subtitle: 'Played for Club',
        sqlCondition: 'team_name LIKE ?',
        sqlArgs: ['%Liverpool%'],
      );

      const ovr85Category = GridCategory(
        id: 'stat_85plus',
        title: '85+ OVR Rating',
        subtitle: 'Peak Overall Rating',
        sqlCondition: 'overall >= ?',
        sqlArgs: [85],
      );

      const egyptCategory = GridCategory(
        id: 'nation_egypt',
        title: 'Egypt',
        subtitle: 'Nationality',
        sqlCondition: 'nationality = ?',
        sqlArgs: ['Egypt'],
      );

      // Query Salah from test DB
      final rows = await db.rawQuery(
        'SELECT * FROM players WHERE player_name = ? GROUP BY player_name',
        ['Mohamed Salah'],
      );
      expect(rows, isNotEmpty, reason: 'Mohamed Salah must exist in DB');
      final salah = Player.fromMap(rows.first);

      // Verify Salah validates for Liverpool x 85+ OVR
      final salahLiv85 = await PuzzleGenerator.validatePlayerForCell(db, salah, livCategory, ovr85Category);
      expect(salahLiv85, isTrue, reason: 'Mohamed Salah must validate for Liverpool x 85+ OVR');

      // Verify Salah validates for Egypt x Liverpool
      final salahEgyptLiv = await PuzzleGenerator.validatePlayerForCell(db, salah, egyptCategory, livCategory);
      expect(salahEgyptLiv, isTrue, reason: 'Mohamed Salah played for Liverpool and represents Egypt');
    });
  });
}
