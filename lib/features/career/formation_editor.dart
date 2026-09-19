import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/models/player.dart';

/// Position coordinate on a normalized pitch (0.0 to 1.0)
class PitchSlot {
  final String defaultRole; // e.g. 'GK', 'CB', 'LW', 'ST'
  final double x; // 0.0 (left) to 1.0 (right)
  final double y; // 0.0 (attacking top) to 1.0 (defending bottom)

  const PitchSlot({
    required this.defaultRole,
    required this.x,
    required this.y,
  });

  PitchSlot copyWith({
    String? defaultRole,
    double? x,
    double? y,
  }) {
    return PitchSlot(
      defaultRole: defaultRole ?? this.defaultRole,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  Map<String, dynamic> toJson() => {
    'defaultRole': defaultRole,
    'x': x,
    'y': y,
  };

  factory PitchSlot.fromJson(Map<String, dynamic> json) => PitchSlot(
    defaultRole: json['defaultRole'] as String? ?? 'CM',
    x: (json['x'] as num?)?.toDouble() ?? 0.5,
    y: (json['y'] as num?)?.toDouble() ?? 0.5,
  );

  /// Dynamically derives a tactical role badge from pitch coordinates
  static String deriveTacticalRole(int slotIndex, double x, double y) {
    if (slotIndex == 0) return 'GK';

    // Attacking third (y <= 0.30)
    if (y <= 0.30) {
      if (x < 0.28) return 'LW';
      if (x > 0.72) return 'RW';
      if (y < 0.20) return 'ST';
      return 'CF';
    }

    // Attacking midfield (0.30 < y <= 0.44)
    if (y <= 0.44) {
      if (x < 0.25) return 'LM';
      if (x > 0.75) return 'RM';
      if (x >= 0.38 && x <= 0.62) return 'CAM';
      return 'AM';
    }

    // Central midfield (0.44 < y <= 0.58)
    if (y <= 0.58) {
      if (x < 0.22) return 'LM';
      if (x > 0.78) return 'RM';
      if (x < 0.40) return 'LCM';
      if (x > 0.60) return 'RCM';
      return 'CM';
    }

    // Defensive midfield (0.58 < y <= 0.68)
    if (y <= 0.68) {
      if (x < 0.22) return 'LWB';
      if (x > 0.78) return 'RWB';
      if (x < 0.40) return 'LDM';
      if (x > 0.60) return 'RDM';
      return 'CDM';
    }

    // Defensive line (y > 0.68)
    if (x < 0.22) return 'LB';
    if (x > 0.78) return 'RB';
    if (x < 0.40) return 'LCB';
    if (x > 0.60) return 'RCB';
    return 'CB';
  }

  /// Clamps slot within safe pitch boundaries. GK stays in penalty box.
  static PitchSlot clampSlot(int slotIndex, double x, double y) {
    if (slotIndex == 0) {
      // Goalkeeper: constrained to defending box
      final clampedX = x.clamp(0.35, 0.65);
      final clampedY = y.clamp(0.78, 0.94);
      return PitchSlot(
        defaultRole: 'GK',
        x: double.parse(clampedX.toStringAsFixed(3)),
        y: double.parse(clampedY.toStringAsFixed(3)),
      );
    } else {
      // Outfield player: tactical pitch bounds
      final clampedX = x.clamp(0.08, 0.92);
      final clampedY = y.clamp(0.08, 0.88);
      final role = deriveTacticalRole(slotIndex, clampedX, clampedY);
      return PitchSlot(
        defaultRole: role,
        x: double.parse(clampedX.toStringAsFixed(3)),
        y: double.parse(clampedY.toStringAsFixed(3)),
      );
    }
  }
}

/// Tactical formation definition
class TacticalFormation {
  final String id;
  final String displayName;
  final List<PitchSlot> slots; // Exactly 11 slots for starters

  const TacticalFormation({
    required this.id,
    required this.displayName,
    required this.slots,
  });

  bool isCustomized(List<PitchSlot> currentSlots) {
    if (currentSlots.length != slots.length) return true;
    for (int i = 0; i < slots.length; i++) {
      if ((slots[i].x - currentSlots[i].x).abs() > 0.015 ||
          (slots[i].y - currentSlots[i].y).abs() > 0.015) {
        return true;
      }
    }
    return false;
  }

  static const List<TacticalFormation> presets = [
    // 4-3-3 (Default)
    TacticalFormation(
      id: '4-3-3',
      displayName: '4-3-3 Attack',
      slots: [
        PitchSlot(defaultRole: 'GK', x: 0.50, y: 0.88),
        PitchSlot(defaultRole: 'LB', x: 0.15, y: 0.70),
        PitchSlot(defaultRole: 'CB', x: 0.38, y: 0.73),
        PitchSlot(defaultRole: 'CB', x: 0.62, y: 0.73),
        PitchSlot(defaultRole: 'RB', x: 0.85, y: 0.70),
        PitchSlot(defaultRole: 'CM', x: 0.28, y: 0.50),
        PitchSlot(defaultRole: 'CAM', x: 0.50, y: 0.42),
        PitchSlot(defaultRole: 'CM', x: 0.72, y: 0.50),
        PitchSlot(defaultRole: 'LW', x: 0.18, y: 0.22),
        PitchSlot(defaultRole: 'ST', x: 0.50, y: 0.16),
        PitchSlot(defaultRole: 'RW', x: 0.82, y: 0.22),
      ],
    ),
    // 4-2-3-1
    TacticalFormation(
      id: '4-2-3-1',
      displayName: '4-2-3-1 Wide',
      slots: [
        PitchSlot(defaultRole: 'GK', x: 0.50, y: 0.88),
        PitchSlot(defaultRole: 'LB', x: 0.15, y: 0.70),
        PitchSlot(defaultRole: 'CB', x: 0.38, y: 0.73),
        PitchSlot(defaultRole: 'CB', x: 0.62, y: 0.73),
        PitchSlot(defaultRole: 'RB', x: 0.85, y: 0.70),
        PitchSlot(defaultRole: 'CDM', x: 0.35, y: 0.56),
        PitchSlot(defaultRole: 'CDM', x: 0.65, y: 0.56),
        PitchSlot(defaultRole: 'LM', x: 0.18, y: 0.35),
        PitchSlot(defaultRole: 'CAM', x: 0.50, y: 0.33),
        PitchSlot(defaultRole: 'RM', x: 0.82, y: 0.35),
        PitchSlot(defaultRole: 'ST', x: 0.50, y: 0.16),
      ],
    ),
    // 4-4-2
    TacticalFormation(
      id: '4-4-2',
      displayName: '4-4-2 Classic',
      slots: [
        PitchSlot(defaultRole: 'GK', x: 0.50, y: 0.88),
        PitchSlot(defaultRole: 'LB', x: 0.15, y: 0.70),
        PitchSlot(defaultRole: 'CB', x: 0.38, y: 0.73),
        PitchSlot(defaultRole: 'CB', x: 0.62, y: 0.73),
        PitchSlot(defaultRole: 'RB', x: 0.85, y: 0.70),
        PitchSlot(defaultRole: 'LM', x: 0.15, y: 0.46),
        PitchSlot(defaultRole: 'CM', x: 0.38, y: 0.48),
        PitchSlot(defaultRole: 'CM', x: 0.62, y: 0.48),
        PitchSlot(defaultRole: 'RM', x: 0.85, y: 0.46),
        PitchSlot(defaultRole: 'ST', x: 0.36, y: 0.18),
        PitchSlot(defaultRole: 'ST', x: 0.64, y: 0.18),
      ],
    ),
    // 3-5-2
    TacticalFormation(
      id: '3-5-2',
      displayName: '3-5-2 Wingbacks',
      slots: [
        PitchSlot(defaultRole: 'GK', x: 0.50, y: 0.88),
        PitchSlot(defaultRole: 'CB', x: 0.25, y: 0.73),
        PitchSlot(defaultRole: 'CB', x: 0.50, y: 0.75),
        PitchSlot(defaultRole: 'CB', x: 0.75, y: 0.73),
        PitchSlot(defaultRole: 'LWB', x: 0.12, y: 0.48),
        PitchSlot(defaultRole: 'CDM', x: 0.35, y: 0.54),
        PitchSlot(defaultRole: 'CAM', x: 0.50, y: 0.36),
        PitchSlot(defaultRole: 'CDM', x: 0.65, y: 0.54),
        PitchSlot(defaultRole: 'RWB', x: 0.88, y: 0.48),
        PitchSlot(defaultRole: 'ST', x: 0.36, y: 0.18),
        PitchSlot(defaultRole: 'ST', x: 0.64, y: 0.18),
      ],
    ),
    // 3-4-3
    TacticalFormation(
      id: '3-4-3',
      displayName: '3-4-3 Attack',
      slots: [
        PitchSlot(defaultRole: 'GK', x: 0.50, y: 0.88),
        PitchSlot(defaultRole: 'CB', x: 0.25, y: 0.73),
        PitchSlot(defaultRole: 'CB', x: 0.50, y: 0.75),
        PitchSlot(defaultRole: 'CB', x: 0.75, y: 0.73),
        PitchSlot(defaultRole: 'LM', x: 0.15, y: 0.48),
        PitchSlot(defaultRole: 'CM', x: 0.38, y: 0.50),
        PitchSlot(defaultRole: 'CM', x: 0.62, y: 0.50),
        PitchSlot(defaultRole: 'RM', x: 0.85, y: 0.48),
        PitchSlot(defaultRole: 'LW', x: 0.20, y: 0.20),
        PitchSlot(defaultRole: 'ST', x: 0.50, y: 0.16),
        PitchSlot(defaultRole: 'RW', x: 0.80, y: 0.20),
      ],
    ),
    // 5-3-2
    TacticalFormation(
      id: '5-3-2',
      displayName: '5-3-2 Solid',
      slots: [
        PitchSlot(defaultRole: 'GK', x: 0.50, y: 0.88),
        PitchSlot(defaultRole: 'LWB', x: 0.12, y: 0.65),
        PitchSlot(defaultRole: 'CB', x: 0.30, y: 0.73),
        PitchSlot(defaultRole: 'CB', x: 0.50, y: 0.75),
        PitchSlot(defaultRole: 'CB', x: 0.70, y: 0.73),
        PitchSlot(defaultRole: 'RWB', x: 0.88, y: 0.65),
        PitchSlot(defaultRole: 'CM', x: 0.28, y: 0.48),
        PitchSlot(defaultRole: 'CM', x: 0.50, y: 0.45),
        PitchSlot(defaultRole: 'CM', x: 0.72, y: 0.48),
        PitchSlot(defaultRole: 'ST', x: 0.36, y: 0.18),
        PitchSlot(defaultRole: 'ST', x: 0.64, y: 0.18),
      ],
    ),
    // 4-1-4-1
    TacticalFormation(
      id: '4-1-4-1',
      displayName: '4-1-4-1 Control',
      slots: [
        PitchSlot(defaultRole: 'GK', x: 0.50, y: 0.88),
        PitchSlot(defaultRole: 'LB', x: 0.15, y: 0.70),
        PitchSlot(defaultRole: 'CB', x: 0.38, y: 0.73),
        PitchSlot(defaultRole: 'CB', x: 0.62, y: 0.73),
        PitchSlot(defaultRole: 'RB', x: 0.85, y: 0.70),
        PitchSlot(defaultRole: 'CDM', x: 0.50, y: 0.58),
        PitchSlot(defaultRole: 'LM', x: 0.15, y: 0.38),
        PitchSlot(defaultRole: 'CM', x: 0.38, y: 0.40),
        PitchSlot(defaultRole: 'CM', x: 0.62, y: 0.40),
        PitchSlot(defaultRole: 'RM', x: 0.85, y: 0.38),
        PitchSlot(defaultRole: 'ST', x: 0.50, y: 0.16),
      ],
    ),
  ];

  static TacticalFormation getById(String id) {
    return presets.firstWhere(
      (f) => f.id == id,
      orElse: () => presets.first,
    );
  }
}

/// Custom painter for authentic football pitch with stripes, markings and grass gradient
class PitchPainter extends CustomPainter {
  final PitchSlot? activeGuideSlot;

  const PitchPainter({this.activeGuideSlot});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Grass background with stripes
    final bgPaint = Paint()..color = const Color(0xFF1E562A);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(16)), bgPaint);

