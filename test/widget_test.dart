import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/core/theme/app_palette.dart';
import 'package:touchline/domain/models/mode_requirements.dart';
import 'package:touchline/domain/models/player.dart';
import 'package:touchline/domain/models/team.dart';

void main() {
  group('Touchline Domain & Theme Tests', () {
    test('AppPalette tonal steps and rating colors', () {
      expect(AppPalette.ratingColor(91), AppPalette.positive);
      expect(AppPalette.ratingColor(85), AppPalette.positive);
      expect(AppPalette.ratingColor(70), AppPalette.warn);
      expect(AppPalette.ratingColor(55), AppPalette.negative);
    });

    test('ModeRequirements specification completeness', () {
      expect(ModeRequirements.allModes.length, 21);
      final goModes = ModeRequirements.allModes.where((m) => m.defaultStatus == ModeStatus.go);
      final improvedModes = ModeRequirements.allModes.where((m) => m.defaultStatus == ModeStatus.improved);
      final deferredModes = ModeRequirements.allModes.where((m) => m.defaultStatus == ModeStatus.defer);

      expect(goModes.length, greaterThanOrEqualTo(8));
      expect(improvedModes.length, greaterThanOrEqualTo(7));
      expect(deferredModes.length, 1); // Retro Rewind only
    });

    test('Player model instantiation and initials generation', () {
      final player = Player.fromMap({
        'mode': 'Premier League',
        'squad_id': 'MUN|2015',
        'team_code': 'MUN',
        'team_name': 'Manchester United',
        'season': 2015,
        'player_id': '20801',
        'player_name': 'Cristiano Ronaldo',
        'overall': 92,
        'display_position': 'LW',
        'primary_position': 'LW',
        'all_positions': 'LW, ST',
        'age': 30.0,
        'pace': 92,
        'shooting': 93,
        'passing': 81,
        'dribbling': 91,
        'defending': 33,
        'physicality': 79,
        'is_goalkeeper': 'No',
        'nationality': 'Portugal',
        'preferred_foot': 'Right',
        'career_goals': 750.0,
      });

      expect(player.name, 'Cristiano Ronaldo');
      expect(player.initials, 'CR');
      expect(player.getAttribute('PAC'), 92);
      expect(player.getAttribute('SHO'), 93);
      expect(player.careerGoals, 750.0);
    });

    test('Team model monogram and colors', () {
      final team = Team.fromMap({
        'mode': 'Premier League',
        'squad_id': 'ARS|2024',
        'team_code': 'ARS',
        'team_name': 'Arsenal',
        'season': 2024,
        'total_players': 25,
        'avg_ovr': 83.5,
        'top_star': 'B. Saka',
        'gk_count': 3,
        'def_count': 8,
        'mid_count': 8,
        'fwd_count': 6,
        'primary_color': '#EF0107',
        'secondary_color': '#FFFFFF',
        'club_country': 'England',
      });

      expect(team.monogram, 'AR');
      expect(team.primaryColor.toARGB32(), 0xFFEF0107);
    });
  });
}
