import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/database/db_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/player.dart';
import '../../domain/services/transfer_market_service.dart';
import '../search/player_detail_sheet.dart';
import '../shared/widgets/player_avatar.dart';
import '../shared/widgets/stat_badge.dart';
import 'career_screen.dart';

/// Categories available in the expanded Transfer Market (Fix 30 / User Fix 8)
enum MarketCategory {
  all('ALL', 'All Stars', Icons.stars_rounded),
  freeAgents('FREE', 'Free Agents (£0)', Icons.money_off_csred_rounded),
  expiring('EXPIRING', 'Expiring (50% Off)', Icons.hourglass_bottom_rounded),
  wonderkids('WONDERKIDS', 'Wonderkids', Icons.diamond_rounded),
  valueGems('VALUE', 'Value Gems (<£15M)', Icons.sell_rounded);

  final String id;
  final String label;
  final IconData icon;
  const MarketCategory(this.id, this.label, this.icon);
}

/// Modal bottom sheet for Scouting & Signing players with expanded tiers, free agents, and expiring contracts (Fix 30)
class TransferMarketSheet extends StatefulWidget {
  final double budget;
  final bool isWindowOpen;
  final String windowTitle;
  final List<Player> userSquad;
  final Function(Player player, double fee, [int contractYears]) onSignPlayer;
  final int currentSeason;
  final int pendingOffersCount;
  final VoidCallback? onViewOffers;

  const TransferMarketSheet({
    super.key,
    required this.budget,
    required this.isWindowOpen,
    required this.windowTitle,
    required this.userSquad,
    required this.onSignPlayer,
    this.currentSeason = 1,
    this.pendingOffersCount = 0,
    this.onViewOffers,
  });

  @override
  State<TransferMarketSheet> createState() => _TransferMarketSheetState();
}

class _TransferMarketSheetState extends State<TransferMarketSheet> {
  final TextEditingController _searchController = TextEditingController();
  MarketCategory _selectedCategory = MarketCategory.all;
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
      final searchClause = query.isNotEmpty
          ? " AND (player_name LIKE ? OR player_name_clean LIKE ? OR team_name LIKE ?)"
          : "";
      final searchParams = query.isNotEmpty
          ? ['%$query%', '%$query%', '%$query%']
          : <Object>[];

      List<Player> loaded = [];

      switch (_selectedCategory) {
        case MarketCategory.all:
          final rows = await db.rawQuery('''
            SELECT *
            FROM players
            WHERE season >= 2022 $posWhere $searchClause
            GROUP BY player_name
            ORDER BY MAX(overall) DESC
            LIMIT 60
          ''', searchParams);
          loaded = rows.map((r) => Player.fromMap(r)).toList();
          if (loaded.isEmpty && query.isNotEmpty) {
            final fallbackRows = await db.rawQuery('''
              SELECT *
              FROM players
              WHERE 1=1 $posWhere $searchClause
              GROUP BY player_name
              ORDER BY MAX(overall) DESC
              LIMIT 60
            ''', searchParams);
            loaded = fallbackRows.map((r) => Player.fromMap(r)).toList();
          }
          break;

        case MarketCategory.freeAgents:
          final rows = await db.rawQuery('''
            SELECT *
            FROM players
            WHERE season >= 2022 $posWhere $searchClause
            GROUP BY player_name
            ORDER BY MAX(overall) DESC
            LIMIT 250
          ''', searchParams);
          final candidates = rows.map((r) => Player.fromMap(r)).toList();
          loaded = candidates.where((p) {
            final status = TransferMarketService.computePlayerContract(p.name, widget.currentSeason);
            return status.isFreeAgent;
          }).take(60).toList();
          break;

        case MarketCategory.expiring:
          final rows = await db.rawQuery('''
            SELECT *
            FROM players
            WHERE season >= 2022 $posWhere $searchClause
            GROUP BY player_name
            ORDER BY MAX(overall) DESC
            LIMIT 250
          ''', searchParams);
          final candidates = rows.map((r) => Player.fromMap(r)).toList();
          loaded = candidates.where((p) {
            final status = TransferMarketService.computePlayerContract(p.name, widget.currentSeason);
            return status.isExpiring;
          }).take(60).toList();
          break;

        case MarketCategory.wonderkids:
          // 1. Academy prospects
          final academy = TransferMarketService.generateYouthProspects(widget.currentSeason)
              .where((p) {
                if (query.isNotEmpty) {
                  final qLower = query.toLowerCase();
                  if (!p.name.toLowerCase().contains(qLower) &&
                      !(p.nationality?.toLowerCase().contains(qLower) ?? false)) {
                    return false;
                  }
                }
                if (_selectedPositionGroup == 'GK') return p.primaryPosition == 'GK';
                if (_selectedPositionGroup == 'DEF') return const ['CB', 'LB', 'RB', 'LWB', 'RWB'].contains(p.primaryPosition);
                if (_selectedPositionGroup == 'MID') return const ['CM', 'CAM', 'CDM', 'LM', 'RM'].contains(p.primaryPosition);
                if (_selectedPositionGroup == 'FWD') return const ['ST', 'CF', 'LW', 'RW'].contains(p.primaryPosition);
                return true;
              }).toList();

          // 2. Database wonderkids
          final rows = await db.rawQuery('''
            SELECT *
            FROM players
            WHERE season >= 2022 AND age <= 21 AND potential >= 80 $posWhere $searchClause
            GROUP BY player_name
            ORDER BY MAX(potential) DESC
            LIMIT 45
          ''', searchParams);
          final dbWonderkids = rows.map((r) => Player.fromMap(r)).toList();

          final seen = <String>{};
          for (final p in academy) {
            seen.add(p.name.trim().toLowerCase());
            loaded.add(p);
          }
          for (final p in dbWonderkids) {
            if (seen.add(p.name.trim().toLowerCase())) {
              loaded.add(p);
            }
          }
          break;

        case MarketCategory.valueGems:
          final rows = await db.rawQuery('''
            SELECT *
            FROM players
            WHERE season >= 2022 AND overall BETWEEN 73 AND 83 $posWhere $searchClause
            GROUP BY player_name
            ORDER BY MAX(overall) DESC
            LIMIT 100
          ''', searchParams);
          final candidates = rows.map((r) => Player.fromMap(r)).toList();
          loaded = candidates.where((p) => calculatePlayerValuation(p) <= 15.0).take(60).toList();
          break;
      }

