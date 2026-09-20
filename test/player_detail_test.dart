import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchline/core/storage/prefs_service.dart';
import 'package:touchline/domain/models/player.dart';
import 'package:touchline/features/search/player_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testPlayer = Player.fromMap({
    'player_id': '158023',
    'player_name': 'Lionel Messi',
    'overall': 90,
    'primary_position': 'RW',
    'all_positions': 'RW, ST, CF',
    'pace': 80,
    'shooting': 89,
    'passing': 90,
    'dribbling': 92,
    'defending': 35,
    'physicality': 65,
    'team_name': 'Inter Miami',
    'season': 2024,
    'mode': 'EA Sports FC 24',
    'nationality': 'Argentina',
    'preferred_foot': 'Left',
    'height_cm': 170.0,
    'weight_kg': 72.0,
    'career_goals': 820.0,
    'career_assists': 350.0,
    'career_appearances': 1050.0,
    'career_minutes': 85000.0,
    'career_yellows': 85.0,
    'career_reds': 3.0,
  });

  group('PlayerDetailSheet Real-World Stats Visibility (Issue #11)', () {
    testWidgets('Non-Career mode displays Transfermarkt career statistics and catalog identifiers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerDetailSheet(
              player: testPlayer,
              isCareerMode: false,
            ),
          ),
        ),
      );

      // Should show real-world career statistics header and counts
      expect(find.text('CAREER STATISTICS (TRANSFERMARKT)'), findsOneWidget);
      expect(find.text('Career Appearances'), findsOneWidget);
      expect(find.text('1050'), findsOneWidget);
      expect(find.text('Career Goals'), findsOneWidget);
      expect(find.text('820'), findsOneWidget);

      // Should show catalog identifiers
      expect(find.text('CATALOG IDENTIFIERS'), findsOneWidget);
      expect(find.text('Player ID'), findsOneWidget);
      expect(find.text('158023'), findsOneWidget);

      // Should NOT show career save specific banner
      expect(find.text('CAREER RECORD (THIS SAVE)'), findsNothing);
    });

    testWidgets('Career mode hides Transfermarkt stats and catalog IDs, showing active save stats', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerDetailSheet(
              player: testPlayer,
              isCareerMode: true,
              careerClubName: 'Ayaan FC',
              careerSeason: 2,
              careerAppearances: 8,
              careerGoals: 5,
            ),
          ),
        ),
      );

      // MUST NOT display real-world Transfermarkt stats in Career Mode
      expect(find.text('CAREER STATISTICS (TRANSFERMARKT)'), findsNothing);
      expect(find.text('1050'), findsNothing);
      expect(find.text('820'), findsNothing);

      // MUST NOT display raw developer catalog identifiers in Career Mode
      expect(find.text('CATALOG IDENTIFIERS'), findsNothing);
      expect(find.text('Player ID'), findsNothing);
      expect(find.text('158023'), findsNothing);

      // MUST display active career save record
      expect(find.text('CAREER RECORD (THIS SAVE)'), findsOneWidget);
      expect(find.text('Matches Played'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Goals Scored'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Ayaan FC • Season 2 (27/28)'), findsOneWidget);
    });

    testWidgets('Career mode displays Clean Sheets for Goalkeepers and Defenders (Issue #8)', (tester) async {
      final gkPlayer = Player.fromMap({
        'player_id': '241671',
        'player_name': 'David Raya',
        'overall': 84,
        'primary_position': 'GK',
        'all_positions': 'GK',
        'pace': 50,
        'shooting': 45,
        'passing': 82,
        'dribbling': 80,
        'defending': 50,
        'physicality': 75,
        'team_name': 'Arsenal',
        'season': 2024,
        'mode': 'EA Sports FC 24',
        'nationality': 'Spain',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerDetailSheet(
              player: gkPlayer,
              isCareerMode: true,
              careerClubName: 'Arsenal',
              careerSeason: 1,
              careerAppearances: 10,
              careerGoals: 0,
              careerCleanSheets: 6,
            ),
          ),
        ),
      );

      expect(find.text('CAREER RECORD (THIS SAVE)'), findsOneWidget);
      expect(find.text('Matches Played'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('Clean Sheets'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('Career mode displays Assists and Average Match Rating when present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerDetailSheet(
              player: testPlayer,
              isCareerMode: true,
              careerClubName: 'Inter Miami',
              careerSeason: 1,
              careerAppearances: 15,
              careerGoals: 12,
              careerAssists: 9,
              careerAverageRating: 8.4,
            ),
          ),
        ),
      );

      expect(find.text('CAREER RECORD (THIS SAVE)'), findsOneWidget);
      expect(find.text('Matches Played'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('Goals Scored'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Assists'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('Average Rating'), findsOneWidget);
      expect(find.text('★ 8.4'), findsOneWidget);
    });
  });

  group('PrefsService Player Career Stats Persistence', () {
    test('PrefsService properly persists and clears active player statistics', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsService.instance;

      final stats = {
        'Bukayo Saka': {'apps': 12, 'goals': 7},
        'Declan Rice': {'apps': 12, 'goals': 2},
      };

      await prefs.saveCareerConfig(
        leagueId: 'premier_league',
        clubName: 'Arsenal',
        clubCode: 'ARS',
        isCustomClub: false,
        squadMode: 'current',
        budget: 90.0,
        season: 1,
        gameweek: 12,
        squadIds: ['Bukayo Saka', 'Declan Rice'],
        playerStats: stats,
      );

      final loaded = await prefs.getCareerConfig();
      expect(loaded, isNotNull);
      final loadedStats = loaded!['playerStats'] as Map<String, Map<String, int>>;
      expect(loadedStats['Bukayo Saka']?['apps'], 12);
      expect(loadedStats['Bukayo Saka']?['goals'], 7);
      expect(loadedStats['Declan Rice']?['apps'], 12);
      expect(loadedStats['Declan Rice']?['goals'], 2);

      await prefs.clearCareerConfig();
      final cleared = await prefs.getCareerConfig();
      expect(cleared, isNull);
    });
  });
}
