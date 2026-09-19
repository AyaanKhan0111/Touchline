import 'package:flutter/material.dart';
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Interactive FIFA-Style Pitch Lineup & Formation Editor Sheet
class FormationEditorSheet extends StatefulWidget {
  final List<Player> squad;
  final String currentFormationId;
  final Function(String newFormationId, List<Player> updatedSquad) onSave;

  const FormationEditorSheet({
    super.key,
    required this.squad,
    required this.currentFormationId,
    required this.onSave,
  });

  @override
  State<FormationEditorSheet> createState() => _FormationEditorSheetState();
}

class _FormationEditorSheetState extends State<FormationEditorSheet> {
  late String _formationId;
  late List<Player> _squad;
  int? _selectedPlayerIndex; // Index in _squad currently selected for swapping

  @override
  void initState() {
    super.initState();
    _formationId = widget.currentFormationId;
    _squad = List<Player>.from(widget.squad);
  }

  void _handlePlayerTap(int index) {
    setState(() {
      if (_selectedPlayerIndex == null) {
        // Select this player
        _selectedPlayerIndex = index;
      } else if (_selectedPlayerIndex == index) {
        // Deselect
        _selectedPlayerIndex = null;
      } else {
        // SWAP players!
        final pA = _squad[_selectedPlayerIndex!];
        final pB = _squad[index];
        final isGkA = pA.isGoalkeeper || pA.primaryPosition == 'GK';
        final isGkB = pB.isGoalkeeper || pB.primaryPosition == 'GK';

        if (isGkA != isGkB) {
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
          _selectedPlayerIndex = null;
          return;
        }

        final temp = _squad[_selectedPlayerIndex!];
        _squad[_selectedPlayerIndex!] = _squad[index];
        _squad[index] = temp;
        _selectedPlayerIndex = null;
        widget.onSave(_formationId, _squad);
      }
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
    final starters = _squad.take(11).toList();
    final bench = _squad.skip(11).toList();
    final avgStarterOvr = starters.isNotEmpty
        ? (starters.map((p) => p.overall).reduce((a, b) => a + b) / starters.length).round()
        : 80;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF0B141B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                          Text(
                            formation.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                  onSelected: (val) {
                    setState(() {
                      _formationId = val;
                      widget.onSave(_formationId, _squad);
                    });
                  },
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
                        Icon(Icons.tune, color: AppPalette.gold, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'CHANGE',
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

          // Instructions hint
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                Icon(
                  _selectedPlayerIndex != null ? Icons.swap_horiz : Icons.touch_app,
                  size: 14,
                  color: _selectedPlayerIndex != null ? const Color(0xFFFFD700) : Colors.white38,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _selectedPlayerIndex != null
                        ? 'Tap any other player on the pitch or bench to SWAP'
                        : 'Tap a starter or bench player to swap positions freely',
                    style: TextStyle(
                      color: _selectedPlayerIndex != null ? const Color(0xFFFFD700) : Colors.white54,
                      fontSize: 11,
                      fontWeight: _selectedPlayerIndex != null ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (_selectedPlayerIndex != null)
                  TextButton(
                    onPressed: () => setState(() => _selectedPlayerIndex = null),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(40, 20),
                    ),
                    child: const Text('CANCEL', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // THE VISUAL PITCH
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final pitchWidth = constraints.maxWidth;
                  final pitchHeight = constraints.maxHeight;

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CustomPaint(
                      painter: PitchPainter(),
                      child: Stack(
                        children: [
                          // Render the 11 starter slots
                          for (int i = 0; i < 11 && i < formation.slots.length && i < starters.length; i++)
                            _buildPitchPlayer(
                              slot: formation.slots[i],
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
          const SizedBox(height: 8),
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
              ],
            ),
          ),

          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF101B24),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: bench.length,
                itemBuilder: (context, bIdx) {
                  final playerIdx = 11 + bIdx;
                  final player = bench[bIdx];
                  final isSelected = _selectedPlayerIndex == playerIdx;

                  return GestureDetector(
                    onTap: () => _handlePlayerTap(playerIdx),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppPalette.gold.withValues(alpha: 0.25) : const Color(0xFF162633),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppPalette.gold : Colors.white10,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
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
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
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
    final cardW = 64.0;
    final cardH = 54.0;

    final posX = (slot.x * pitchWidth) - (cardW / 2);
    final posY = (slot.y * pitchHeight) - (cardH / 2);

    return Positioned(
      left: posX.clamp(4.0, pitchWidth - cardW - 4.0),
      top: posY.clamp(4.0, pitchHeight - cardH - 4.0),
      child: GestureDetector(
        onTap: () => _handlePlayerTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: cardW,
          height: cardH,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F3B5C) : const Color(0xFF0C1923).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFFD700)
                  : Colors.white.withValues(alpha: 0.25),
              width: isSelected ? 2.2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected ? const Color(0xFFFFD700).withValues(alpha: 0.4) : Colors.black45,
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A4C),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      player.primaryPosition,
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
            ],
          ),
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
