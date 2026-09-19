import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseService Direct SQLite Tests', () {
    late Database db;

    setUp(() async {
      final dbPath = File('assets/db/players.db').absolute.path;
      expect(File(dbPath).existsSync(), isTrue, reason: 'assets/db/players.db must exist');
      db = await databaseFactory.openDatabase(dbPath, options: OpenDatabaseOptions(readOnly: true));
    });

    tearDown(() async {
      await db.close();
    });

    test('Total counts match enriched database specifications', () async {
      final playerCount = (await db.rawQuery('SELECT COUNT(*) FROM players')).first.values.first as int;
      final teamCount = (await db.rawQuery('SELECT COUNT(*) FROM teams')).first.values.first as int;
      final ftsCount = (await db.rawQuery('SELECT COUNT(*) FROM players_fts')).first.values.first as int;

      expect(playerCount, 24651);
      expect(teamCount, 849);
      expect(ftsCount, 24651);
    });

    test('Harry Kane and Cristiano Ronaldo ID separation', () async {
      final ronaldoRows = await db.query(
        'players',
        where: 'player_id = ?',
        whereArgs: ['20801'],
      );
      expect(ronaldoRows.isNotEmpty, isTrue);
      for (final row in ronaldoRows) {
        expect(row['player_name'], contains('Cristiano Ronaldo'));
      }

      final kaneRows = await db.query(
        'players',
        where: 'player_id = ?',
        whereArgs: ['202126'],
      );
      expect(kaneRows.isNotEmpty, isTrue);
      for (final row in kaneRows) {
        expect(row['player_name'], contains('Kane'));
      }
    });

    test('Frank Lampard name unification', () async {
      final lampardRows = await db.query(
        'players',
        where: 'player_id = ?',
        whereArgs: ['5471'],
      );
      expect(lampardRows.isNotEmpty, isTrue);
      for (final row in lampardRows) {
        expect(row['player_name'], 'Frank Lampard');
      }
    });

    test('FTS5 search performance and accuracy', () async {
      final stopwatch = Stopwatch()..start();
      final results = await db.rawQuery('''
        SELECT p.player_name, p.team_name, p.overall
        FROM players p
        JOIN players_fts fts ON p.rowid = fts.rowid
        WHERE players_fts MATCH 'messi*'
        ORDER BY p.overall DESC
        LIMIT 10
      ''');
      stopwatch.stop();

      expect(results.isNotEmpty, isTrue);
      expect(results.first['player_name'], contains('Messi'));
      expect(stopwatch.elapsedMilliseconds, lessThan(80), reason: 'Search should be <80ms');
    });

    test('Enriched fields coverage', () async {
      final natCount = (await db.rawQuery("SELECT COUNT(*) FROM players WHERE nationality IS NOT NULL AND nationality != ''")).first.values.first as int;
      expect(natCount / 24651, greaterThan(0.98)); // >98% nationality coverage

      final footCount = (await db.rawQuery("SELECT COUNT(*) FROM players WHERE preferred_foot IS NOT NULL AND preferred_foot != ''")).first.values.first as int;
      expect(footCount / 24651, greaterThan(0.70)); // >70% preferred foot

      final goalCount = (await db.rawQuery("SELECT COUNT(*) FROM players WHERE career_goals IS NOT NULL")).first.values.first as int;
      expect(goalCount, greaterThanOrEqualTo(6400)); // Transfermarkt career goals
    });

    test('Search deduplication returns unique players with peak rating', () async {
      final results = await db.rawQuery('''
        SELECT p.player_name, p.team_name, p.overall
        FROM players p
        JOIN players_fts fts ON p.rowid = fts.rowid
        WHERE players_fts MATCH 'ronaldo*'
        GROUP BY p.player_name
        ORDER BY MAX(p.overall) DESC
        LIMIT 10
      ''');

      final names = results.map((r) => r['player_name']).toList();
      // Must not have duplicates
      expect(names.toSet().length, names.length, reason: 'Search results must be deduplicated by player_name');
      expect(names, contains('Cristiano Ronaldo'));

      final cr7Row = results.firstWhere((r) => r['player_name'] == 'Cristiano Ronaldo');
      expect(cr7Row['overall'], greaterThanOrEqualTo(94), reason: 'Peak OVR should be preserved in deduplicated row');
    });
  });
}
