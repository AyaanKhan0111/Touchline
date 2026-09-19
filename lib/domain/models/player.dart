/// Domain model representing a football player snapshot from the enriched database.
class Player {
  final String mode;
  final String squadId;
  final String teamCode;
  final String teamName;
  final int season;
  final String playerId;
  final String name;
  final int overall;
  final String displayPosition;
  final String primaryPosition;
  final String allPositions;
  final double? age;
  final double? shirtNumber;
  final int pace;
  final int shooting;
  final int passing;
  final int dribbling;
  final int defending;
  final int physicality;
  final bool isGoalkeeper;
  final double? squadWeight;
  final String? dataSource;
  final String? nationality;
  final String? preferredFoot;
  final double? heightCm;
  final double? weightKg;
  final double? potential;
  final double? weakFoot;
  final double? skillMoves;
  final String? workRate;
  final double? intlReputation;
  final double? careerGoals;
  final double? careerAssists;
  final double? careerAppearances;
  final double? careerYellows;
  final double? careerReds;
  final double? careerMinutes;
  final String? clubCountry;
  final String? competitionName;
  final double? marketValueMillions;

  const Player({
    required this.mode,
    required this.squadId,
    required this.teamCode,
    required this.teamName,
    required this.season,
    required this.playerId,
    required this.name,
    required this.overall,
    required this.displayPosition,
    required this.primaryPosition,
    required this.allPositions,
    this.age,
    this.shirtNumber,
    required this.pace,
    required this.shooting,
    required this.passing,
    required this.dribbling,
    required this.defending,
    required this.physicality,
    required this.isGoalkeeper,
    this.squadWeight,
    this.dataSource,
    this.nationality,
    this.preferredFoot,
    this.heightCm,
    this.weightKg,
    this.potential,
    this.weakFoot,
    this.skillMoves,
    this.workRate,
    this.intlReputation,
    this.careerGoals,
    this.careerAssists,
    this.careerAppearances,
    this.careerYellows,
    this.careerReds,
    this.careerMinutes,
    this.clubCountry,
    this.competitionName,
    this.marketValueMillions,
  });

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      mode: map['mode'] as String? ?? '',
      squadId: map['squad_id'] as String? ?? '',
      teamCode: map['team_code'] as String? ?? '',
      teamName: map['team_name'] as String? ?? '',
      season: (map['season'] as num?)?.toInt() ?? 2024,
      playerId: map['player_id']?.toString() ?? '',
      name: map['player_name'] as String? ?? '',
      overall: (map['overall'] as num?)?.toInt() ?? 50,
      displayPosition: map['display_position'] as String? ?? '',
      primaryPosition: map['primary_position'] as String? ?? 'CM',
      allPositions: map['all_positions'] as String? ?? '',
      age: (map['age'] as num?)?.toDouble(),
      shirtNumber: (map['shirt_number'] as num?)?.toDouble(),
      pace: (map['pace'] as num?)?.toInt() ?? 50,
      shooting: (map['shooting'] as num?)?.toInt() ?? 50,
      passing: (map['passing'] as num?)?.toInt() ?? 50,
      dribbling: (map['dribbling'] as num?)?.toInt() ?? 50,
      defending: (map['defending'] as num?)?.toInt() ?? 50,
      physicality: (map['physicality'] as num?)?.toInt() ?? 50,
      isGoalkeeper: map['is_goalkeeper'] == 'Yes' || map['is_goalkeeper'] == 1 || map['is_goalkeeper'] == true,
      squadWeight: (map['squad_weight'] as num?)?.toDouble(),
      dataSource: map['data_source'] as String?,
      nationality: map['nationality'] as String?,
      preferredFoot: map['preferred_foot'] as String?,
      heightCm: (map['height_cm'] as num?)?.toDouble(),
      weightKg: (map['weight_kg'] as num?)?.toDouble(),
      potential: (map['potential'] as num?)?.toDouble(),
      weakFoot: (map['weak_foot'] as num?)?.toDouble(),
      skillMoves: (map['skill_moves'] as num?)?.toDouble(),
      workRate: map['work_rate'] as String?,
      intlReputation: (map['intl_reputation'] as num?)?.toDouble(),
      careerGoals: (map['career_goals'] as num?)?.toDouble(),
      careerAssists: (map['career_assists'] as num?)?.toDouble(),
      careerAppearances: (map['career_appearances'] as num?)?.toDouble(),
      careerYellows: (map['career_yellows'] as num?)?.toDouble(),
      careerReds: (map['career_reds'] as num?)?.toDouble(),
      careerMinutes: (map['career_minutes'] as num?)?.toDouble(),
      clubCountry: map['club_country'] as String?,
      competitionName: map['competition_name'] as String?,
      marketValueMillions: (map['market_value_millions'] as num?)?.toDouble(),
    );
  }

  /// Two-letter monogram initials for safe club/player avatar representation
  String get initials {
    if (name.isEmpty) return '??';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  /// Attribute lookup helper
  int getAttribute(String attr) {
    switch (attr.toUpperCase()) {
      case 'PAC': return pace;
      case 'SHO': return shooting;
      case 'PAS': return passing;
      case 'DRI': return dribbling;
      case 'DEF': return defending;
      case 'PHY': return physicality;
      case 'OVR': return overall;
      default: return overall;
    }
  }

  Player copyWith({
    String? mode,
    String? squadId,
    String? teamCode,
    String? teamName,
    int? season,
    String? playerId,
    String? name,
    int? overall,
    String? displayPosition,
    String? primaryPosition,
    String? allPositions,
    double? age,
    double? shirtNumber,
    int? pace,
    int? shooting,
    int? passing,
    int? dribbling,
    int? defending,
    int? physicality,
    bool? isGoalkeeper,
    double? squadWeight,
    String? dataSource,
    String? nationality,
    String? preferredFoot,
    double? heightCm,
    double? weightKg,
    double? potential,
    double? weakFoot,
    double? skillMoves,
    String? workRate,
    double? intlReputation,
    double? careerGoals,
    double? careerAssists,
    double? careerAppearances,
    double? careerYellows,
    double? careerReds,
    double? careerMinutes,
    String? clubCountry,
    String? competitionName,
    double? marketValueMillions,
  }) {
    return Player(
      mode: mode ?? this.mode,
      squadId: squadId ?? this.squadId,
      teamCode: teamCode ?? this.teamCode,
      teamName: teamName ?? this.teamName,
      season: season ?? this.season,
      playerId: playerId ?? this.playerId,
      name: name ?? this.name,
      overall: overall ?? this.overall,
      displayPosition: displayPosition ?? this.displayPosition,
      primaryPosition: primaryPosition ?? this.primaryPosition,
      allPositions: allPositions ?? this.allPositions,
      age: age ?? this.age,
      shirtNumber: shirtNumber ?? this.shirtNumber,
      pace: pace ?? this.pace,
      shooting: shooting ?? this.shooting,
      passing: passing ?? this.passing,
      dribbling: dribbling ?? this.dribbling,
      defending: defending ?? this.defending,
      physicality: physicality ?? this.physicality,
      isGoalkeeper: isGoalkeeper ?? this.isGoalkeeper,
      squadWeight: squadWeight ?? this.squadWeight,
      dataSource: dataSource ?? this.dataSource,
      nationality: nationality ?? this.nationality,
      preferredFoot: preferredFoot ?? this.preferredFoot,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      potential: potential ?? this.potential,
      weakFoot: weakFoot ?? this.weakFoot,
      skillMoves: skillMoves ?? this.skillMoves,
      workRate: workRate ?? this.workRate,
      intlReputation: intlReputation ?? this.intlReputation,
      careerGoals: careerGoals ?? this.careerGoals,
      careerAssists: careerAssists ?? this.careerAssists,
      careerAppearances: careerAppearances ?? this.careerAppearances,
      careerYellows: careerYellows ?? this.careerYellows,
      careerReds: careerReds ?? this.careerReds,
      careerMinutes: careerMinutes ?? this.careerMinutes,
      clubCountry: clubCountry ?? this.clubCountry,
      competitionName: competitionName ?? this.competitionName,
      marketValueMillions: marketValueMillions ?? this.marketValueMillions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mode': mode,
      'squad_id': squadId,
      'team_code': teamCode,
      'team_name': teamName,
      'season': season,
      'player_id': playerId,
      'player_name': name,
      'overall': overall,
      'display_position': displayPosition,
      'primary_position': primaryPosition,
      'all_positions': allPositions,
      'age': age,
      'shirt_number': shirtNumber,
      'pace': pace,
      'shooting': shooting,
      'passing': passing,
      'dribbling': dribbling,
      'defending': defending,
      'physicality': physicality,
      'is_goalkeeper': isGoalkeeper ? 1 : 0,
      'squad_weight': squadWeight,
      'data_source': dataSource,
      'nationality': nationality,
      'preferred_foot': preferredFoot,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'potential': potential,
      'weak_foot': weakFoot,
      'skill_moves': skillMoves,
      'work_rate': workRate,
      'intl_reputation': intlReputation,
      'career_goals': careerGoals,
      'career_assists': careerAssists,
      'career_appearances': careerAppearances,
      'career_yellows': careerYellows,
      'career_reds': careerReds,
      'career_minutes': careerMinutes,
      'club_country': clubCountry,
      'competition_name': competitionName,
      'market_value_millions': marketValueMillions,
    };
  }
}
