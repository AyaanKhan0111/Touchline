import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';

/// Enum distinguishing the nature of a squad unavailability event (Fix 29 / User Fix 7)
enum SquadEventType {
  injury,
  personalLeave,
  internationalDuty;

  String get key {
    switch (this) {
      case SquadEventType.injury:
        return 'injury';
      case SquadEventType.personalLeave:
        return 'personal_leave';
      case SquadEventType.internationalDuty:
        return 'international_duty';
    }
  }

  static SquadEventType fromKey(String key) {
    switch (key) {
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

/// Domain model encapsulating a dynamic squad unavailability event (injuries, leave, international duty)
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
  final String severity; // 'mild', 'moderate', 'severe'
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
    required this.date,
  });

  String get typeKey => type.key;

  bool get isResolved => remainingGameweeks <= 0;

  String get badgeLabel {
    final gws = '$remainingGameweeks ${remainingGameweeks == 1 ? "GW" : "GWs"}';
    switch (type) {
      case SquadEventType.injury:
        return 'INJURED ($gws)';
      case SquadEventType.personalLeave:
        return 'ON LEAVE ($gws)';
      case SquadEventType.internationalDuty:
        return 'INT DUTY ($gws)';
    }
  }

  Color get badgeColor {
    switch (type) {
      case SquadEventType.injury:
        return AppPalette.coral;
      case SquadEventType.personalLeave:
        return Colors.purpleAccent;
      case SquadEventType.internationalDuty:
        return Colors.orangeAccent;
    }
  }

  IconData get iconData {
    switch (type) {
      case SquadEventType.injury:
        return Icons.medical_services_rounded;
      case SquadEventType.personalLeave:
        return Icons.beach_access_rounded;
      case SquadEventType.internationalDuty:
        return Icons.flight_takeoff_rounded;
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
      'date': date.toIso8601String(),
    };
  }

  factory SquadEvent.fromMap(Map<String, dynamic> map) {
    return SquadEvent(
      id: map['id'] as String? ?? 'event_${DateTime.now().millisecondsSinceEpoch}',
      playerName: map['playerName'] as String? ?? '',
      type: SquadEventType.fromKey(map['type'] as String? ?? 'injury'),
      title: map['title'] as String? ?? 'Squad Event',
      description: map['description'] as String? ?? '',
      durationGameweeks: (map['durationGameweeks'] as num?)?.toInt() ?? 1,
      remainingGameweeks: (map['remainingGameweeks'] as num?)?.toInt() ?? 1,
      startGameweek: (map['startGameweek'] as num?)?.toInt() ?? 1,
      startSeason: (map['startSeason'] as num?)?.toInt() ?? 1,
      severity: map['severity'] as String? ?? 'moderate',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
