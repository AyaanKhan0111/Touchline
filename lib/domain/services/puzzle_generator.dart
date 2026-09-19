import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../../core/database/db_service.dart';
import '../models/player.dart';

/// Criterion for Grid rows or columns
class GridCategory {
  final String id;
  final String title;
  final String subtitle;
  final String sqlCondition;
  final List<dynamic> sqlArgs;

  const GridCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.sqlCondition,
    required this.sqlArgs,
  });
}

/// 3x3 Grid Puzzle definition
class GridPuzzle {
  final List<GridCategory> rowCategories;
  final List<GridCategory> colCategories;
  final String seed;

  const GridPuzzle({
    required this.rowCategories,
    required this.colCategories,
    required this.seed,
  });
}

/// Service to generate & validate puzzles dynamically from the database
class PuzzleGenerator {
  PuzzleGenerator._();

  // Curated prominent clubs with deep roster history
  static const List<Map<String, String>> clubPool = [
    {'code': 'RMA', 'name': 'Real Madrid', 'country': 'Spain'},
    {'code': 'BAR', 'name': 'Barcelona', 'country': 'Spain'},
    {'code': 'MUN', 'name': 'Manchester United', 'country': 'England'},
    {'code': 'LIV', 'name': 'Liverpool', 'country': 'England'},
    {'code': 'ARS', 'name': 'Arsenal', 'country': 'England'},
    {'code': 'CHE', 'name': 'Chelsea', 'country': 'England'},
    {'code': 'MCI', 'name': 'Manchester City', 'country': 'England'},
    {'code': 'BAY', 'name': 'Bayern Munich', 'country': 'Germany'},
    {'code': 'JUV', 'name': 'Juventus', 'country': 'Italy'},
    {'code': 'MIL', 'name': 'AC Milan', 'country': 'Italy'},
    {'code': 'INT', 'name': 'Inter', 'country': 'Italy'},
    {'code': 'PSG', 'name': 'Paris Saint-Germain', 'country': 'France'},
    {'code': 'TOT', 'name': 'Tottenham Hotspur', 'country': 'England'},
    {'code': 'ATM', 'name': 'Atlético Madrid', 'country': 'Spain'},
    {'code': 'DOR', 'name': 'Borussia Dortmund', 'country': 'Germany'},
  ];

  static const List<String> nationPool = [
    'England', 'France', 'Spain', 'Germany', 'Brazil',
    'Argentina', 'Italy', 'Netherlands', 'Portugal', 'Belgium'
  ];

  static const List<Map<String, String>> positionPool = [
    {'pos': 'ST', 'label': 'Forward (ST/CF)', 'condition': "primary_position IN ('ST', 'CF', 'LW', 'RW')"},
    {'pos': 'MID', 'label': 'Midfielder (CM/CAM/CDM)', 'condition': "primary_position IN ('CM', 'CAM', 'CDM', 'LM', 'RM')"},
    {'pos': 'DEF', 'label': 'Defender (CB/LB/RB)', 'condition': "primary_position IN ('CB', 'LB', 'RB', 'RWB', 'LWB')"},
  ];

  static const List<Map<String, dynamic>> traitPool = [
    {
      'id': 'stat_85plus',
      'title': '85+ OVR Rating',
      'subtitle': 'Peak Overall Rating',
      'condition': 'overall >= ?',
      'args': [85],
    },
    {
      'id': 'stat_82plus',
      'title': '82+ OVR Rating',
      'subtitle': 'Peak Overall Rating',
      'condition': 'overall >= ?',
      'args': [82],
    },
    {
      'id': 'trait_left_foot',
      'title': 'Left-Footed',
      'subtitle': 'Strong Left Foot',
      'condition': "preferred_foot = 'Left'",
      'args': <dynamic>[],
    },
    {
      'id': 'stat_goals_50',
      'title': '50+ Career Goals',
      'subtitle': 'Senior Club & Country',
      'condition': 'career_goals >= ?',
      'args': [50],
    },
    {
      'id': 'stat_apps_100',
      'title': '100+ Appearances',
      'subtitle': 'Career Matches',
      'condition': 'career_appearances >= ?',
      'args': [100],
    },
  ];

