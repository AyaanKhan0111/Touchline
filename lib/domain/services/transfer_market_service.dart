import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../models/player.dart';

/// Represents contract status and remaining seasons for a player (Fix 30 / User Fix 8)
class ContractStatus {
  final int seasonsRemaining;
  final bool isFreeAgent;
  final bool isExpiring;
  final double discountMultiplier;
  final String statusBadge;
  final Color badgeColor;

  const ContractStatus({
    required this.seasonsRemaining,
    required this.isFreeAgent,
    required this.isExpiring,
    required this.discountMultiplier,
    required this.statusBadge,
    required this.badgeColor,
  });

  factory ContractStatus.fromSeasons(int seasons) {
    if (seasons <= 0) {
      return const ContractStatus(
        seasonsRemaining: 0,
        isFreeAgent: true,
        isExpiring: false,
        discountMultiplier: 0.0,
        statusBadge: 'FREE AGENT (£0)',
        badgeColor: AppPalette.green,
      );
    } else if (seasons == 1) {
      return const ContractStatus(
        seasonsRemaining: 1,
        isFreeAgent: false,
        isExpiring: true,
        discountMultiplier: 0.5,
        statusBadge: '1 YR (50% OFF)',
        badgeColor: AppPalette.warn,
      );
    } else {
      return ContractStatus(
        seasonsRemaining: seasons,
        isFreeAgent: false,
        isExpiring: false,
        discountMultiplier: 1.0,
        statusBadge: '$seasons YRS',
        badgeColor: AppPalette.darkInkMuted,
      );
    }
  }
}

/// Result of processing annual contract decrements at season change
class SquadContractTickResult {
  final Map<String, int> updatedContracts;
  final List<Player> remainingSquad;
  final List<Player> departedPlayers;

  const SquadContractTickResult({
    required this.updatedContracts,
    required this.remainingSquad,
    required this.departedPlayers,
  });
}

