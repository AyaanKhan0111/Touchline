import 'package:flutter/material.dart';

/// Domain model representing a team squad snapshot.
class Team {
  final String mode;
  final String squadId;
  final String teamCode;
  final String teamName;
  final int season;
  final double? squadWeight;
  final int totalPlayers;
  final double avgOvr;
  final String? topStar;
  final int gkCount;
  final int defCount;
  final int midCount;
  final int fwdCount;
  final String? primaryColorHex;
  final String? secondaryColorHex;
  final String? clubCountry;

  const Team({
    required this.mode,
    required this.squadId,
    required this.teamCode,
    required this.teamName,
    required this.season,
    this.squadWeight,
    required this.totalPlayers,
    required this.avgOvr,
    this.topStar,
    required this.gkCount,
    required this.defCount,
    required this.midCount,
    required this.fwdCount,
    this.primaryColorHex,
    this.secondaryColorHex,
    this.clubCountry,
  });

  factory Team.fromMap(Map<String, dynamic> map) {
    return Team(
      mode: map['mode'] as String? ?? '',
      squadId: map['squad_id'] as String? ?? '',
      teamCode: map['team_code'] as String? ?? '',
      teamName: map['team_name'] as String? ?? '',
      season: (map['season'] as num?)?.toInt() ?? 2024,
      squadWeight: (map['squad_weight'] as num?)?.toDouble(),
      totalPlayers: (map['total_players'] as num?)?.toInt() ?? 0,
      avgOvr: (map['avg_ovr'] as num?)?.toDouble() ?? 70.0,
      topStar: map['top_star'] as String?,
      gkCount: (map['gk_count'] as num?)?.toInt() ?? 0,
      defCount: (map['def_count'] as num?)?.toInt() ?? 0,
      midCount: (map['mid_count'] as num?)?.toInt() ?? 0,
      fwdCount: (map['fwd_count'] as num?)?.toInt() ?? 0,
      primaryColorHex: map['primary_color'] as String?,
      secondaryColorHex: map['secondary_color'] as String?,
      clubCountry: map['club_country'] as String?,
    );
  }

  /// Two-letter monogram code for club badge
  String get monogram {
    if (teamCode.isNotEmpty && teamCode.length <= 3) {
      return teamCode.substring(0, teamCode.length >= 2 ? 2 : 1).toUpperCase();
    }
    final words = teamName.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return teamName.substring(0, 2).toUpperCase();
  }

  Color get primaryColor {
    return _parseColor(primaryColorHex, const Color(0xFF1F6F4A));
  }

  Color get secondaryColor {
    return _parseColor(secondaryColorHex, const Color(0xFFFFFFFF));
  }

  static Color _parseColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      if (val != null) return Color(val);
    }
    return fallback;
  }
}
