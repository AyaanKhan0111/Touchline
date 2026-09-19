import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Separate writable SQLite database (`save.db`) for careers, streaks, and ledger.
/// Section 2 requirement: "Career saves must survive app kill mid-season."
class SaveService {
  static final SaveService instance = SaveService._();
  SaveService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      dbPath = p.join(docsDir.path, 'touchline_save.db');
    } catch (_) {
      dbPath = inMemoryDatabasePath;
    }

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        // Coin transaction ledger
        await db.execute('''
          CREATE TABLE coins_ledger (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            delta INTEGER NOT NULL,
            reason TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');

        // Completed puzzle records
        await db.execute('''
          CREATE TABLE completed_puzzles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mode TEXT NOT NULL,
            date TEXT NOT NULL,
            score INTEGER NOT NULL,
            rarity REAL,
            time_seconds INTEGER,
            timestamp INTEGER NOT NULL
          )
        ''');

        // Career campaign persistence
        await db.execute('''
          CREATE TABLE career_save (
            save_id TEXT PRIMARY KEY,
            club_code TEXT NOT NULL,
            season INTEGER NOT NULL,
            budget REAL NOT NULL,
            state_json TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> recordCoinTransaction(int delta, String reason) async {
    final db = await database;
    await db.insert('coins_ledger', {
      'delta': delta,
      'reason': reason,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> recordPuzzleResult({
    required String mode,
    required String date,
    required int score,
    double? rarity,
    int? timeSeconds,
  }) async {
    final db = await database;
    await db.insert('completed_puzzles', {
      'mode': mode,
      'date': date,
      'score': score,
      'rarity': rarity,
      'time_seconds': timeSeconds,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getCompletedPuzzles({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'completed_puzzles',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  /// Persists full career campaign state into SQLite database (Issue #10)
  Future<void> saveCareerState({
    String saveId = 'active_career',
    required String clubCode,
    required int season,
    required double budget,
    required Map<String, dynamic> state,
  }) async {
    final db = await database;
    await db.insert(
      'career_save',
      {
        'save_id': saveId,
        'club_code': clubCode,
        'season': season,
        'budget': budget,
        'state_json': jsonEncode(state),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Loads full career campaign state from SQLite database (Issue #10)
  Future<Map<String, dynamic>?> loadCareerState([String saveId = 'active_career']) async {
    final db = await database;
    final rows = await db.query(
      'career_save',
      where: 'save_id = ?',
      whereArgs: [saveId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final jsonStr = rows.first['state_json'] as String;
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Checks if a valid career campaign save exists in SQLite database (Issue #10)
  Future<bool> hasCareerSave([String saveId = 'active_career']) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM career_save WHERE save_id = ?',
      [saveId],
    );
    final count = (res.first['cnt'] as num?)?.toInt() ?? 0;
    return count > 0;
  }

  /// Deletes career campaign save from SQLite database (Issue #10)
  Future<void> deleteCareerSave([String saveId = 'active_career']) async {
    final db = await database;
    await db.delete('career_save', where: 'save_id = ?', whereArgs: [saveId]);
  }
}