/// Service managing Transfer Market expansion, contract season counters, Free Agents, and Youth Prospects (Fix 30 / User Fix 8)
class TransferMarketService {
  /// Computes deterministic contract duration for players in the transfer market pool.
  /// Enforces realistic football dynamics (Fix 36):
  /// - High-rated superstars (85+ OVR) are virtually never free agents in season 1.
  /// - As seasons advance, players with expiring contracts may sign a new contract or walk away as free agents.
  /// - Free agents have realistic distributions across tiers and may be picked up by clubs.
  static ContractStatus computePlayerContract(
    String playerName,
    int currentSeason, {
    int? overall,
    double? age,
    String? currentClub,
    int? overrideContractYears,
  }) {
    if (overrideContractYears != null && overrideContractYears > 0) {
      return ContractStatus.fromSeasons(overrideContractYears);
    }

    final hasActiveClub = currentClub != null &&
        currentClub.trim().isNotEmpty &&
        currentClub.trim().toLowerCase() != 'free agent';

    final normName = playerName.trim().toLowerCase();
    final baseSeed = (normName.hashCode.abs() ^ 0x3C6EF35F);
    final roll = baseSeed % 100;
    final ovr = overall ?? 78;
    final pAge = age ?? 26.0;

    // 1. Initial contract duration in Season 1 based on player rating tier and age
    int remaining;
    if (ovr >= 87) {
      if (!hasActiveClub && pAge >= 35 && roll == 99) {
        remaining = 0; // Extremely rare veteran free agent
      } else if (roll < 6) {
        remaining = 1; // 1 Year Expiring Contract (6%)
      } else if (roll < 31) {
        remaining = 2; // 2 Years Contract (25%)
      } else if (roll < 76) {
        remaining = 3; // 3 Years Contract (45%)
      } else {
        remaining = 4; // 4+ Years Contract (24%)
      }
    } else if (ovr >= 83) {
      if (!hasActiveClub && pAge >= 33 && roll < 2) {
        remaining = 0; // Rare veteran free agent (2%)
      } else if (roll < 10) {
        remaining = 1; // 1 Year Expiring (8-10%)
      } else if (roll < 42) {
        remaining = 2; // 2 Years (32%)
      } else if (roll < 82) {
        remaining = 3; // 3 Years (40%)
      } else {
        remaining = 4; // 4+ Years (18%)
      }
    } else if (ovr >= 79) {
      if (!hasActiveClub && roll < 4) {
        remaining = 0; // Free agent (4%)
      } else if (roll < 16) {
        remaining = 1; // 1 Year Expiring (12%)
      } else if (roll < 53) {
        remaining = 2; // 2 Years (37%)
      } else if (roll < 88) {
        remaining = 3; // 3 Years (35%)
      } else {
        remaining = 4; // 4+ Years (12%)
      }
    } else if (ovr >= 74) {
      if (!hasActiveClub && roll < 7) {
        remaining = 0; // Free agent (7%)
      } else if (roll < 24) {
        remaining = 1; // 1 Year Expiring (17%)
      } else if (roll < 65) {
        remaining = 2; // 2 Years (41%)
      } else {
        remaining = 3; // 3 Years (35%)
      }
    } else {
      // Lower tier (< 74 OVR)
      if (!hasActiveClub && roll < 12) {
        remaining = 0; // Free agent (12%)
      } else if (roll < 32) {
        remaining = 1; // 1 Year Expiring (20%)
      } else if (roll < 79) {
        remaining = 2; // 2 Years (47%)
      } else {
        remaining = 3; // 3 Years (21%)
      }
    }

    // 2. Simulate season-by-season progression ("Those with contracts expiring may sign a new contract or may not")
    for (int s = 2; s <= currentSeason; s++) {
      if (remaining == 0) {
        // Player was a Free Agent: May be signed by a club or remain unattached
        final pickupSeed = (baseSeed + s * 4397) % 100;
        final pPickup = ovr >= 85 ? 85 : (ovr >= 80 ? 70 : (ovr >= 74 ? 50 : 35));
        if (pickupSeed < pPickup || hasActiveClub) {
          remaining = ovr >= 80 ? 2 : 1; // Signed a 1-2 year deal
        }
      } else {
        // 1 season elapses
        remaining -= 1;
        if (remaining == 0) {
          // Contract expired! Player may sign a renewal or walk away as a free agent
          final renewSeed = (baseSeed + s * 7919) % 100;
          int pRenew = ovr >= 87 ? 90 : (ovr >= 83 ? 80 : (ovr >= 75 ? 65 : 50));
          if (pAge + s >= 33) {
            pRenew -= 15; // Veterans slightly less likely to renew long-term
          }
          if (renewSeed < pRenew || hasActiveClub) {
            // Signed contract renewal!
            remaining = ovr >= 83 ? 3 : 2;
          } else {
            // Did not sign a new contract -> Free Agent
            remaining = 0;
          }
        }
      }
    }

    // Absolute guarantee: Any player currently owned by an active club has a contract
    if (hasActiveClub && remaining <= 0) {
      remaining = ovr >= 83 ? 3 : 2;
    }

    return ContractStatus.fromSeasons(remaining);
  }

  /// Calculates the effective transfer fee considering free agency (£0) or expiring contract (50% discount).
  static double calculateEffectiveTransferFee({
    required double baseValuation,
    required ContractStatus contractStatus,
  }) {
    if (contractStatus.isFreeAgent) {
      return 0.0;
    }
    if (contractStatus.isExpiring) {
      final discounted = baseValuation * contractStatus.discountMultiplier;
      return double.parse(max(0.5, discounted).toStringAsFixed(1));
    }
    return baseValuation;
  }

  /// Calculates cost to extend/renew a squad player's contract for +3 seasons (e.g. 10% signing loyalty bonus).
  static double calculateContractRenewalCost(double baseValuation) {
    final bonus = (baseValuation * 0.10).clamp(0.5, 12.0);
    return double.parse(bonus.toStringAsFixed(1));
  }

  /// Decrements all player contract counters by 1 season when advancing to next campaign year.
  static Map<String, int> tickSquadContracts(Map<String, int> currentContracts) {
    final updated = <String, int>{};
    currentContracts.forEach((name, seasons) {
      updated[name] = max(0, seasons - 1);
    });
    return updated;
  }

