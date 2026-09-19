/// Represents an inbound transfer bid received from an AI club for a squad player.
class TransferOffer {
  final String id;
  final String playerName;
  final String playerPosition;
  final int playerOverall;
  final int playerAge;
  final String buyingClub;
  final String buyingClubTier;
  final double playerMarketValue;
  final double offeredFeeMillions;
  final int season;
  final int gameweek;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime date;

  const TransferOffer({
    required this.id,
    required this.playerName,
    required this.playerPosition,
    required this.playerOverall,
    required this.playerAge,
    required this.buyingClub,
    required this.buyingClubTier,
    required this.playerMarketValue,
    required this.offeredFeeMillions,
    required this.season,
    required this.gameweek,
    this.status = 'pending',
    required this.date,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  double get premiumPercent {
    if (playerMarketValue <= 0) return 0.0;
    return ((offeredFeeMillions - playerMarketValue) / playerMarketValue) * 100.0;
  }

  TransferOffer copyWith({
    String? id,
    String? playerName,
    String? playerPosition,
    int? playerOverall,
    int? playerAge,
    String? buyingClub,
    String? buyingClubTier,
    double? playerMarketValue,
    double? offeredFeeMillions,
    int? season,
    int? gameweek,
    String? status,
    DateTime? date,
  }) {
    return TransferOffer(
      id: id ?? this.id,
      playerName: playerName ?? this.playerName,
      playerPosition: playerPosition ?? this.playerPosition,
      playerOverall: playerOverall ?? this.playerOverall,
      playerAge: playerAge ?? this.playerAge,
      buyingClub: buyingClub ?? this.buyingClub,
      buyingClubTier: buyingClubTier ?? this.buyingClubTier,
      playerMarketValue: playerMarketValue ?? this.playerMarketValue,
      offeredFeeMillions: offeredFeeMillions ?? this.offeredFeeMillions,
      season: season ?? this.season,
      gameweek: gameweek ?? this.gameweek,
      status: status ?? this.status,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'playerName': playerName,
    'playerPosition': playerPosition,
    'playerOverall': playerOverall,
    'playerAge': playerAge,
    'buyingClub': buyingClub,
    'buyingClubTier': buyingClubTier,
    'playerMarketValue': playerMarketValue,
    'offeredFeeMillions': offeredFeeMillions,
    'season': season,
    'gameweek': gameweek,
    'status': status,
    'date': date.toIso8601String(),
  };

  factory TransferOffer.fromMap(Map<String, dynamic> map) {
    return TransferOffer(
      id: map['id'] as String? ?? 'offer_${DateTime.now().millisecondsSinceEpoch}',
      playerName: map['playerName'] as String? ?? '',
      playerPosition: map['playerPosition'] as String? ?? 'CM',
      playerOverall: (map['playerOverall'] as num?)?.toInt() ?? 75,
      playerAge: (map['playerAge'] as num?)?.toInt() ?? 25,
      buyingClub: map['buyingClub'] as String? ?? 'Real Madrid',
      buyingClubTier: map['buyingClubTier'] as String? ?? 'Tier 1 (Elite Mega Club)',
      playerMarketValue: (map['playerMarketValue'] as num?)?.toDouble() ?? 10.0,
      offeredFeeMillions: (map['offeredFeeMillions'] as num?)?.toDouble() ?? 12.0,
      season: (map['season'] as num?)?.toInt() ?? 1,
      gameweek: (map['gameweek'] as num?)?.toInt() ?? 1,
      status: map['status'] as String? ?? 'pending',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
