import 'dart:math';
import '../models/player.dart';
import '../models/transfer_offer.dart';

/// Engine managing inbound AI club transfer offers, bidding valuations, and club financial tiers.
class TransferOfferService {
  /// Tier 1: Global Mega Clubs with unlimited financial muscle.
  /// The ONLY clubs capable of signing 85+ world-class superstars (e.g. Cristiano Ronaldo, Mbappé, Haaland).
  static const List<String> kTier1Clubs = [
    'Real Madrid',
    'Manchester City',
    'Bayern Munich',
    'Paris Saint-Germain',
    'Barcelona',
    'Arsenal',
    'Liverpool',
  ];

  /// Tier 2: Continental Powerhouses and domestic heavyweights.
  /// Approach 78–84 rated starters and top prospects.
  static const List<String> kTier2Clubs = [
    'Chelsea',
    'Manchester United',
    'Atlético Madrid',
    'Inter Milan',
    'Juventus',
    'Borussia Dortmund',
    'Bayer Leverkusen',
    'AC Milan',
    'Napoli',
    'Tottenham Hotspur',
    'Newcastle United',
    'Aston Villa',
  ];

  /// Tier 3: Established Top-Flight Mid-Table clubs.
  /// Target 73–80 rated players; cannot afford 85+ superstars.
  static const List<String> kTier3Clubs = [
    'West Ham United',
    'Brighton & Hove Albion',
    'Everton',
    'Crystal Palace',
    'Fulham',
    'Wolverhampton Wanderers',
    'Sporting CP',
    'Sevilla',
    'Benfica',
    'Ajax',
  ];

  /// Tier 4: Developmental, Championship, or relegation-battling clubs.
  /// Target 68–75 rated squad players; strictly cannot afford elite superstars like Cristiano Ronaldo.
  static const List<String> kTier4Clubs = [
    'Brentford',
    'AFC Bournemouth',
    'Nottingham Forest',
    'Leicester City',
    'Ipswich Town',
    'Southampton',
    'Leeds United',
    'Burnley',
    'Sunderland',
  ];

  /// Returns true if the club has the financial caliber and prestige to bid for the given player.
  static bool canClubApproachPlayer({
    required String club,
    required Player player,
    required String userClub,
  }) {
    if (club.trim().toLowerCase() == userClub.trim().toLowerCase()) return false;

    final ovr = player.overall;

    if (ovr >= 85) {
      // 85+ Superstars (Ronaldo, Haaland, etc.): strictly Tier 1 mega clubs only
      return kTier1Clubs.contains(club);
    } else if (ovr >= 80) {
      // 80–84 High-Caliber Starters: Tier 1 and Tier 2 clubs only
      return kTier1Clubs.contains(club) || kTier2Clubs.contains(club);
    } else if (ovr >= 74) {
      // 74–79 Solid Squad Players: Tier 2, Tier 3, and Tier 4 clubs
      return kTier2Clubs.contains(club) || kTier3Clubs.contains(club) || kTier4Clubs.contains(club);
    } else {
      // < 74 Emerging / Fringe / Rotation: Tier 3 and Tier 4 clubs
      return kTier3Clubs.contains(club) || kTier4Clubs.contains(club);
    }
  }

  /// Returns the human-readable financial tier label for a buying club.
  static String getClubTierLabel(String club) {
    if (kTier1Clubs.contains(club)) return 'Tier 1 (Elite Mega Club)';
    if (kTier2Clubs.contains(club)) return 'Tier 2 (Continental Heavyweight)';
    if (kTier3Clubs.contains(club)) return 'Tier 3 (Established Mid-Table)';
    return 'Tier 4 (Championship / Developing)';
  }

  /// Returns eligible bidding clubs for a given player, excluding the user's club.
  static List<String> getEligibleClubsForPlayer({
    required Player player,
    required String userClub,
  }) {
    final ovr = player.overall;
    final candidates = <String>[];

    if (ovr >= 85) {
      candidates.addAll(kTier1Clubs);
    } else if (ovr >= 80) {
      candidates.addAll(kTier1Clubs);
      candidates.addAll(kTier2Clubs);
    } else if (ovr >= 74) {
      candidates.addAll(kTier2Clubs);
      candidates.addAll(kTier3Clubs);
      candidates.addAll(kTier4Clubs);
    } else {
      candidates.addAll(kTier3Clubs);
      candidates.addAll(kTier4Clubs);
    }

    final normalizedUser = userClub.trim().toLowerCase();
    return candidates.where((c) => c.trim().toLowerCase() != normalizedUser).toList();
  }

