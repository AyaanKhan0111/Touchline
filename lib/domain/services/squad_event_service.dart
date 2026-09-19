import 'dart:math';
import '../models/player.dart';
import '../models/squad_event.dart';

/// Result container produced when ticking matchday squad events
class SquadEventTickResult {
  final List<SquadEvent> activeEvents;
  final List<SquadEvent> newEvents;
  final List<SquadEvent> recoveredEvents;

  const SquadEventTickResult({
    required this.activeEvents,
    required this.newEvents,
    required this.recoveredEvents,
  });
}

/// Engine managing dynamic squad availability events: injuries, compassionate leave, and international call-ups (Fix 29 / User Fix 7).
class SquadEventService {
  static const int kMaxConcurrentUnavailable = 3;

  static const List<Map<String, dynamic>> _kInjuryCatalog = [
    {
      'title': 'Hamstring Strain',
      'description': 'Sustained during high-intensity training sprint; ruled out by physio.',
      'minGw': 1,
      'maxGw': 3,
      'severity': 'moderate',
    },
    {
      'title': 'Twisted Ankle Sprain',
      'description': 'Suffered a heavy challenge in training match; ankle strapped.',
      'minGw': 1,
      'maxGw': 2,
      'severity': 'mild',
    },
    {
      'title': 'Knee Hyperextension Knock',
      'description': 'Impact injury sustained on the pitch; undergoing rehabilitation.',
      'minGw': 2,
      'maxGw': 3,
      'severity': 'moderate',
    },
    {
      'title': 'Groin Muscle Strain',
      'description': 'Felt discomfort during shooting practice; resting to prevent tear.',
      'minGw': 1,
      'maxGw': 3,
      'severity': 'moderate',
    },
    {
      'title': 'Calf Muscle Tear',
      'description': 'Severe muscular fatigue tear; sidelined under specialist medical care.',
      'minGw': 2,
      'maxGw': 4,
      'severity': 'severe',
    },
    {
      'title': 'Quadriceps Contusion',
      'description': 'Deep dead-leg bruising from impact challenge in training.',
      'minGw': 1,
      'maxGw': 2,
      'severity': 'mild',
    },
  ];

  static const List<Map<String, dynamic>> _kInternationalDutyCatalog = [
    {
      'title': 'World Cup Qualifier Duty',
      'description': 'Called up to senior national squad for competitive international qualifiers.',
      'minGw': 1,
      'maxGw': 2,
    },
    {
      'title': 'Continental Championship Duty',
      'description': 'Traveled overseas to represent national team in continental tournament.',
      'minGw': 1,
      'maxGw': 3,
    },
    {
      'title': 'National Team Friendly Camp',
      'description': 'Selected for international exhibition fixtures and training camp.',
      'minGw': 1,
      'maxGw': 2,
    },
  ];

  static const List<Map<String, dynamic>> _kLeaveCatalog = [
    {
      'title': 'Paternity Leave',
      'description': 'Granted authorized leave to be with family for the birth of a child.',
      'minGw': 1,
      'maxGw': 2,
    },
    {
      'title': 'Compassionate Family Leave',
      'description': 'Manager granted short-term absence to attend to personal family matters.',
      'minGw': 1,
      'maxGw': 2,
    },
    {
      'title': 'Authorized Rest & Recovery',
      'description': 'Given mental fatigue breather by manager following intense fixture congestion.',
      'minGw': 1,
      'maxGw': 1,
    },
  ];

  /// Checks if a player is currently available for selection.
  static bool isPlayerAvailable(String playerName, List<SquadEvent> activeEvents) {
    final norm = playerName.trim().toLowerCase();
    return !activeEvents.any((e) => e.playerName.trim().toLowerCase() == norm && !e.isResolved);
  }

  /// Retrieves the active unavailability event for a player, if any.
  static SquadEvent? getPlayerEvent(String playerName, List<SquadEvent> activeEvents) {
    final norm = playerName.trim().toLowerCase();
    return activeEvents.where((e) => e.playerName.trim().toLowerCase() == norm && !e.isResolved).firstOrNull;
  }

