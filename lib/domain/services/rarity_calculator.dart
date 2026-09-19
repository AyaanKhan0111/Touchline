import 'dart:math';
import '../models/player.dart';

/// Rarity & Popularity Scoring Service
/// Strictly follows Section 5.1 & Section 0.3 of the Build Brief.
class RarityCalculator {
  RarityCalculator._();

  /// Obviousness / Popularity heuristic per §0.3:
  /// (OVR/100)^2 * prestigeFactor * recencyFactor
  static double calculateObviousness(Player player) {
    final ratingFactor = pow(player.overall / 100.0, 2.0).toDouble();

    // League prestige factor
    double prestige = 0.85;
    final mode = player.mode.toLowerCase();
    if (mode.contains('fc 27')) {
      prestige = 1.0;
    } else if (mode.contains('fc 26')) {
      prestige = 0.95;
    } else if (mode.contains('fc 25')) {
      prestige = 0.90;
    } else if (mode.contains('premier league')) {
      prestige = player.season >= 2015 ? 0.88 : 0.70;
    } else if (mode.contains('european')) {
      prestige = player.season >= 2015 ? 0.85 : 0.68;
    } else if (mode.contains('nations cup')) {
      prestige = player.season >= 2006 ? 0.75 : 0.55;
    }

    // Recency factor (more recent = more obvious)
    final year = player.season;
    final recency = ((year - 1966) / (2027 - 1966)).clamp(0.4, 1.0);

    // Reputation bonus if available
    final rep = (player.intlReputation ?? 1.0) / 5.0;

    return ratingFactor * prestige * recency * (0.8 + 0.2 * rep);
  }

  /// Calculates rarity score (1 to 100) for a chosen player among a pool of valid answers.
  /// Lower rarity score is better (e.g. 3% vs 65%).
  static int calculateRarityScore(Player chosen, List<Player> validAnswers) {
    if (validAnswers.isEmpty) return 50;
    if (validAnswers.length == 1) return 100;

    final chosenWeight = calculateObviousness(chosen);
    double totalWeight = 0.0;
    for (final p in validAnswers) {
      totalWeight += calculateObviousness(p);
    }

    if (totalWeight <= 0) return 50;

    final share = chosenWeight / totalWeight;
    final score = (share * 100).round();
    return score.clamp(1, 100);
  }

  /// Evaluates Grid total score:
  /// Perfect 9/9 with low rarity = IMMACULATE
  static String getGridVerdict(int correctCount, int totalRarity) {
    if (correctCount < 9) {
      return '$correctCount / 9 COMPLETE';
    }
    if (totalRarity < 80) {
      return 'IMMACULATE (LEGENDARY KNOWLEDGE)';
    }
    if (totalRarity < 200) {
      return 'MASTERMIND';
    }
    if (totalRarity < 400) {
      return 'SOLID GRID';
    }
    return 'POPULAR PICKS';
  }
}
