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

  static const List<Map<String, dynamic>> _kMinorInjuryCatalog = [
    {
      'title': 'Dead Leg Contusion',
      'description': 'Deep quadriceps bruising from heavy collision; resting to disperse hematoma.',
      'minGw': 1,
      'maxGw': 1,
      'minDays': 4,
      'maxDays': 7,
      'severity': 'minor',
    },
    {
      'title': 'Mild Ankle Inversion Twist',
      'description': 'Slight ankle roll during change of direction drill; resting as precaution.',
      'minGw': 1,
      'maxGw': 1,
      'minDays': 5,
      'maxDays': 7,
      'severity': 'minor',
    },
    {
      'title': 'Viral Infection & Flu',
      'description': 'Sidelined by club doctor with seasonal fever; resting to prevent spread.',
      'minGw': 1,
      'maxGw': 1,
      'minDays': 4,
      'maxDays': 6,
      'severity': 'minor',
    },
    {
      'title': 'Concussion Protocol Knock',
      'description': 'Head impact during aerial challenge; resting under mandatory FA protocol.',
      'minGw': 1,
      'maxGw': 1,
      'minDays': 7,
      'maxDays': 7,
      'severity': 'minor',
    },
    {
      'title': 'Foot Blister & Turf Abrasion',
      'description': 'Severe friction blister requiring antibiotic dressing and off-feet rest.',
      'minGw': 1,
      'maxGw': 1,
      'minDays': 4,
      'maxDays': 6,
      'severity': 'minor',
    },
    {
      'title': 'Facial Laceration & Swelling',
      'description': 'Collided in training duel; required stitches to eyebrow, avoiding contact.',
      'minGw': 1,
      'maxGw': 1,
      'minDays': 5,
      'maxDays': 7,
      'severity': 'minor',
    },
  ];

  static const List<Map<String, dynamic>> _kModerateInjuryCatalog = [
    {
      'title': 'Grade 1 Hamstring Strain',
      'description': 'Felt acute tightness in posterior thigh during sprint drill; undergoing physio.',
      'minGw': 2,
      'maxGw': 3,
      'minDays': 14,
      'maxDays': 21,
      'severity': 'moderate',
    },
    {
      'title': 'Adductor Groin Pull',
      'description': 'Discomfort during shooting practice; resting to prevent full muscle tear.',
      'minGw': 2,
      'maxGw': 3,
      'minDays': 14,
      'maxDays': 21,
      'severity': 'moderate',
    },
    {
      'title': 'Sprained Ankle Ligaments',
      'description': 'Landed awkwardly on opponent foot; joint immobilized in protective boot.',
      'minGw': 2,
      'maxGw': 4,
      'minDays': 14,
      'maxDays': 28,
      'severity': 'moderate',
    },
    {
      'title': 'Knee Hyperextension Strain',
      'description': 'Jarred knee on firm turf; undergoing targeted joint stabilization therapy.',
      'minGw': 2,
      'maxGw': 3,
      'minDays': 14,
      'maxDays': 21,
      'severity': 'moderate',
    },
    {
      'title': 'Shoulder Joint Subluxation',
      'description': 'Heavy tumble onto turf; joint stabilized in sling to heal capsule.',
      'minGw': 3,
      'maxGw': 4,
      'minDays': 21,
      'maxDays': 28,
      'severity': 'moderate',
    },
    {
      'title': 'Fractured Nose & Facial Injury',
      'description': 'Underwent minor nasal reduction; awaiting custom carbon protective mask.',
      'minGw': 2,
      'maxGw': 3,
      'minDays': 14,
      'maxDays': 21,
      'severity': 'moderate',
    },
    {
      'title': 'Calf Gastrocnemius Strain',
      'description': 'Sharp contraction during acceleration; prescribed cryotherapy rehab.',
      'minGw': 2,
      'maxGw': 3,
      'minDays': 14,
      'maxDays': 21,
      'severity': 'moderate',
    },
  ];

  static const List<Map<String, dynamic>> _kSevereInjuryCatalog = [
    {
      'title': 'Knee Meniscus Cartilage Tear',
      'description': 'Underwent arthroscopic repair; undergoing intensive knee rehabilitation.',
      'minGw': 5,
      'maxGw': 7,
      'minDays': 35,
      'maxDays': 49,
      'severity': 'severe',
    },
    {
      'title': 'High Ankle Syndesmosis Sprain',
      'description': 'Severe rotational ankle disruption requiring non-weight-bearing boot.',
      'minGw': 6,
      'maxGw': 8,
      'minDays': 42,
      'maxDays': 56,
      'severity': 'severe',
    },
    {
      'title': 'Fractured Fibula Bone',
      'description': 'Clean hairline fracture from tackle; bone set in plaster cast.',
      'minGw': 6,
      'maxGw': 9,
      'minDays': 42,
      'maxDays': 63,
      'severity': 'severe',
    },
    {
      'title': 'Hamstring Tendon Partial Tear',
      'description': 'Grade 2 tendon avulsion; rehabilitation supervised by specialist surgeon.',
      'minGw': 5,
      'maxGw': 8,
      'minDays': 35,
      'maxDays': 56,
      'severity': 'severe',
    },
  ];

  static const List<Map<String, dynamic>> _kCriticalInjuryCatalog = [
    {
      'title': 'Anterior Cruciate Ligament (ACL) Rupture',
      'description': 'Severe non-contact knee twist; undergoing reconstruction surgery & long rehab.',
      'minGw': 12,
      'maxGw': 18,
      'minDays': 84,
      'maxDays': 126,
      'severity': 'critical',
    },
    {
      'title': 'Achilles Tendon Rupture',
      'description': 'Tendon snap during acceleration; surgical tendon repair & prolonged rehabilitation.',
      'minGw': 10,
      'maxGw': 16,
      'minDays': 70,
      'maxDays': 112,
      'severity': 'critical',
    },
  ];

  static const List<Map<String, dynamic>> _kSuspensionCatalog = [
    {
      'title': 'Red Card Suspension (Violent Conduct)',
      'description': 'FA disciplinary commission imposed a strict 3-match ban for dangerous challenge.',
      'minGw': 3,
      'maxGw': 3,
      'minDays': 21,
      'maxDays': 21,
      'severity': 'severe',
    },
    {
      'title': 'Red Card Suspension (Professional Foul)',
      'description': 'Serving an automatic 1-match ban for denying an obvious goalscoring opportunity.',
      'minGw': 1,
      'maxGw': 1,
      'minDays': 7,
      'maxDays': 7,
      'severity': 'moderate',
    },
    {
      'title': 'Yellow Card Accumulation Suspension',
      'description': 'Reached domestic threshold of 5 yellow cards; serving automatic 1-match ban.',
      'minGw': 1,
      'maxGw': 1,
      'minDays': 7,
      'maxDays': 7,
      'severity': 'mild',
    },
    {
      'title': 'Disciplinary Code Breach',
      'description': 'Manager imposed a 1-match internal squad suspension for training unpunctuality.',
      'minGw': 1,
      'maxGw': 1,
      'minDays': 7,
      'maxDays': 7,
      'severity': 'mild',
    },
  ];

  static const List<Map<String, dynamic>> _kInternationalDutyCatalog = [
    {
      'title': 'World Cup Qualifier Duty',
      'description': 'Called up to senior national squad for competitive international qualifiers.',
      'minGw': 1,
      'maxGw': 2,
      'minDays': 7,
      'maxDays': 14,
      'severity': 'moderate',
    },
    {
      'title': 'Continental Championship Finals',
      'description': 'Traveled overseas to represent country in major continental tournament.',
      'minGw': 3,
      'maxGw': 4,
      'minDays': 21,
      'maxDays': 28,
      'severity': 'moderate',
    },
    {
      'title': 'Olympic / U23 International Duty',
      'description': 'Selected for national Olympic youth tournament fixtures overseas.',
      'minGw': 2,
      'maxGw': 3,
      'minDays': 14,
      'maxDays': 21,
      'severity': 'moderate',
    },
    {
      'title': 'National Team Exhibition Camp',
      'description': 'Selected for international exhibition fixtures and training camp abroad.',
      'minGw': 1,
      'maxGw': 1,
      'minDays': 7,
      'maxDays': 7,
      'severity': 'mild',
    },
  ];

  static const List<Map<String, dynamic>> _kLeaveCatalog = [
    {
      'title': 'Paternity Leave',
      'description': 'Granted authorized compassionate leave to be with family for birth of a child.',
      'minGw': 1,
      'maxGw': 2,
      'minDays': 7,
      'maxDays': 14,
      'severity': 'mild',
    },
    {
      'title': 'Compassionate Bereavement Leave',
      'description': 'Manager granted short-term absence to attend personal family bereavement.',
      'minGw': 1,
      'maxGw': 2,
      'minDays': 7,
      'maxDays': 14,
      'severity': 'mild',
    },
    {
      'title': 'Consular Visa & Permit Clearance',
      'description': 'Traveled abroad to finalize mandatory immigration and work residency paperwork.',
      'minGw': 1,
      'maxGw': 1,
      'minDays': 5,
      'maxDays': 7,
      'severity': 'minor',
    },
  ];

  static const List<Map<String, dynamic>> _kFatigueCatalog = [
    {
      'title': 'Severe Match Congestion Fatigue',
      'description': 'Sports science staff advised mandatory 1-match rest to prevent muscular breakdown.',
      'minGw': 1,
      'maxGw': 1,
      'minDays': 5,
      'maxDays': 7,
      'severity': 'mild',
    },
    {
      'title': 'Acute Muscle Overload Protocol',
      'description': 'Biometric fatigue indicators spiked beyond safety thresholds; resting for recovery.',
      'minGw': 1,
      'maxGw': 1,
      'minDays': 7,
      'maxDays': 7,
      'severity': 'mild',
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

  /// Returns all players in the Starting XI (indices 0..10) who are currently unavailable.
  static List<Player> getIneligibleStarters({
    required List<Player> squad,
    required List<SquadEvent> activeEvents,
  }) {
    if (squad.isEmpty) return [];
    final activeNames = activeEvents
        .where((e) => !e.isResolved)
        .map((e) => e.playerName.trim().toLowerCase())
        .toSet();

    final ineligible = <Player>[];
    for (int i = 0; i < min(11, squad.length); i++) {
      final player = squad[i];
      if (activeNames.contains(player.name.trim().toLowerCase())) {
        ineligible.add(player);
      }
    }
    return ineligible;
  }

  /// Processes the progression of squad events across matchdays:
  /// - Decrements remaining duration for existing events
  /// - Flags recovered players who return to availability
  /// - Randomly evaluates realistic new injuries, international call-ups, suspensions, or leave
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
      final daysRemaining = max(0, ev.estimatedDays - 7);
      if (remaining <= 0) {
        recovered.add(ev.copyWith(remainingGameweeks: 0, estimatedDays: 0));
      } else {
        updatedActive.add(ev.copyWith(remainingGameweeks: remaining, estimatedDays: daysRemaining));
      }
    }

    // 2. Evaluate new event generation
    final List<SquadEvent> newEvents = [];

    // Safeguards:
    // - Cap active unavailable players at kMaxConcurrentUnavailable (3)
    // - Minimum squad size of 12 to generate events
    // - ~22% chance of a squad event occurring on any matchday
    final canTriggerNew = updatedActive.length < kMaxConcurrentUnavailable &&
        userSquad.length >= 12 &&
        random.nextDouble() < 0.22;

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
        final candidate = eligibleCandidates[random.nextInt(eligibleCandidates.length)];

        // Choose event type:
        // 55% Injury
        // 18% Suspension
        // 14% International Duty
        // 8% Personal Leave
        // 5% Fatigue / Load Management
        final typeRoll = random.nextDouble();
        SquadEventType eventType;
        Map<String, dynamic> eventDetails;

        if (typeRoll < 0.55) {
          eventType = SquadEventType.injury;
          // Sub-distribute injury severity:
          // 50% Minor (1 match / 4-7 days)
          // 35% Moderate (2-4 matches / 14-28 days)
          // 12% Severe (5-8 matches / 35-56 days)
          // 3% Critical (10-18 matches / 70-126 days)
          final injuryRoll = random.nextDouble();
          if (injuryRoll < 0.50) {
            eventDetails = _kMinorInjuryCatalog[random.nextInt(_kMinorInjuryCatalog.length)];
          } else if (injuryRoll < 0.85) {
            eventDetails = _kModerateInjuryCatalog[random.nextInt(_kModerateInjuryCatalog.length)];
          } else if (injuryRoll < 0.97) {
            eventDetails = _kSevereInjuryCatalog[random.nextInt(_kSevereInjuryCatalog.length)];
          } else {
            eventDetails = _kCriticalInjuryCatalog[random.nextInt(_kCriticalInjuryCatalog.length)];
          }
        } else if (typeRoll < 0.73) {
          eventType = SquadEventType.suspension;
          eventDetails = _kSuspensionCatalog[random.nextInt(_kSuspensionCatalog.length)];
        } else if (typeRoll < 0.87) {
          eventType = SquadEventType.internationalDuty;
          eventDetails = _kInternationalDutyCatalog[random.nextInt(_kInternationalDutyCatalog.length)];
        } else if (typeRoll < 0.95) {
          eventType = SquadEventType.personalLeave;
          eventDetails = _kLeaveCatalog[random.nextInt(_kLeaveCatalog.length)];
        } else {
          eventType = SquadEventType.fatigue;
          eventDetails = _kFatigueCatalog[random.nextInt(_kFatigueCatalog.length)];
        }

        final minGw = eventDetails['minGw'] as int;
        final maxGw = eventDetails['maxGw'] as int;
        final duration = minGw + random.nextInt(maxGw - minGw + 1);

        final minDays = eventDetails['minDays'] as int? ?? (duration * 7);
        final maxDays = eventDetails['maxDays'] as int? ?? (duration * 7);
        final days = minDays + random.nextInt(max(1, maxDays - minDays + 1));

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
          estimatedDays: days,
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
