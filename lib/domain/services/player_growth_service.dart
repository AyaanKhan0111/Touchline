import 'dart:math';
import '../models/player.dart';

/// Encapsulates the evaluation result of a player's growth or decline over a campaign.
class PlayerGrowthResult {
  final Player player;
  final int oldOverall;
  final int newOverall;
  final int delta;
  final int oldAge;
  final int newAge;
  final String statusLabel;
  final String statusDescription;

  const PlayerGrowthResult({
    required this.player,
    required this.oldOverall,
    required this.newOverall,
    required this.delta,
    required this.oldAge,
    required this.newAge,
    required this.statusLabel,
    required this.statusDescription,
  });

  bool get isGrowth => delta > 0;
  bool get isDecline => delta < 0;
  bool get isUnchanged => delta == 0;
}

/// Service managing dynamic player development, form momentum, and age-related decline.
class PlayerGrowthService {
  /// Strict rule: natural physical/athletic decline starts at age 33.
  static const int kDeclineAge = 33;

  /// Realistic ceiling: no player ever reaches 99 unrealistically.
  static const int kMaxAllowedOverall = 94;

  /// Quality floor: aging legends do not drop below respectable professional baseline.
  static const int kMinAllowedOverall = 68;

  /// Calculates end-of-season rating progression and age advancement for a player.
  static PlayerGrowthResult processSeasonGrowth({
    required Player player,
    required int appearances,
    required double averageRating,
    required int goals,
    required int assists,
    required int cleanSheets,
  }) {
    final oldOvr = player.overall;
    final oldAge = (player.age ?? 24.0).round();
    final newAge = oldAge + 1;

    // Potential ceiling from FIFA database (or slightly above current if null)
    final dbPotential = (player.potential ?? (oldOvr + 2.0)).round();
    final effectivePotential = min(dbPotential, kMaxAllowedOverall);
    final headroom = max(0, effectivePotential - oldOvr);

    int delta = 0;
    String label = 'STABLE';
    String description = 'Maintained current performance level.';

    if (oldAge >= kDeclineAge) {
      // -------------------------------------------------------------
      // Case 1: Veteran Age 33+ (Strict Natural Physical Decline)
      // -------------------------------------------------------------
      if (appearances >= 12 && averageRating >= 7.3) {
        // Outstanding veteran campaign softens natural decline
        delta = -1;
        label = 'MANAGED DECLINE (33+)';
        description = 'Exceptional leadership & form mitigated natural age decline.';
      } else if (appearances >= 6 && averageRating >= 6.6) {
        // Standard expected decline
        delta = -2;
        label = 'AGE DECLINE (33+)';
        description = 'Natural physical & pace deterioration at age $oldAge.';
      } else {
        // Low playing time or poor form accelerates veteran decline
        delta = oldAge >= 35 ? -3 : -2;
        label = 'ACCELERATED DECLINE (33+)';
        description = 'Limited match fitness and age contributed to rating drop.';
      }
    } else if (oldAge <= 23) {
      // -------------------------------------------------------------
      // Case 2: Young Prodigy / Developing Star (Age <= 23)
      // -------------------------------------------------------------
      if (headroom <= 0) {
        // Strictly capped by potential ceiling
        delta = 0;
        label = 'POTENTIAL REACHED';
        description = 'Player has fulfilled their scouted potential.';
      } else {
        // Has development headroom towards FIFA potential
        final isExcellent = (appearances >= 10 && averageRating >= 7.0) ||
            goals >= 8 ||
            assists >= 6 ||
            cleanSheets >= 5;

        final isGood = appearances >= 5 || averageRating >= 6.4;

        if (isExcellent) {
          // Rapid, breakout development (+2 to +4, capped by potential & 94)
          final bonus = (headroom >= 4 ? 1 : 0) + (averageRating >= 7.4 ? 1 : 0);
          delta = min(headroom, min(4, 2 + bonus));
          label = delta >= 3 ? 'EXPLOSIVE GROWTH' : 'SOLID PROGRESS';
          description = 'Breakout campaign driving rapid technical & tactical maturation.';
        } else if (isGood) {
          // Steady growth (+1 to +2)
          final bonus = headroom >= 3 ? 1 : 0;
          delta = min(headroom, min(2, 1 + bonus));
          label = 'DEVELOPING';
          description = 'Consistent match exposure aided regular development.';
        } else {
          // Minimal playing time or poor form (+0 to +1)
          delta = min(headroom, appearances > 0 ? 1 : 0);
          label = 'MODEST DEVELOPMENT';
          description = 'Limited playing time tempered potential progress.';
        }
      }
    } else if (oldAge <= 27) {
      // -------------------------------------------------------------
      // Case 3: Maturing Contender (Age 24–27)
      // -------------------------------------------------------------
      if (headroom > 0) {
        if (appearances >= 10 && averageRating >= 7.0) {
          delta = min(headroom, 2);
          label = 'APPROACHING PEAK';
          description = 'Strong season propelling player towards career prime.';
        } else if (appearances >= 5) {
          delta = min(headroom, 1);
          label = 'STEADY PRIME';
          description = 'Solid season with continued refinement.';
        } else {
          delta = 0;
          label = 'PRIME STABLE';
          description = 'Established player with stable attributes.';
        }
      } else {
        delta = (appearances >= 15 && averageRating >= 7.6 && oldOvr < kMaxAllowedOverall) ? 1 : 0;
        label = 'PEAK PRIME';
        description = 'Operating in peak athletic and tactical prime.';
      }
    } else {
      // -------------------------------------------------------------
      // Case 4: Peak Maturity (Age 28–32)
      // -------------------------------------------------------------
      if (appearances >= 15 && averageRating >= 7.6 && oldOvr < kMaxAllowedOverall) {
        delta = 1;
        label = 'WORLD-CLASS PRIME';
        description = 'Career-defining season leading to peak rating bump.';
      } else if (appearances >= 10 && averageRating < 5.8) {
        delta = -1;
        label = 'OUT OF FORM';
        description = 'Challenging season led to slight rating regression.';
      } else {
        delta = 0;
        label = 'PEAK PRIME';
        description = 'Established senior in prime career window.';
      }
    }

    // Apply strict bounds: Never exceed 94, never exceed potential (unless prime bonus), never fall below floor
    final rawNewOvr = oldOvr + delta;
    final boundedNewOvr = min(kMaxAllowedOverall, max(kMinAllowedOverall, rawNewOvr));
    final trueDelta = boundedNewOvr - oldOvr;

    // Proportionally adjust core attributes (Pace, Shooting, Passing, Dribbling, Defending, Physicality)
    final paceDelta = oldAge >= kDeclineAge ? (trueDelta < 0 ? -1 : 0) : (trueDelta > 0 ? 1 : 0);
    final technicalDelta = trueDelta;

    final updatedPlayer = player.copyWith(
      overall: boundedNewOvr,
      age: newAge.toDouble(),
      pace: max(40, min(99, player.pace + paceDelta)),
      shooting: max(40, min(99, player.shooting + technicalDelta)),
      passing: max(40, min(99, player.passing + technicalDelta)),
      dribbling: max(40, min(99, player.dribbling + technicalDelta)),
      defending: max(40, min(99, player.defending + (trueDelta > 0 ? 1 : (trueDelta < 0 ? -1 : 0)))),
      physicality: max(40, min(99, player.physicality + (oldAge >= kDeclineAge ? -1 : (trueDelta > 0 ? 1 : 0)))),
    );

    return PlayerGrowthResult(
      player: updatedPlayer,
      oldOverall: oldOvr,
      newOverall: boundedNewOvr,
      delta: trueDelta,
      oldAge: oldAge,
      newAge: newAge,
      statusLabel: label,
      statusDescription: description,
    );
  }

  /// Returns authentic FIFA potential band description for UI display
  static String getPotentialTierDescription(Player player) {
    final age = (player.age ?? 25.0).round();
    if (age >= kDeclineAge) return 'Experienced Veteran';
    if (age >= 28) return 'At Peak Prime';

    final pot = (player.potential ?? player.overall.toDouble()).round();
    if (pot >= 90) return 'Has Potential to be Special';
    if (pot >= 86) return 'An Exciting Prospect';
    if (pot >= 81) return 'Showing Great Potential';
    return 'Solid Squad Talent';
  }
}