      if (mounted) {
        setState(() {
          _players = loaded;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _promptSignPlayer(Player player, ContractStatus contractStatus, double effectiveFee) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink = theme.colorScheme.onSurface;

    // Calculate signed contract duration: Free Agents = 2 yrs, Wonderkids = 4 yrs, Standard = 3 yrs
    final isWonderkid = (player.potential ?? 0) > player.overall && (player.age ?? 25) <= 21;
    final contractYears = contractStatus.isFreeAgent ? 2 : (isWonderkid ? 4 : 3);

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
                color: contractStatus.isFreeAgent
                    ? AppPalette.green.withValues(alpha: 0.12)
                    : AppPalette.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: contractStatus.isFreeAgent
                      ? AppPalette.green.withValues(alpha: 0.3)
                      : AppPalette.gold.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Transfer Fee:', style: AppTypography.caption(ink)),
                      Text(
                        contractStatus.isFreeAgent
                            ? 'FREE (£0.0M)'
                            : (contractStatus.isExpiring
                                ? '£${effectiveFee.toStringAsFixed(1)}M (50% OFF)'
                                : '£${effectiveFee.toStringAsFixed(1)}M'),
                        style: AppTypography.statNumber(
                          contractStatus.isFreeAgent ? AppPalette.green : AppPalette.gold,
                          fontSize: 13,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Contract Offered:', style: AppTypography.caption(ink)),
                      Text(
                        '$contractYears Seasons',
                        style: AppTypography.statNumber(AppPalette.gold, fontSize: 12.5, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Remaining War Chest:', style: AppTypography.caption(ink)),
                      Text(
                        '£${(_currentBudget - effectiveFee).toStringAsFixed(1)}M',
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
              backgroundColor: contractStatus.isFreeAgent ? AppPalette.green : AppPalette.gold,
              foregroundColor: isDark ? AppPalette.darkBg : Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _currentBudget -= effectiveFee;
                _ownedPlayerNames.add(player.name.trim().toLowerCase());
              });
              widget.onSignPlayer(player, effectiveFee, contractYears);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppPalette.green,
                  content: Text(
                    contractStatus.isFreeAgent
                        ? 'Signed Free Agent ${player.name} on a $contractYears-season deal! Added to squad roster.'
                        : 'Signed ${player.name} for £${effectiveFee.toStringAsFixed(1)}M ($contractYears seasons)! Added to squad roster.',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              );
            },
            child: Text(
              contractStatus.isFreeAgent ? 'Sign Free Agent (£0)' : 'Sign for £${effectiveFee.toStringAsFixed(1)}M',
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
      height: MediaQuery.of(context).size.height * 0.92,
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
                if (widget.pendingOffersCount > 0) ...[
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onViewOffers?.call();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppPalette.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppPalette.gold.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mark_email_unread_rounded, size: 13, color: AppPalette.gold),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.pendingOffersCount} BIDS',
                            style: const TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
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
                hintText: 'Search player or club (e.g. Haaland, Mbappe, Real Madrid)...',
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

          const SizedBox(height: 8),

          // Category Filter Chips (Fix 30: All Stars, Free Agents, Expiring, Wonderkids, Value Gems)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: MarketCategory.values.map((cat) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildCategoryChip(cat),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Position Group Filter Chips
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildPositionChip('ALL', 'All Positions'),
                const SizedBox(width: 6),
                _buildPositionChip('GK', 'Goalkeepers'),
                const SizedBox(width: 6),
                _buildPositionChip('DEF', 'Defenders'),
                const SizedBox(width: 6),
                _buildPositionChip('MID', 'Midfielders'),
                const SizedBox(width: 6),
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
                            Text('No players found in this category', style: AppTypography.titleMedium(ink)),
                            const SizedBox(height: 4),
                            Text(
                              'Try adjusting your search terms or category filter.',
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

                          final contractStatus = _selectedCategory == MarketCategory.freeAgents
                              ? const ContractStatus(
                                  seasonsRemaining: 0,
                                  isFreeAgent: true,
                                  isExpiring: false,
                                  discountMultiplier: 0.0,
                                  statusBadge: 'FREE AGENT (£0)',
                                  badgeColor: AppPalette.green,
                                )
                              : (_selectedCategory == MarketCategory.expiring
                                  ? const ContractStatus(
                                      seasonsRemaining: 1,
                                      isFreeAgent: false,
                                      isExpiring: true,
                                      discountMultiplier: 0.5,
                                      statusBadge: '1 YR (50% OFF)',
                                      badgeColor: AppPalette.warn,
                                    )
                                  : TransferMarketService.computePlayerContract(player.name, widget.currentSeason));

                          final baseValuation = calculatePlayerValuation(player);
                          final fee = TransferMarketService.calculateEffectiveTransferFee(
                            baseValuation: baseValuation,
                            contractStatus: contractStatus,
                          );

                          final canAfford = _currentBudget >= fee;
                          final isSquadFull = widget.userSquad.length >= 25;
                          final isWonderkid = (player.potential ?? 0) > player.overall && (player.age ?? 25) <= 21;

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
                                        const SizedBox(height: 3),
                                        // Metadata & Contract status tags
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Age ${player.age?.toInt() ?? 26} • ${player.teamName}',
                                                style: AppTypography.caption(inkMuted),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (contractStatus.isFreeAgent) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: AppPalette.green.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(3),
                                                  border: Border.all(color: AppPalette.green.withValues(alpha: 0.4)),
                                                ),
                                                child: const Text(
                                                  'FREE AGENT',
                                                  style: TextStyle(
                                                    fontFamily: AppTypography.fontFamily,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppPalette.green,
                                                  ),
                                                ),
                                              ),
                                            ] else if (contractStatus.isExpiring) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: AppPalette.warn.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(3),
                                                  border: Border.all(color: AppPalette.warn.withValues(alpha: 0.4)),
                                                ),
                                                child: const Text(
                                                  '1 YR LEFT • 50% OFF',
                                                  style: TextStyle(
                                                    fontFamily: AppTypography.fontFamily,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppPalette.warn,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            if (isWonderkid) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: AppPalette.cyan.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(3),
                                                  border: Border.all(color: AppPalette.cyan.withValues(alpha: 0.4)),
                                                ),
                                                child: Text(
                                                  '💎 POT ${player.potential?.round()}',
                                                  style: const TextStyle(
                                                    fontFamily: AppTypography.fontFamily,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppPalette.cyan,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
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
                                      if (contractStatus.isFreeAgent)
                                        Text(
                                          'FREE',
                                          style: AppTypography.statNumber(
                                            AppPalette.green,
                                            fontSize: 13,
                                            weight: FontWeight.w900,
                                          ),
                                        )
                                      else
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
                                            onPressed: () => _promptSignPlayer(player, contractStatus, fee),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: contractStatus.isFreeAgent ? AppPalette.green : AppPalette.gold,
                                              foregroundColor: isDark ? AppPalette.darkBg : Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                            child: Text(
                                              contractStatus.isFreeAgent ? 'SIGN FREE' : 'SIGN',
                                              style: const TextStyle(
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

  Widget _buildCategoryChip(MarketCategory category) {
    final isSelected = _selectedCategory == category;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color activeColor = AppPalette.gold;
    if (category == MarketCategory.freeAgents) {
      activeColor = AppPalette.green;
    } else if (category == MarketCategory.expiring) {
      activeColor = AppPalette.warn;
    } else if (category == MarketCategory.wonderkids) {
      activeColor = AppPalette.cyan;
    }

    return InkWell(
      onTap: () {
        setState(() => _selectedCategory = category);
        _loadPlayers();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.22)
              : (isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : Theme.of(context).dividerColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              size: 13,
              color: isSelected ? activeColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 5),
            Text(
              category.label,
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeColor : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            fontSize: 11,
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
