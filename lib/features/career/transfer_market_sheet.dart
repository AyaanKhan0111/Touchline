import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/database/db_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/player.dart';
import '../search/player_detail_sheet.dart';
import '../shared/widgets/player_avatar.dart';
import '../shared/widgets/stat_badge.dart';
import 'career_screen.dart';

/// Modal bottom sheet for Scouting & Signing players from the global database (Issue #9)
class TransferMarketSheet extends StatefulWidget {
  final double budget;
  final bool isWindowOpen;
  final String windowTitle;
  final List<Player> userSquad;
  final Function(Player player, double fee) onSignPlayer;

  const TransferMarketSheet({
    super.key,
    required this.budget,
    required this.isWindowOpen,
    required this.windowTitle,
    required this.userSquad,
    required this.onSignPlayer,
  });

  @override
  State<TransferMarketSheet> createState() => _TransferMarketSheetState();
}

class _TransferMarketSheetState extends State<TransferMarketSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedPositionGroup = 'ALL'; // ALL, GK, DEF, MID, FWD
  List<Player> _players = [];
  bool _isLoading = true;
  late double _currentBudget;
  late List<String> _ownedPlayerNames;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _currentBudget = widget.budget;
    _ownedPlayerNames = widget.userSquad.map((p) => p.name.trim().toLowerCase()).toList();
    _loadPlayers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _loadPlayers();
    });
  }

  Future<void> _loadPlayers() async {
    setState(() => _isLoading = true);

    try {
      final db = await DatabaseService.instance.database;
      String posWhere = '';
      if (_selectedPositionGroup == 'GK') {
        posWhere = " AND primary_position = 'GK'";
      } else if (_selectedPositionGroup == 'DEF') {
        posWhere = " AND primary_position IN ('CB', 'LB', 'RB', 'LWB', 'RWB')";
      } else if (_selectedPositionGroup == 'MID') {
        posWhere = " AND primary_position IN ('CM', 'CAM', 'CDM', 'LM', 'RM')";
      } else if (_selectedPositionGroup == 'FWD') {
        posWhere = " AND primary_position IN ('ST', 'CF', 'LW', 'RW')";
      }

      final query = _searchController.text.trim();
      List<Map<String, dynamic>> rows;

      if (query.isEmpty) {
        rows = await db.rawQuery('''
          SELECT *
          FROM players
          WHERE season >= 2022 $posWhere
          GROUP BY player_name
          ORDER BY MAX(overall) DESC
          LIMIT 60
        ''');
      } else {
        final pattern = '%$query%';
        rows = await db.rawQuery('''
          SELECT *
          FROM players
          WHERE season >= 2022 $posWhere AND (player_name LIKE ? OR player_name_clean LIKE ? OR team_name LIKE ?)
          GROUP BY player_name
          ORDER BY MAX(overall) DESC
          LIMIT 60
        ''', [pattern, pattern, pattern]);

        if (rows.isEmpty) {
          // Fall back to historical database records if modern search returns no results
          rows = await db.rawQuery('''
            SELECT *
            FROM players
            WHERE 1=1 $posWhere AND (player_name LIKE ? OR player_name_clean LIKE ? OR team_name LIKE ?)
            GROUP BY player_name
            ORDER BY MAX(overall) DESC
            LIMIT 60
          ''', [pattern, pattern, pattern]);
        }
      }

      if (mounted) {
        setState(() {
          _players = rows.map((r) => Player.fromMap(r)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _promptSignPlayer(Player player) {
    final fee = calculatePlayerValuation(player);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink = theme.colorScheme.onSurface;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.handshake_rounded, color: AppPalette.gold),
            const SizedBox(width: 8),
            Text('Confirm Signing', style: AppTypography.titleMedium(ink)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sign ${player.name} to your squad?',
              style: AppTypography.bodyLarge(ink).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Position: ${player.primaryPosition} • Rating: ${player.overall} OVR • Age: ${player.age?.toInt() ?? 26}',
              style: AppTypography.bodySmall(ink.withValues(alpha: 0.7)),
            ),
            Text(
              'Current Club: ${player.teamName}',
              style: AppTypography.bodySmall(ink.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppPalette.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppPalette.gold.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Transfer Fee:', style: AppTypography.caption(ink)),
                      Text(
                        '£${fee.toStringAsFixed(1)}M',
                        style: AppTypography.statNumber(AppPalette.gold, fontSize: 13, weight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Remaining War Chest:', style: AppTypography.caption(ink)),
                      Text(
                        '£${(_currentBudget - fee).toStringAsFixed(1)}M',
                        style: AppTypography.statNumber(AppPalette.green, fontSize: 13, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.gold,
              foregroundColor: isDark ? AppPalette.darkBg : Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _currentBudget -= fee;
                _ownedPlayerNames.add(player.name.trim().toLowerCase());
              });
              widget.onSignPlayer(player, fee);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppPalette.green,
                  content: Text(
                    'Signed ${player.name} for £${fee.toStringAsFixed(1)}M! Added to squad roster.',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              );
            },
            child: Text(
              'Sign for £${fee.toStringAsFixed(1)}M',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink = theme.colorScheme.onSurface;
    final inkMuted = ink.withValues(alpha: 0.65);
    final border = theme.dividerColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkBg : AppPalette.lightBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: inkMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.storefront_rounded, color: AppPalette.gold, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'TRANSFER MARKET & SCOUTING',
                            style: AppTypography.sectionHeader(AppPalette.gold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Budget: £${_currentBudget.toStringAsFixed(1)}M • ${widget.windowTitle}',
                        style: AppTypography.caption(inkMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.isWindowOpen
                        ? AppPalette.green.withValues(alpha: 0.15)
                        : AppPalette.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isWindowOpen ? Icons.lock_open_rounded : Icons.lock_clock_rounded,
                        size: 13,
                        color: widget.isWindowOpen ? AppPalette.green : AppPalette.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.isWindowOpen ? 'WINDOW OPEN' : 'WINDOW CLOSED',
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: widget.isWindowOpen ? AppPalette.green : AppPalette.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search player or club (e.g. Haaland, Salah, Real Madrid)...',
                hintStyle: AppTypography.bodySmall(inkMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _loadPlayers();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppPalette.gold),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Position Group Filter Chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildPositionChip('ALL', 'All Positions'),
                const SizedBox(width: 8),
                _buildPositionChip('GK', 'Goalkeepers'),
                const SizedBox(width: 8),
                _buildPositionChip('DEF', 'Defenders'),
                const SizedBox(width: 8),
                _buildPositionChip('MID', 'Midfielders'),
                const SizedBox(width: 8),
                _buildPositionChip('FWD', 'Attackers'),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Divider(color: border, height: 1),

          // Player List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _players.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_search_rounded, size: 48, color: AppPalette.gold),
                            const SizedBox(height: 12),
                            Text('No players found', style: AppTypography.titleMedium(ink)),
                            const SizedBox(height: 4),
                            Text(
                              'Try adjusting your search terms or position filter.',
                              style: AppTypography.caption(inkMuted),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        itemCount: _players.length,
                        separatorBuilder: (context, index) => Divider(color: border.withValues(alpha: 0.4), height: 1),
                        itemBuilder: (context, index) {
                          final player = _players[index];
                          final normName = player.name.trim().toLowerCase();
                          final isOwned = _ownedPlayerNames.contains(normName);
                          final fee = calculatePlayerValuation(player);
                          final canAfford = _currentBudget >= fee;
                          final isSquadFull = widget.userSquad.length >= 25;

                          return InkWell(
                            onTap: () => showPlayerDetailSheet(context, player),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  PlayerAvatar(name: player.name, size: 38),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                player.name,
                                                style: TextStyle(
                                                  fontFamily: AppTypography.fontFamily,
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: ink,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            PositionBadge(position: player.primaryPosition),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Age ${player.age?.toInt() ?? 26} • ${player.teamName} • ${player.nationality ?? ''}',
                                          style: AppTypography.caption(inkMuted),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Rating Pill
                                  StatBadge(value: player.overall, label: ''),
                                  const SizedBox(width: 10),

                                  // Fee & Action Button
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '£${fee.toStringAsFixed(1)}M',
                                        style: AppTypography.statNumber(
                                          canAfford ? AppPalette.gold : inkMuted,
                                          fontSize: 12.5,
                                          weight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (isOwned)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppPalette.green.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'IN SQUAD',
                                            style: AppTypography.caption(AppPalette.green)
                                                .copyWith(fontSize: 9, fontWeight: FontWeight.w800),
                                          ),
                                        )
                                      else if (!widget.isWindowOpen)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.lock_rounded, size: 9, color: inkMuted),
                                              const SizedBox(width: 3),
                                              Text(
                                                'LOCKED',
                                                style: AppTypography.caption(inkMuted)
                                                    .copyWith(fontSize: 9, fontWeight: FontWeight.w700),
                                              ),
                                            ],
                                          ),
                                        )
                                      else if (isSquadFull)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppPalette.red.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'SQUAD FULL',
                                            style: AppTypography.caption(AppPalette.red)
                                                .copyWith(fontSize: 9, fontWeight: FontWeight.w800),
                                          ),
                                        )
                                      else if (!canAfford)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'FUNDS LOW',
                                            style: AppTypography.caption(inkMuted)
                                                .copyWith(fontSize: 9, fontWeight: FontWeight.w700),
                                          ),
                                        )
                                      else
                                        SizedBox(
                                          height: 26,
                                          child: FilledButton(
                                            onPressed: () => _promptSignPlayer(player),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: AppPalette.gold,
                                              foregroundColor: isDark ? AppPalette.darkBg : Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                            child: const Text(
                                              'SIGN',
                                              style: TextStyle(
                                                fontFamily: AppTypography.bodyFamily,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionChip(String code, String label) {
    final isSelected = _selectedPositionGroup == code;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        setState(() => _selectedPositionGroup = code);
        _loadPlayers();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppPalette.gold
              : (isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppPalette.gold : Theme.of(context).dividerColor,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? (isDark ? AppPalette.darkBg : Colors.white)
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