  /// Generates a realistic inbound transfer offer for a player.
  /// Bids are mostly higher than market value (1.05x to 1.35x) with competitive premiums.
  static TransferOffer? generateOfferForPlayer({
    required Player player,
    required double playerMarketValue,
    required String userClub,
    required int season,
    required int gameweek,
    Random? rng,
  }) {
    final random = rng ?? Random();
    final eligibleClubs = getEligibleClubsForPlayer(player: player, userClub: userClub);
    if (eligibleClubs.isEmpty) return null;

    final buyingClub = eligibleClubs[random.nextInt(eligibleClubs.length)];
    final tierLabel = getClubTierLabel(buyingClub);

    // Multiplier: mostly higher than player market value (+5% to +35%)
    double multiplier;
    if (player.overall >= 85) {
      // Mega clubs willing to pay 1.12x to 1.35x for world-class match-winners
      multiplier = 1.12 + random.nextDouble() * 0.23;
    } else if (player.age != null && player.age! <= 22 && (player.potential ?? 0) >= 85) {
      // High-potential youth prospect premium (+15% to +35%)
      multiplier = 1.15 + random.nextDouble() * 0.20;
    } else {
      // Standard bidding premium (+5% to +25%)
      multiplier = 1.05 + random.nextDouble() * 0.20;
    }

    final offeredFee = double.parse((max(1.0, playerMarketValue * multiplier)).toStringAsFixed(1));

    return TransferOffer(
      id: 'offer_${season}_${gameweek}_${player.name.replaceAll(' ', '_')}_${random.nextInt(9999)}',
      playerName: player.name,
      playerPosition: player.primaryPosition,
      playerOverall: player.overall,
      playerAge: player.age?.round() ?? 25,
      buyingClub: buyingClub,
      buyingClubTier: tierLabel,
      playerMarketValue: playerMarketValue,
      offeredFeeMillions: offeredFee,
      season: season,
      gameweek: gameweek,
      status: 'pending',
      date: DateTime.now(),
    );
  }

  /// Periodically evaluates whether an inbound transfer bid arrives during an open transfer window.
  static List<TransferOffer> evaluateMatchdayInboundBids({
    required List<Player> userSquad,
    required String userClub,
    required int season,
    required int gameweek,
    required bool isWindowOpen,
    required List<TransferOffer> currentPendingOffers,
    required double Function(Player) valuationCalculator,
    Random? rng,
  }) {
    if (!isWindowOpen || userSquad.isEmpty) return [];
    if (currentPendingOffers.length >= 3) return []; // Maximum 3 concurrent active pending bids

    final random = rng ?? Random();

    // 40% chance of receiving an inbound offer per matchday during an open transfer window
    if (random.nextDouble() > 0.40) return [];

    // Filter squad players who do not already have an active pending offer
    final pendingNames = currentPendingOffers.map((o) => o.playerName.trim().toLowerCase()).toSet();
    final eligiblePlayers = userSquad
        .where((p) => !pendingNames.contains(p.name.trim().toLowerCase()))
        .toList();

    if (eligiblePlayers.isEmpty) return [];

    // Weight candidate selection: stars (OVR >= 80) and young talents (Age <= 23) get scouted more actively
    eligiblePlayers.sort((a, b) {
      final aWeight = a.overall + ((a.age != null && a.age! <= 23) ? 5 : 0);
      final bWeight = b.overall + ((b.age != null && b.age! <= 23) ? 5 : 0);
      return bWeight.compareTo(aWeight);
    });

    // Pick from top candidates
    final candidatePool = eligiblePlayers.take(min(6, eligiblePlayers.length)).toList();
    final chosenPlayer = candidatePool[random.nextInt(candidatePool.length)];

    final valuation = valuationCalculator(chosenPlayer);
    final offer = generateOfferForPlayer(
      player: chosenPlayer,
      playerMarketValue: valuation,
      userClub: userClub,
      season: season,
      gameweek: gameweek,
      rng: random,
    );

    if (offer != null) {
      return [offer];
    }
    return [];
  }
}