  /// Generates a validated, solvable 3x3 Grid with creative & diverse categories
  static Future<GridPuzzle> generateValidGrid([int? seed, Database? dbInstance]) async {
    final rng = Random(seed ?? DateTime.now().millisecondsSinceEpoch);
    final db = dbInstance ?? await DatabaseService.instance.database;

    // Try up to 20 candidate combinations until all 9 intersections have >= 3 valid answers
    for (int attempt = 0; attempt < 20; attempt++) {
      final shuffledClubs = List<Map<String, String>>.from(clubPool)..shuffle(rng);
      final shuffledNations = List<String>.from(nationPool)..shuffle(rng);
      final shuffledPositions = List<Map<String, String>>.from(positionPool)..shuffle(rng);
      final shuffledTraits = List<Map<String, dynamic>>.from(traitPool)..shuffle(rng);

      final club1 = shuffledClubs[0];
      final club2 = shuffledClubs[1];
      final traitRow = shuffledTraits[0];

      final nationCol = shuffledNations[0];
      final posCol = shuffledPositions[0];
      final traitCol = shuffledTraits[1];

      final rowCats = [
        GridCategory(
          id: 'club_${club1['code']}',
          title: club1['name']!,
          subtitle: 'Played for Club',
          sqlCondition: 'team_name LIKE ?',
          sqlArgs: ['%${club1['name']}%'],
        ),
        GridCategory(
          id: 'club_${club2['code']}',
          title: club2['name']!,
          subtitle: 'Played for Club',
          sqlCondition: 'team_name LIKE ?',
          sqlArgs: ['%${club2['name']}%'],
        ),
        GridCategory(
          id: traitRow['id'] as String,
          title: traitRow['title'] as String,
          subtitle: traitRow['subtitle'] as String,
          sqlCondition: traitRow['condition'] as String,
          sqlArgs: List<dynamic>.from(traitRow['args'] as List),
        ),
      ];

      final colCats = [
        GridCategory(
          id: 'nation_$nationCol',
          title: nationCol,
          subtitle: 'Nationality',
          sqlCondition: 'nationality = ?',
          sqlArgs: [nationCol],
        ),
        GridCategory(
          id: 'pos_${posCol['pos']}',
          title: posCol['label']!.split(' (').first,
          subtitle: posCol['label']!,
          sqlCondition: posCol['condition']!,
          sqlArgs: const [],
        ),
        GridCategory(
          id: traitCol['id'] as String,
          title: traitCol['title'] as String,
          subtitle: traitCol['subtitle'] as String,
          sqlCondition: traitCol['condition'] as String,
          sqlArgs: List<dynamic>.from(traitCol['args'] as List),
        ),
      ];

      // Validate all 9 cells
      bool allCellsValid = true;
      for (final r in rowCats) {
        for (final c in colCats) {
          final count = await getValidAnswersCount(db, r, c);
          // §5.0 validator requirement: at least N >= 3 valid answers exist
          if (count < 3) {
            allCellsValid = false;
            break;
          }
        }
        if (!allCellsValid) break;
      }

      if (allCellsValid) {
        return GridPuzzle(
          rowCategories: rowCats,
          colCategories: colCats,
          seed: 'grid_${seed ?? attempt}',
        );
      }
    }

    // Fallback known-immaculate grid
    return _buildFallbackGrid();
  }

  static Future<int> getValidAnswersCount(Database db, GridCategory row, GridCategory col) async {
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT p.player_name) as count
      FROM players p
      WHERE p.player_name IN (SELECT player_name FROM players WHERE ${row.sqlCondition})
        AND p.player_name IN (SELECT player_name FROM players WHERE ${col.sqlCondition})
    ''', [...row.sqlArgs, ...col.sqlArgs]);

    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  /// Check if a player satisfies both row and col criteria across their entire career.
  /// Matches player name (case-insensitive) or player ID across all database records.
  static Future<bool> validatePlayerForCell(
    Database db,
    Player player,
    GridCategory row,
    GridCategory col,
  ) async {
    final rowResult = await db.rawQuery('''
      SELECT 1 FROM players
      WHERE (
        player_name = ? 
        OR player_id = ?
        OR LOWER(TRIM(player_name)) = LOWER(TRIM(?))
      ) AND (${row.sqlCondition})
      LIMIT 1
    ''', [player.name, player.playerId, player.name, ...row.sqlArgs]);

    if (rowResult.isEmpty) return false;

    final colResult = await db.rawQuery('''
      SELECT 1 FROM players
      WHERE (
        player_name = ? 
        OR player_id = ?
        OR LOWER(TRIM(player_name)) = LOWER(TRIM(?))
      ) AND (${col.sqlCondition})
      LIMIT 1
    ''', [player.name, player.playerId, player.name, ...col.sqlArgs]);

    return colResult.isNotEmpty;
  }

  /// Get all valid players for a cell to compute rarity
  static Future<List<Player>> getValidAnswersForCell(
    Database db,
    GridCategory row,
    GridCategory col,
  ) async {
    final result = await db.rawQuery('''
      SELECT * FROM players p
      WHERE p.player_name IN (SELECT player_name FROM players WHERE ${row.sqlCondition})
        AND p.player_name IN (SELECT player_name FROM players WHERE ${col.sqlCondition})
      ORDER BY p.overall DESC, p.season DESC
    ''', [...row.sqlArgs, ...col.sqlArgs]);

    final seen = <String>{};
    final validPlayers = <Player>[];
    for (final r in result) {
      final p = Player.fromMap(r);
      if (seen.add(p.name.trim().toLowerCase())) {
        validPlayers.add(p);
      }
    }
    return validPlayers;
  }

  static GridPuzzle _buildFallbackGrid() {
    return GridPuzzle(
      rowCategories: [
        const GridCategory(
          id: 'club_rma',
          title: 'Real Madrid',
          subtitle: 'Played for Club',
          sqlCondition: 'team_name LIKE ?',
          sqlArgs: ['%Real Madrid%'],
        ),
        const GridCategory(
          id: 'club_mun',
          title: 'Manchester United',
          subtitle: 'Played for Club',
          sqlCondition: 'team_name LIKE ?',
          sqlArgs: ['%Manchester United%'],
        ),
        const GridCategory(
          id: 'stat_85plus',
          title: '85+ OVR Rating',
          subtitle: 'Peak Rating',
          sqlCondition: 'overall >= ?',
          sqlArgs: [85],
        ),
      ],
      colCategories: [
        const GridCategory(
          id: 'nation_spain',
          title: 'Spain',
          subtitle: 'Nationality',
          sqlCondition: 'nationality = ?',
          sqlArgs: ['Spain'],
        ),
        const GridCategory(
          id: 'nation_france',
          title: 'France',
          subtitle: 'Nationality',
          sqlCondition: 'nationality = ?',
          sqlArgs: ['France'],
        ),
        const GridCategory(
          id: 'pos_forward',
          title: 'Forward',
          subtitle: 'ST / CF / LW / RW',
          sqlCondition: "primary_position IN ('ST', 'CF', 'LW', 'RW')",
          sqlArgs: [],
        ),
      ],
      seed: 'fallback',
    );
  }
}