    // Subtle alternating mowing stripes
    final stripePaint = Paint()..color = const Color(0xFF236531);
    const numStripes = 8;
    final stripeHeight = h / numStripes;
    for (int i = 0; i < numStripes; i += 2) {
      canvas.drawRect(Rect.fromLTWH(0, i * stripeHeight, w, stripeHeight), stripePaint);
    }

    // Pitch line paint
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final inset = 12.0;
    final fieldRect = Rect.fromLTWH(inset, inset, w - 2 * inset, h - 2 * inset);
    canvas.drawRect(fieldRect, linePaint);

    // Halfway line
    final midY = h / 2;
    canvas.drawLine(Offset(inset, midY), Offset(w - inset, midY), linePaint);

    // Center circle
    final centerCircleRadius = w * 0.16;
    canvas.drawCircle(Offset(w / 2, midY), centerCircleRadius, linePaint);
    final spotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2, midY), 2.5, spotPaint);

    // Attacking penalty box (top)
    final boxW = w * 0.58;
    final boxH = h * 0.18;
    final boxX = (w - boxW) / 2;
    canvas.drawRect(Rect.fromLTWH(boxX, inset, boxW, boxH), linePaint);

    // Attacking 6-yard box
    final smallBoxW = w * 0.28;
    final smallBoxH = h * 0.07;
    final smallBoxX = (w - smallBoxW) / 2;
    canvas.drawRect(Rect.fromLTWH(smallBoxX, inset, smallBoxW, smallBoxH), linePaint);

    // Defending penalty box (bottom)
    canvas.drawRect(Rect.fromLTWH(boxX, h - inset - boxH, boxW, boxH), linePaint);

    // Defending 6-yard box
    canvas.drawRect(Rect.fromLTWH(smallBoxX, h - inset - smallBoxH, smallBoxW, smallBoxH), linePaint);

    // Penalty spots
    canvas.drawCircle(Offset(w / 2, inset + boxH * 0.65), 2.0, spotPaint);
    canvas.drawCircle(Offset(w / 2, h - inset - boxH * 0.65), 2.0, spotPaint);

    // Tactical crosshair guide lines when actively dragging a slot in Freeform Mode
    if (activeGuideSlot != null) {
      final guideX = (activeGuideSlot!.x * w).clamp(inset, w - inset);
      final guideY = (activeGuideSlot!.y * h).clamp(inset, h - inset);

      final guidePaint = Paint()
        ..color = AppPalette.gold.withValues(alpha: 0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      // Dashed horizontal guide
      const dashW = 6.0;
      const dashSpace = 4.0;
      double startX = inset;
      while (startX < w - inset) {
        canvas.drawLine(
          Offset(startX, guideY),
          Offset(math.min(startX + dashW, w - inset), guideY),
          guidePaint,
        );
        startX += dashW + dashSpace;
      }

      // Dashed vertical guide
      double startY = inset;
      while (startY < h - inset) {
        canvas.drawLine(
          Offset(guideX, startY),
          Offset(guideX, math.min(startY + dashW, h - inset)),
          guidePaint,
        );
        startY += dashW + dashSpace;
      }

      // Reticle ring
      final reticlePaint = Paint()
        ..color = AppPalette.gold.withValues(alpha: 0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(guideX, guideY), 16.0, reticlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant PitchPainter oldDelegate) {
    return oldDelegate.activeGuideSlot != activeGuideSlot;
  }
}

/// Interactive FIFA-Style Pitch Lineup & Formation Editor Sheet
class FormationEditorSheet extends StatefulWidget {
  final List<Player> squad;
  final String currentFormationId;
  final List<PitchSlot>? initialCustomSlots;
  final Function(String newFormationId, List<Player> updatedSquad, [List<PitchSlot>? customSlots]) onSave;

  const FormationEditorSheet({
    super.key,
    required this.squad,
    required this.currentFormationId,
    this.initialCustomSlots,
    required this.onSave,
  });

  @override
  State<FormationEditorSheet> createState() => _FormationEditorSheetState();
}

class _FormationEditorSheetState extends State<FormationEditorSheet> {
  late String _formationId;
  late List<Player> _squad;
  late List<PitchSlot> _currentSlots;
  int? _selectedPlayerIndex; // Index in _squad currently selected for tap-to-swap
  int? _draggingSlotIndex; // Slot index being moved across the pitch in Freeform mode
  int _editorMode = 0; // 0: LINEUP & SWAPS, 1: FREEFORM PITCH

  @override
  void initState() {
    super.initState();
    _formationId = widget.currentFormationId;
    _squad = List<Player>.from(widget.squad);

    final defaultFormation = TacticalFormation.getById(_formationId);
    if (widget.initialCustomSlots != null && widget.initialCustomSlots!.length == 11) {
      _currentSlots = List<PitchSlot>.from(widget.initialCustomSlots!);
    } else {
      _currentSlots = List<PitchSlot>.from(defaultFormation.slots);
    }
  }

  bool _canSwap(int indexA, int indexB) {
    if (indexA == indexB) return false;
    if (indexA < 0 || indexA >= _squad.length || indexB < 0 || indexB >= _squad.length) return false;
    final pA = _squad[indexA];
    final pB = _squad[indexB];
    final isGkA = pA.isGoalkeeper || pA.primaryPosition == 'GK';
    final isGkB = pB.isGoalkeeper || pB.primaryPosition == 'GK';
    return isGkA == isGkB;
  }

  void _executeSwap(int indexA, int indexB) {
    if (!_canSwap(indexA, indexB)) {
      SoundService.instance.playWrong();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppPalette.red,
          content: Text(
            'Invalid Swap: Goalkeepers cannot be swapped with outfield players.',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          duration: Duration(seconds: 2),
        ),
      );
      setState(() {
        _selectedPlayerIndex = null;
      });
      return;
    }

    SoundService.instance.playClick();
    setState(() {
      final temp = _squad[indexA];
      _squad[indexA] = _squad[indexB];
      _squad[indexB] = temp;
      _selectedPlayerIndex = null;
      widget.onSave(_formationId, _squad, _currentSlots);
    });
  }

  void _handlePlayerTap(int index) {
    if (_editorMode == 1) {
      // In Freeform mode, tapping selects node for visual feedback
      setState(() {
        _selectedPlayerIndex = (_selectedPlayerIndex == index) ? null : index;
      });
      SoundService.instance.playClick();
      return;
    }

    // In Swap mode: standard tap-to-swap
    setState(() {
      if (_selectedPlayerIndex == null) {
        // Select this player
        _selectedPlayerIndex = index;
        SoundService.instance.playClick();
      } else if (_selectedPlayerIndex == index) {
        // Deselect
        _selectedPlayerIndex = null;
        SoundService.instance.playClick();
      } else {
        // SWAP players!
        _executeSwap(_selectedPlayerIndex!, index);
      }
    });
  }

  void _resetSlotsToPreset() {
    SoundService.instance.playClick();
    setState(() {
      final preset = TacticalFormation.getById(_formationId);
      _currentSlots = List<PitchSlot>.from(preset.slots);
      _selectedPlayerIndex = null;
      _draggingSlotIndex = null;
      widget.onSave(_formationId, _squad, _currentSlots);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF132330),
        content: Text(
          'Positions reset to canonical ${TacticalFormation.getById(_formationId).displayName}',
          style: const TextStyle(color: AppPalette.gold, fontWeight: FontWeight.bold),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _changeFormation(String newId) {
    SoundService.instance.playClick();
    setState(() {
      _formationId = newId;
      final preset = TacticalFormation.getById(newId);
      _currentSlots = List<PitchSlot>.from(preset.slots);
      _selectedPlayerIndex = null;
      _draggingSlotIndex = null;
      widget.onSave(_formationId, _squad, _currentSlots);
    });
  }

  Color _getOvrColor(int ovr) {
    if (ovr >= 85) return const Color(0xFFFFD700); // Gold
    if (ovr >= 80) return const Color(0xFF00E5FF); // Electric Cyan
    if (ovr >= 75) return const Color(0xFFC0C0C0); // Silver
    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    final formation = TacticalFormation.getById(_formationId);
    final isCustomized = formation.isCustomized(_currentSlots);
    final starters = _squad.take(11).toList();
    final bench = _squad.skip(11).toList();
    final avgStarterOvr = starters.isNotEmpty
        ? (starters.map((p) => p.overall).reduce((a, b) => a + b) / starters.length).round()
        : 80;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFF0B141B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title & Formation Selector Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TEAM MANAGEMENT & TACTICS',
                        style: TextStyle(
                          color: AppPalette.darkInkMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              formation.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isCustomized) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppPalette.gold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppPalette.gold.withValues(alpha: 0.6)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, color: AppPalette.gold, size: 10),
                                  SizedBox(width: 3),
                                  Text(
                                    'CUSTOM',
                                    style: TextStyle(
                                      color: AppPalette.gold,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              'OVR $avgStarterOvr',
                              style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Formation Dropdown
                PopupMenuButton<String>(
                  initialValue: _formationId,
                  tooltip: 'Change Formation',
                  onSelected: _changeFormation,
                  color: const Color(0xFF132330),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (context) {
                    return TacticalFormation.presets.map((f) {
                      final isSelected = f.id == _formationId;
                      return PopupMenuItem<String>(
                        value: f.id,
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: isSelected ? AppPalette.gold : Colors.white54,
                              size: 16,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              f.displayName,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF162A38),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppPalette.gold.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune, color: AppPalette.gold, size: 15),
                        SizedBox(width: 5),
                        Text(
                          'PRESETS',
                          style: TextStyle(
                            color: AppPalette.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Interactive Mode Selector Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFF101B24),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModeTab(
                      index: 0,
                      label: 'LINEUP & SWAPS',
                      icon: Icons.swap_horiz_rounded,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildModeTab(
                      index: 1,
                      label: 'FREEFORM PITCH',
                      icon: Icons.open_with_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contextual Instructions & Reset Action
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(
                  _editorMode == 1
                      ? Icons.control_camera_rounded
                      : (_selectedPlayerIndex != null ? Icons.touch_app : Icons.pan_tool_alt_rounded),
                  size: 13,
                  color: (_editorMode == 1 || _selectedPlayerIndex != null)
                      ? AppPalette.gold
                      : Colors.white38,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _editorMode == 1
                        ? 'Drag any starter node to customize spacing & tactical roles'
                        : (_selectedPlayerIndex != null
                            ? 'Tap another player or drag card to SWAP'
                            : 'Tap or drag players between pitch & bench to swap starters'),
                    style: TextStyle(
                      color: (_editorMode == 1 || _selectedPlayerIndex != null)
                          ? AppPalette.gold
                          : Colors.white54,
                      fontSize: 10.5,
                      fontWeight: (_editorMode == 1 || _selectedPlayerIndex != null)
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_editorMode == 0 && _selectedPlayerIndex != null)
                  TextButton(
                    onPressed: () => setState(() => _selectedPlayerIndex = null),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(40, 20),
                    ),
                    child: const Text('CANCEL', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  )
                else if (isCustomized)
                  InkWell(
                    onTap: _resetSlotsToPreset,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.restore, size: 12, color: Colors.white70),
                          SizedBox(width: 3),
                          Text(
                            'RESET',
                            style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // THE TACTICAL PITCH
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final pitchWidth = constraints.maxWidth;
                  final pitchHeight = constraints.maxHeight;
                  final guideSlot = (_draggingSlotIndex != null && _draggingSlotIndex! < _currentSlots.length)
                      ? _currentSlots[_draggingSlotIndex!]
                      : null;

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CustomPaint(
                      painter: PitchPainter(activeGuideSlot: guideSlot),
                      child: Stack(
                        children: [
                          // Render the 11 starter slots
                          for (int i = 0; i < 11 && i < _currentSlots.length && i < starters.length; i++)
                            _buildPitchPlayer(
                              slot: _currentSlots[i],
                              player: starters[i],
                              index: i,
                              pitchWidth: pitchWidth,
                              pitchHeight: pitchHeight,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // BENCH RESERVES TITLE & LIST
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                const Text(
                  'SUBSTITUTES & BENCH',
                  style: TextStyle(
                    color: AppPalette.darkInkMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${bench.length} reserves)',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                const Spacer(),
                if (_editorMode == 0)
                  const Text(
                    'Hold card to drag into lineup',
                    style: TextStyle(color: Colors.white30, fontSize: 9.5, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),

          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF101B24),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: bench.length,
                itemBuilder: (context, bIdx) => _buildBenchItem(bIdx, bench),
              ),
            ),
          ),

          // Bottom Confirmation Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  SoundService.instance.playClick();
                  widget.onSave(_formationId, _squad, _currentSlots);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text(
                  isCustomized ? 'SAVE CUSTOM TACTICS' : 'CONFIRM LINEUP',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isActive = _editorMode == index;
    return GestureDetector(
      onTap: () {
        SoundService.instance.playClick();
        setState(() {
          _editorMode = index;
          _selectedPlayerIndex = null;
          _draggingSlotIndex = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppPalette.gold.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppPalette.gold.withValues(alpha: 0.6) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? AppPalette.gold : Colors.white54,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppPalette.gold : Colors.white60,
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPitchPlayer({
    required PitchSlot slot,
    required Player player,
    required int index,
    required double pitchWidth,
    required double pitchHeight,
  }) {
    final isSelected = _selectedPlayerIndex == index;
    final isActivelyDragged = _draggingSlotIndex == index;
    const cardW = 66.0;
    const cardH = 56.0;

    final posX = (slot.x * pitchWidth) - (cardW / 2);
    final posY = (slot.y * pitchHeight) - (cardH / 2);

    if (_editorMode == 1) {
      // FREEFORM TACTICAL DRAG MODE
      return Positioned(
        left: posX.clamp(4.0, pitchWidth - cardW - 4.0),
        top: posY.clamp(4.0, pitchHeight - cardH - 4.0),
        child: GestureDetector(
          onPanStart: (details) {
            setState(() {
              _draggingSlotIndex = index;
            });
            SoundService.instance.lightHaptic();
          },
          onPanUpdate: (details) {
            setState(() {
              final dx = details.delta.dx / pitchWidth;
              final dy = details.delta.dy / pitchHeight;
              final cur = _currentSlots[index];
              _currentSlots[index] = PitchSlot.clampSlot(index, cur.x + dx, cur.y + dy);
            });
          },
          onPanEnd: (_) {
            setState(() {
              _draggingSlotIndex = null;
            });
            SoundService.instance.playClick();
            widget.onSave(_formationId, _squad, _currentSlots);
          },
          onPanCancel: () {
            setState(() {
              _draggingSlotIndex = null;
            });
          },
          child: _buildNodeCard(
            player: player,
            slot: slot,
            isSelected: isSelected,
            isDragging: isActivelyDragged,
            showCoords: isActivelyDragged,
            cardW: cardW,
            cardH: cardH,
          ),
        ),
      );
    } else {
      // SWAP MODE (Drag-to-Swap and Tap-to-Swap)
      return Positioned(
        left: posX.clamp(4.0, pitchWidth - cardW - 4.0),
        top: posY.clamp(4.0, pitchHeight - cardH - 4.0),
        child: DragTarget<int>(
          onWillAcceptWithDetails: (details) => details.data != index,
          onAcceptWithDetails: (details) {
            _executeSwap(details.data, index);
          },
          builder: (context, candidateData, rejectedData) {
            final draggedCandidate = candidateData.whereType<int>().firstOrNull;
            final isTargeted = draggedCandidate != null;
            final canAccept = isTargeted && _canSwap(draggedCandidate, index);

            return LongPressDraggable<int>(
              data: index,
              delay: const Duration(milliseconds: 140),
              onDragStarted: () => SoundService.instance.lightHaptic(),
              feedback: Material(
                color: Colors.transparent,
                child: _buildNodeCard(
                  player: player,
                  slot: slot,
                  isSelected: true,
                  isFloating: true,
                  cardW: cardW,
                  cardH: cardH,
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.35,
                child: _buildNodeCard(
                  player: player,
                  slot: slot,
                  isSelected: false,
                  cardW: cardW,
                  cardH: cardH,
                ),
              ),
              child: GestureDetector(
                onTap: () => _handlePlayerTap(index),
                child: _buildNodeCard(
                  player: player,
                  slot: slot,
                  isSelected: isSelected,
                  isDropTarget: isTargeted,
                  isDropValid: canAccept,
                  cardW: cardW,
                  cardH: cardH,
                ),
              ),
            );
          },
        ),
      );
    }
  }

  Widget _buildNodeCard({
    required Player player,
    required PitchSlot slot,
    bool isSelected = false,
    bool isDragging = false,
    bool isFloating = false,
    bool isDropTarget = false,
    bool isDropValid = true,
    bool showCoords = false,
    required double cardW,
    required double cardH,
  }) {
    Color borderColor = Colors.white.withValues(alpha: 0.25);
    double borderWidth = 1.2;
    Color bgColor = const Color(0xFF0C1923).withValues(alpha: 0.92);

    if (isDropTarget) {
      if (isDropValid) {
        borderColor = const Color(0xFF00E5FF);
        borderWidth = 2.4;
        bgColor = const Color(0xFF00384D);
      } else {
        borderColor = AppPalette.red;
        borderWidth = 2.4;
        bgColor = const Color(0xFF4A1010);
      }
    } else if (isDragging || isSelected || isFloating) {
      borderColor = const Color(0xFFFFD700);
      borderWidth = 2.2;
      bgColor = const Color(0xFF0F3B5C);
    }

    return AnimatedScale(
      scale: (isDragging || isFloating) ? 1.10 : (isDropTarget ? 1.05 : 1.0),
      duration: const Duration(milliseconds: 150),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: cardW,
        height: cardH,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: (isDragging || isSelected || isFloating)
                  ? const Color(0xFFFFD700).withValues(alpha: 0.45)
                  : (isDropTarget
                      ? (isDropValid
                          ? const Color(0xFF00E5FF).withValues(alpha: 0.45)
                          : AppPalette.red.withValues(alpha: 0.45))
                      : Colors.black45),
              blurRadius: (isDragging || isFloating || isDropTarget) ? 10 : (isSelected ? 8 : 4),
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isDropTarget)
              Text(
                isDropValid ? 'SWAP' : 'NO GK',
                style: TextStyle(
                  color: isDropValid ? const Color(0xFF00E5FF) : AppPalette.red,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1),
                    decoration: BoxDecoration(
                      color: slot.defaultRole == 'GK'
                          ? const Color(0xFF7A4E00)
                          : const Color(0xFF1E3A4C),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      slot.defaultRole,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${player.overall}',
                    style: TextStyle(
                      color: _getOvrColor(player.overall),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  _shortenName(player.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (showCoords)
                Text(
                  '${(slot.x * 100).round()}% • ${(slot.y * 100).round()}%',
                  style: const TextStyle(
                    color: AppPalette.gold,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBenchItem(int bIdx, List<Player> bench) {
    final playerIdx = 11 + bIdx;
    final player = bench[bIdx];
    final isSelected = _selectedPlayerIndex == playerIdx;

    if (_editorMode == 0) {
      // SWAP MODE: bench item is both DragTarget and LongPressDraggable!
      return DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != playerIdx,
        onAcceptWithDetails: (details) {
          _executeSwap(details.data, playerIdx);
        },
        builder: (context, candidateData, rejectedData) {
          final draggedCandidate = candidateData.whereType<int>().firstOrNull;
          final isTargeted = draggedCandidate != null;
          final canAccept = isTargeted && _canSwap(draggedCandidate, playerIdx);

          return LongPressDraggable<int>(
            data: playerIdx,
            delay: const Duration(milliseconds: 180),
            onDragStarted: () => SoundService.instance.lightHaptic(),
            feedback: Material(
              color: Colors.transparent,
              child: _buildBenchCard(
                player: player,
                isSelected: true,
                isFloating: true,
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.35,
              child: _buildBenchCard(player: player, isSelected: false),
            ),
            child: GestureDetector(
              onTap: () => _handlePlayerTap(playerIdx),
              child: _buildBenchCard(
                player: player,
                isSelected: isSelected,
                isDropTarget: isTargeted,
                isDropValid: canAccept,
              ),
            ),
          );
        },
      );
    } else {
      // FREEFORM MODE: bench player is tap-only
      return GestureDetector(
        onTap: () => _handlePlayerTap(playerIdx),
        child: _buildBenchCard(player: player, isSelected: isSelected),
      );
    }
  }

  Widget _buildBenchCard({
    required Player player,
    bool isSelected = false,
    bool isFloating = false,
    bool isDropTarget = false,
    bool isDropValid = true,
  }) {
    Color borderColor = Colors.white10;
    double borderWidth = 1.0;
    Color bgColor = const Color(0xFF162633);

    if (isDropTarget) {
      if (isDropValid) {
        borderColor = const Color(0xFF00E5FF);
        borderWidth = 2.0;
        bgColor = const Color(0xFF00384D);
      } else {
        borderColor = AppPalette.red;
        borderWidth = 2.0;
        bgColor = const Color(0xFF4A1010);
      }
    } else if (isSelected || isFloating) {
      borderColor = AppPalette.gold;
      borderWidth = 2.0;
      bgColor = AppPalette.gold.withValues(alpha: 0.25);
    }

    return AnimatedScale(
      scale: isFloating ? 1.08 : (isDropTarget ? 1.05 : 1.0),
      duration: const Duration(milliseconds: 150),
      child: Container(
        width: 82,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: isFloating
              ? [
                  BoxShadow(
                    color: AppPalette.gold.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isDropTarget)
              Text(
                isDropValid ? 'SUB' : 'NO GK',
                style: TextStyle(
                  color: isDropValid ? const Color(0xFF00E5FF) : AppPalette.red,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: (player.isGoalkeeper || player.primaryPosition == 'GK')
                          ? const Color(0xFF7A4E00)
                          : Colors.black45,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      player.primaryPosition,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${player.overall}',
                    style: TextStyle(
                      color: _getOvrColor(player.overall),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _shortenName(player.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _shortenName(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length <= 1) return fullName;
    return '${parts.first[0]}. ${parts.sublist(1).join(' ')}';
  }
}
