import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/player.dart';
import '../../domain/models/team.dart';

/// Database service handling offline SQLite operations on `players.db`.
/// Fast FTS5 search (<80ms), asset extraction on first launch, cross-platform support.
class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for desktop (Windows / Linux / macOS) if running outside Android/iOS
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'touchline_players.db');

    final prefs = await SharedPreferences.getInstance();
    const currentDbVersion = 2;
    final installedVersion = prefs.getInt('db_asset_version') ?? 0;

    // Check if database exists in documents directory
    final file = File(dbPath);
    final exists = await file.exists();

    if (!exists || installedVersion < currentDbVersion) {
      debugPrint('Extracting bundled players.db (v$currentDbVersion) to $dbPath...');
      try {
        final byteData = await rootBundle.load('assets/db/players.db');
        final bytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
        await file.writeAsBytes(bytes, flush: true);
        await prefs.setInt('db_asset_version', currentDbVersion);
        debugPrint('Extraction complete (${bytes.length ~/ (1024 * 1024)} MB).');
      } catch (e) {
        debugPrint('Error copying assets/db/players.db: $e');
        // If running in development/local test where rootBundle might point directly or asset is at local path:
        const fallbackPath = 'assets/db/players.db';
        if (File(fallbackPath).existsSync()) {
          final fallbackBytes = await File(fallbackPath).readAsBytes();
          await file.writeAsBytes(fallbackBytes, flush: true);
          await prefs.setInt('db_asset_version', currentDbVersion);
        } else {
          rethrow;
        }
      }
    }

    return await openDatabase(
      dbPath,
      readOnly: true,
      singleInstance: true,
    );
  }

  /// Fast FTS5 search with prefix matching and ranking by overall rating
  Future<List<Player>> searchPlayers(String query, {int limit = 25}) async {
    final db = await database;
    final cleanQuery = query.trim().replaceAll(RegExp(r'[^\w\s]'), '');
    if (cleanQuery.isEmpty) return [];

    // Format query for FTS: e.g. "lampard*" or "frank* lampard*"
    final words = cleanQuery.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final ftsExpression = words.map((w) => '$w*').join(' ');

    try {
      final results = await db.rawQuery('''
        SELECT p.*
        FROM players p
        JOIN players_fts fts ON p.rowid = fts.rowid
        WHERE players_fts MATCH ?
        GROUP BY p.player_name
        ORDER BY MAX(p.overall) DESC
        LIMIT ?
      ''', [ftsExpression, limit]);

      return results.map((row) => Player.fromMap(row)).toList();
    } catch (e) {
      debugPrint('FTS search fallback on error: $e');
      // Fallback to LIKE if FTS expression has syntax quirk
      final likePattern = '%$cleanQuery%';
      final fallbackResults = await db.rawQuery('''
        SELECT * FROM players
        WHERE player_name LIKE ? OR team_name LIKE ?
        GROUP BY player_name
        ORDER BY MAX(overall) DESC
        LIMIT ?
      ''', [likePattern, likePattern, limit]);

      return fallbackResults.map((row) => Player.fromMap(row)).toList();
    }
  }

  /// Get distinct top players by rating for quick lists or suggestions
  Future<List<Player>> getTopPlayers({int limit = 50}) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT * FROM players
      GROUP BY player_name
      ORDER BY MAX(overall) DESC
      LIMIT ?
    ''', [limit]);

    return results.map((row) => Player.fromMap(row)).toList();
  }

  /// Get a single player by ID
  Future<Player?> getPlayerById(String id) async {
    final db = await database;
    final results = await db.query(
      'players',
      where: 'player_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Player.fromMap(results.first);
  }

  /// Get all players for a specific team squad
  Future<List<Player>> getPlayersByTeam(String teamCode, int season) async {
    final db = await database;
    final results = await db.query(
      'players',
      where: 'team_code = ? AND season = ?',
      whereArgs: [teamCode, season],
      orderBy: 'overall DESC',
    );
    return results.map((row) => Player.fromMap(row)).toList();
  }

  /// Get all teams for selection or tournament mode
  Future<List<Team>> getTeams({String? mode, int limit = 100}) async {
    final db = await database;
    final results = await db.query(
      'teams',
      where: mode != null ? 'mode = ?' : null,
      whereArgs: mode != null ? [mode] : null,
      orderBy: 'avg_ovr DESC',
      limit: limit,
    );
    return results.map((row) => Team.fromMap(row)).toList();
  }

  /// Fetch random players with career goals for Goal Chase mode
  Future<List<Player>> getPlayersWithCareerGoals({int count = 3, int minGoals = 10}) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT * FROM players
      WHERE career_goals IS NOT NULL AND career_goals >= ?
      ORDER BY RANDOM()
      LIMIT ?
    ''', [minGoals, count]);
    return results.map((row) => Player.fromMap(row)).toList();
  }

  /// Get database telemetry and row counts for the /debug screen
  Future<Map<String, dynamic>> getDatabaseMetrics() async {
    final db = await database;
    final playerCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM players'),
    ) ?? 0;

    final teamCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM teams'),
    ) ?? 0;

    final ftsCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM players_fts'),
    ) ?? 0;

    final goalPlayersCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM players WHERE career_goals IS NOT NULL'),
    ) ?? 0;

    final natCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM players WHERE nationality IS NOT NULL'),
    ) ?? 0;

    final footCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM players WHERE preferred_foot IS NOT NULL'),
    ) ?? 0;

    final docsDir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(docsDir.path, 'touchline_players.db'));
    final sizeMb = (await dbFile.exists()) ? (await dbFile.length()) / (1024 * 1024) : 0.0;

    return {
      'playerCount': playerCount,
      'teamCount': teamCount,
      'ftsCount': ftsCount,
      'goalPlayersCount': goalPlayersCount,
      'nationalityCoverage': natCount,
      'footCoverage': footCount,
      'databaseSizeMb': sizeMb,
      'databasePath': dbFile.path,
    };
  }
}