  /// Processes the progression of squad events across matchdays:
  /// - Decrements remaining duration for existing events
  /// - Flags recovered players who return to availability
  /// - Randomly evaluates realistic new injuries, international call-ups, or leave
  static SquadEventTickResult evaluateMatchdaySquadEvents({
    required List<Player> userSquad,
    required int gameweek,
    required int season,
    required int totalGameweeks,
    required List<SquadEvent> currentActiveEvents,
    Random? rng,
  }) {
    final random = rng ?? Random();

    // 1. Progress and resolve existing events
    final List<SquadEvent> updatedActive = [];
    final List<SquadEvent> recovered = [];

    for (final ev in currentActiveEvents) {
      final remaining = ev.remainingGameweeks - 1;
      if (remaining <= 0) {
        recovered.add(ev.copyWith(remainingGameweeks: 0));
      } else {
        updatedActive.add(ev.copyWith(remainingGameweeks: remaining));
      }
    }

    // 2. Evaluate new event generation
    final List<SquadEvent> newEvents = [];

    // Safeguards:
    // - Cap active unavailable players at kMaxConcurrentUnavailable (3)
    // - Minimum squad size of 12 to generate events
    // - ~20% chance of a squad event occurring on any matchday
    final canTriggerNew = updatedActive.length < kMaxConcurrentUnavailable &&
        userSquad.length >= 12 &&
        random.nextDouble() < 0.20;

    if (canTriggerNew) {
      final activeNames = updatedActive.map((e) => e.playerName.trim().toLowerCase()).toSet();

      // Count healthy goalkeepers to ensure we NEVER sideline the last remaining goalkeeper
      final totalGks = userSquad.where((p) => p.isGoalkeeper || p.primaryPosition == 'GK').toList();
      final healthyGks = totalGks.where((p) => !activeNames.contains(p.name.trim().toLowerCase())).toList();
      final protectLastGk = healthyGks.length <= 1;

      final eligibleCandidates = userSquad.where((p) {
        final key = p.name.trim().toLowerCase();
        if (activeNames.contains(key)) return false;
        if (protectLastGk && (p.isGoalkeeper || p.primaryPosition == 'GK')) return false;
        return true;
      }).toList();

      if (eligibleCandidates.isNotEmpty) {
        // Pick a candidate player (starters are under higher physical match load)
        final candidate = eligibleCandidates[random.nextInt(eligibleCandidates.length)];

        // Choose event type: 60% Injury, 25% International Duty, 15% Personal Leave
        final typeRoll = random.nextDouble();
        SquadEventType eventType;
        Map<String, dynamic> eventDetails;
        int duration;

        if (typeRoll < 0.60) {
          eventType = SquadEventType.injury;
          eventDetails = _kInjuryCatalog[random.nextInt(_kInjuryCatalog.length)];
          final minGw = eventDetails['minGw'] as int;
          final maxGw = eventDetails['maxGw'] as int;
          duration = minGw + random.nextInt(maxGw - minGw + 1);
        } else if (typeRoll < 0.85) {
          eventType = SquadEventType.internationalDuty;
          eventDetails = _kInternationalDutyCatalog[random.nextInt(_kInternationalDutyCatalog.length)];
          final minGw = eventDetails['minGw'] as int;
          final maxGw = eventDetails['maxGw'] as int;
          duration = minGw + random.nextInt(maxGw - minGw + 1);
        } else {
          eventType = SquadEventType.personalLeave;
          eventDetails = _kLeaveCatalog[random.nextInt(_kLeaveCatalog.length)];
          final minGw = eventDetails['minGw'] as int;
          final maxGw = eventDetails['maxGw'] as int;
          duration = minGw + random.nextInt(maxGw - minGw + 1);
        }

        final generatedEvent = SquadEvent(
          id: 'squad_event_${season}_${gameweek}_${candidate.name.replaceAll(' ', '_')}_${random.nextInt(9999)}',
          playerName: candidate.name,
          type: eventType,
          title: eventDetails['title'] as String,
          description: eventDetails['description'] as String,
          durationGameweeks: duration,
          remainingGameweeks: duration,
          startGameweek: gameweek,
          startSeason: season,
          severity: eventDetails['severity'] as String? ?? 'moderate',
          date: DateTime.now(),
        );

        newEvents.add(generatedEvent);
        updatedActive.add(generatedEvent);
      }
    }

    return SquadEventTickResult(
      activeEvents: updatedActive,
      newEvents: newEvents,
      recoveredEvents: recovered,
    );
  }

  /// Automatically replaces any unavailable players currently positioned in the Starting XI (indices 0..10)
  /// with the highest-rated available players from the bench/reserves (indices 11+).
  static List<Player> autoReplaceUnavailableStarters({
    required List<Player> squad,
    required List<SquadEvent> activeEvents,
  }) {
    if (squad.length < 11) return squad;

    final updated = List<Player>.from(squad);
    final activeNames = activeEvents.where((e) => !e.isResolved).map((e) => e.playerName.trim().toLowerCase()).toSet();

    for (int i = 0; i < 11; i++) {
      final starter = updated[i];
      if (activeNames.contains(starter.name.trim().toLowerCase())) {
        final isGk = starter.isGoalkeeper || starter.primaryPosition == 'GK';

        // Find available replacement on bench
        int replacementIndex = -1;
        for (int b = 11; b < updated.length; b++) {
          final benchPlayer = updated[b];
          if (activeNames.contains(benchPlayer.name.trim().toLowerCase())) continue;

          final benchIsGk = benchPlayer.isGoalkeeper || benchPlayer.primaryPosition == 'GK';
          if (isGk == benchIsGk) {
            replacementIndex = b;
            break;
          }
        }

        // If no matching GK found but outfield, pick any available outfield
        if (replacementIndex == -1 && !isGk) {
          for (int b = 11; b < updated.length; b++) {
            final benchPlayer = updated[b];
            if (activeNames.contains(benchPlayer.name.trim().toLowerCase())) continue;
            if (!benchPlayer.isGoalkeeper && benchPlayer.primaryPosition != 'GK') {
              replacementIndex = b;
              break;
            }
          }
        }

        if (replacementIndex != -1) {
          final temp = updated[i];
          updated[i] = updated[replacementIndex];
          updated[replacementIndex] = temp;
        }
      }
    }

    return updated;
  }
}