  /// Evaluates contract expiry at season transition:
  /// Decrements all contracts by 1. Players whose contracts reach <= 0 depart as free agents,
  /// with safety guards to preserve at least 11 players and at least 1 goalkeeper.
  static SquadContractTickResult processSeasonContractExpiry({
    required List<Player> squad,
    required Map<String, int> contracts,
  }) {
    final updatedContracts = <String, int>{};
    final departed = <Player>[];
    final remaining = <Player>[];

    // Ensure squad doesn't drop below 11 players and always has at least 1 GK
    int totalGks = squad.where((p) => p.isGoalkeeper || p.primaryPosition == 'GK').length;

    for (final player in squad) {
      final currentContract = contracts[player.name] ?? 3;
      final newContract = currentContract - 1;
      final isGk = player.isGoalkeeper || player.primaryPosition == 'GK';

      if (newContract <= 0) {
        // Check safety rules: cannot release if squad <= 11 or if this is the last GK
        final canDepart = (squad.length - departed.length > 11) && (!isGk || totalGks > 1);
        if (canDepart) {
          departed.add(player);
          if (isGk) totalGks--;
          continue;
        } else {
          // Club auto-extends last resort player on a 1-year emergency contract
          updatedContracts[player.name] = 1;
          remaining.add(player);
          continue;
        }
      }

      updatedContracts[player.name] = newContract;
      remaining.add(player);
    }

    return SquadContractTickResult(
      updatedContracts: updatedContracts,
      remainingSquad: remaining,
      departedPlayers: departed,
    );
  }

  /// Curated pool of scouted high-potential youth academy prospects (wonderkids).
  static List<Player> generateYouthProspects(int season, {Random? rng}) {
    final random = rng ?? Random(season * 997);
    final prospects = <Player>[
      _createProspect('Mateo Rossi', 'ITA', 'Italy', 'ST', 75, 89, 18, random, season),
      _createProspect('Lucas Silva', 'BRA', 'Brazil', 'LW', 74, 91, 19, random, season),
      _createProspect('Jonas Becker', 'GER', 'Germany', 'CM', 73, 88, 18, random, season),
      _createProspect('Marc Delacroix', 'FRA', 'France', 'CB', 76, 90, 20, random, season),
      _createProspect('Oliver Sterling', 'ENG', 'England', 'RW', 75, 89, 19, random, season),
      _createProspect('Alejandro Vega', 'ESP', 'Spain', 'CAM', 76, 92, 19, random, season),
      _createProspect('Noah Van Dijk', 'NED', 'Netherlands', 'CB', 73, 87, 18, random, season),
      _createProspect('Tiago Ramos', 'POR', 'Portugal', 'CDM', 74, 88, 19, random, season),
      _createProspect('Luka Milic', 'CRO', 'Croatia', 'CAM', 72, 87, 18, random, season),
      _createProspect('Mads Lindholm', 'DEN', 'Denmark', 'GK', 74, 89, 20, random, season),
      _createProspect('Gabriel Santana', 'BRA', 'Brazil', 'ST', 76, 91, 19, random, season),
      _createProspect('Arthur Moreau', 'FRA', 'France', 'LB', 73, 86, 18, random, season),
      _createProspect('Ben Campbell', 'ENG', 'England', 'RB', 74, 87, 19, random, season),
      _createProspect('Emil Larsson', 'SWE', 'Sweden', 'ST', 72, 86, 18, random, season),
      _createProspect('Liam O\'Connor', 'IRL', 'Ireland', 'GK', 71, 85, 18, random, season),
    ];
    return prospects;
  }

  static Player _createProspect(
    String name,
    String natCode,
    String nation,
    String position,
    int ovr,
    int pot,
    int age,
    Random rng,
    int season,
  ) {
    final isGk = position == 'GK';
    return Player(
      mode: 'Academy Wonderkids',
      squadId: 'WONDER_${position}_$ovr',
      teamCode: 'FA',
      teamName: 'Youth Academy',
      season: season,
      playerId: 'prospect_${name.replaceAll(" ", "_")}_$ovr',
      name: name,
      overall: ovr,
      displayPosition: position,
      primaryPosition: position,
      allPositions: position,
      age: age.toDouble(),
      potential: pot.toDouble(),
      pace: isGk ? 45 : (75 + rng.nextInt(15)),
      shooting: isGk ? 20 : (position == 'ST' || position == 'LW' || position == 'RW' ? 74 + rng.nextInt(12) : 60 + rng.nextInt(15)),
      passing: isGk ? 60 : (68 + rng.nextInt(15)),
      dribbling: isGk ? 40 : (72 + rng.nextInt(15)),
      defending: isGk ? 30 : (position.contains('B') ? 74 + rng.nextInt(12) : 40 + rng.nextInt(20)),
      physicality: isGk ? 65 : (65 + rng.nextInt(15)),
      isGoalkeeper: isGk,
      nationality: nation,
      preferredFoot: rng.nextBool() ? 'Right' : 'Left',
    );
  }
}
