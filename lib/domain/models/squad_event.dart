import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';

/// Enum distinguishing the nature of a squad unavailability event (Fix 29 / User Fix 7)
enum SquadEventType {
  injury,
  suspension,
  personalLeave,
  internationalDuty,
  fatigue;

  String get key {
    switch (this) {
      case SquadEventType.injury:
        return 'injury';
      case SquadEventType.suspension:
        return 'suspension';
      case SquadEventType.personalLeave:
        return 'personal_leave';
      case SquadEventType.internationalDuty:
        return 'international_duty';
      case SquadEventType.fatigue:
        return 'fatigue';
    }
  }

  static SquadEventType fromKey(String key) {
    switch (key) {
      case 'suspension':
        return SquadEventType.suspension;
      case 'fatigue':
        return SquadEventType.fatigue;
      case 'personal_leave':
        return SquadEventType.personalLeave;
      case 'international_duty':
        return SquadEventType.internationalDuty;
      case 'injury':
      default:
        return SquadEventType.injury;
    }
  }
}

/// Domain model encapsulating a dynamic squad unavailability event (injuries, suspensions, leave, international duty, fatigue)
class SquadEvent {
  final String id;
  final String playerName;
  final SquadEventType type;
  final String title;
  final String description;
  final int durationGameweeks;
  final int remainingGameweeks;
  final int startGameweek;
  final int startSeason;
  final String severity; // 'minor', 'mild', 'moderate', 'severe', 'critical'
  final int estimatedDays;
  final DateTime date;

  const SquadEvent({
    required this.id,
    required this.playerName,
    required this.type,
    required this.title,
    required this.description,
    required this.durationGameweeks,
    required this.remainingGameweeks,
    required this.startGameweek,
    required this.startSeason,
    this.severity = 'moderate',
    this.estimatedDays = 7,
    required this.date,
  });

  String get typeKey => type.key;

  bool get isResolved => remainingGameweeks <= 0;

  int get daysRemaining => estimatedDays > 0 ? estimatedDays : (remainingGameweeks * 7);

  String get formattedTimeline {
    final matchesText = '$remainingGameweeks ${remainingGameweeks == 1 ? "match" : "matches"}';
    final days = daysRemaining;
    if (days >= 45) {
      final months = (days / 30).round();
      return '$matchesText (~$months ${months == 1 ? "month" : "months"})';
    }
    return '$matchesText (~$days days)';
  }

  String get badgeLabel {
    final gws = '$remainingGameweeks ${remainingGameweeks == 1 ? "GW" : "GWs"}';
    switch (type) {
      case SquadEventType.injury:
        return 'INJURED ($gws)';
      case SquadEventType.suspension:
        return 'SUSPENDED ($gws)';
      case SquadEventType.personalLeave:
        return 'ON LEAVE ($gws)';
      case SquadEventType.internationalDuty:
        return 'INT DUTY ($gws)';
      case SquadEventType.fatigue:
        return 'RESTED ($gws)';
    }
  }

  Color get badgeColor {
    switch (type) {
      case SquadEventType.injury:
        return AppPalette.coral;
      case SquadEventType.suspension:
        return AppPalette.red;
      case SquadEventType.personalLeave:
        return Colors.purpleAccent;
      case SquadEventType.internationalDuty:
        return Colors.orangeAccent;
      case SquadEventType.fatigue:
        return Colors.tealAccent;
    }
  }

  IconData get iconData {
    switch (type) {
      case SquadEventType.injury:
        return Icons.medical_services_rounded;
      case SquadEventType.suspension:
        return Icons.front_hand_rounded;
      case SquadEventType.personalLeave:
        return Icons.family_restroom_rounded;
      case SquadEventType.internationalDuty:
        return Icons.flight_takeoff_rounded;
      case SquadEventType.fatigue:
        return Icons.battery_alert_rounded;
    }
  }

  SquadEvent copyWith({
    String? id,
    String? playerName,
    SquadEventType? type,
    String? title,
    String? description,
    int? durationGameweeks,
    int? remainingGameweeks,
    int? startGameweek,
    int? startSeason,
    String? severity,
    int? estimatedDays,
    DateTime? date,
  }) {
    return SquadEvent(
      id: id ?? this.id,
      playerName: playerName ?? this.playerName,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      durationGameweeks: durationGameweeks ?? this.durationGameweeks,
      remainingGameweeks: remainingGameweeks ?? this.remainingGameweeks,
      startGameweek: startGameweek ?? this.startGameweek,
      startSeason: startSeason ?? this.startSeason,
      severity: severity ?? this.severity,
      estimatedDays: estimatedDays ?? this.estimatedDays,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'playerName': playerName,
      'type': type.key,
      'title': title,
      'description': description,
      'durationGameweeks': durationGameweeks,
      'remainingGameweeks': remainingGameweeks,
      'startGameweek': startGameweek,
      'startSeason': startSeason,
      'severity': severity,
      'estimatedDays': estimatedDays,
      'date': date.toIso8601String(),
    };
  }

  factory SquadEvent.fromMap(Map<String, dynamic> map) {
    final remaining = (map['remainingGameweeks'] as num?)?.toInt() ?? 1;
    return SquadEvent(
      id: map['id'] as String? ?? 'event_${DateTime.now().millisecondsSinceEpoch}',
      playerName: map['playerName'] as String? ?? '',
      type: SquadEventType.fromKey(map['type'] as String? ?? 'injury'),
      title: map['title'] as String? ?? 'Squad Event',
      description: map['description'] as String? ?? '',
      durationGameweeks: (map['durationGameweeks'] as num?)?.toInt() ?? 1,
      remainingGameweeks: remaining,
      startGameweek: (map['startGameweek'] as num?)?.toInt() ?? 1,
      startSeason: (map['startSeason'] as num?)?.toInt() ?? 1,
      severity: map['severity'] as String? ?? 'moderate',
      estimatedDays: (map['estimatedDays'] as num?)?.toInt() ?? (remaining * 7),
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
