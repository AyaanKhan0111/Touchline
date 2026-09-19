import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/db_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/player.dart';
import '../../domain/services/puzzle_generator.dart';
import '../../domain/services/rarity_calculator.dart';
import '../search/player_detail_sheet.dart';
import '../shared/widgets/almanac_card.dart';
import '../shared/widgets/player_avatar.dart';
import '../shared/widgets/player_search_field.dart';
import '../shared/widgets/puzzle_result_sheet.dart';

class GridScreen extends ConsumerStatefulWidget {
  final int? seed;
  const GridScreen({super.key, this.seed});

  @override
  ConsumerState<GridScreen> createState() => _GridScreenState();
}

class _GridScreenState extends ConsumerState<GridScreen> {
  GridPuzzle? _puzzle;
  bool _isLoading = true;

  // Grid state: 3x3 cells (0..8)
  final Map<int, Player> _cellAnswers = {};
  final Map<int, int> _cellRarity = {};
  final Set<String> _usedPlayerIds = {};
  final Set<String> _usedPlayerNames = {};

  int _guessesRemaining = 9; // Section 5.1: 9 guesses total
  int _secondsElapsed = 0;
  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();
    _loadPuzzle();
  }

  Future<void> _loadPuzzle() async {
    setState(() => _isLoading = true);
    final puzzle = await PuzzleGenerator.generateValidGrid(widget.seed);
    setState(() {
      _puzzle = puzzle;
      _isLoading = false;
    });
  }

  void _onCellTapped(int row, int col) {
    if (_isGameOver || _guessesRemaining <= 0) return;
    SoundService.instance.playClick();
    final cellIndex = row * 3 + col;
    if (_cellAnswers.containsKey(cellIndex)) {
      // Show details of filled player
      showPlayerDetailSheet(context, _cellAnswers[cellIndex]!);
      return;
    }

    _showPlayerSearchSheet(row, col, cellIndex);
  }

  void _showPlayerSearchSheet(int row, int col, int cellIndex) {
    final rowCat = _puzzle!.rowCategories[row];
    final colCat = _puzzle!.colCategories[col];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppPalette.darkSurfaceRaised
                  : AppPalette.lightSurfaceRaised,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CRITERIA REQUIREMENT',
                      style: AppTypography.sectionHeader(AppPalette.gold),
                    ),
                    Text(
                      '$_guessesRemaining left',
                      style: AppTypography.caption(AppPalette.gold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${rowCat.title}  ×  ${colCat.title}',
                  style: AppTypography.titleMedium(
                    Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All clubs & nations from their career count',
                  style: AppTypography.caption(AppPalette.gold),
                ),
                const SizedBox(height: 16),
                PlayerSearchField(
                  autoFocus: true,
                  hintText: 'Search player name...',
                  onPlayerSelected: (player) {
                    Navigator.pop(context);
                    _submitPlayerForCell(player, row, col, cellIndex);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitPlayerForCell(Player player, int row, int col, int cellIndex) async {
    // Check once-only rule
    final normalizedName = player.name.trim().toLowerCase();
    if (_usedPlayerIds.contains(player.playerId) || _usedPlayerNames.contains(normalizedName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${player.name} has already been used on this grid!'),
          backgroundColor: AppPalette.negative,
        ),
      );
      return;
    }

    final db = await DatabaseService.instance.database;
    final rowCat = _puzzle!.rowCategories[row];
    final colCat = _puzzle!.colCategories[col];

    final isValid = await PuzzleGenerator.validatePlayerForCell(db, player, rowCat, colCat);

    setState(() {
      _guessesRemaining--;
      if (isValid) {
        _cellAnswers[cellIndex] = player;
        _usedPlayerIds.add(player.playerId);
        _usedPlayerNames.add(normalizedName);
      }
    });

    if (isValid) {
      SoundService.instance.playCorrect();
      // Calculate cell rarity score
      final validAnswers = await PuzzleGenerator.getValidAnswersForCell(db, rowCat, colCat);
      final rarity = RarityCalculator.calculateRarityScore(player, validAnswers);
      setState(() {
        _cellRarity[cellIndex] = rarity;
      });
    } else {
      SoundService.instance.playWrong();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${player.name} does not meet both criteria!'),
            backgroundColor: AppPalette.negative,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    // Check game over (9 guesses spent or all 9 cells filled)
    if (_guessesRemaining <= 0 || _cellAnswers.length == 9) {
      _finishGame();
    }
  }

  void _finishGame() {
    setState(() => _isGameOver = true);
    final correctCount = _cellAnswers.length;
    final totalRarity = _cellRarity.values.fold<int>(0, (sum, val) => sum + val);

    if (correctCount >= 6) {
      SoundService.instance.playGoal();
    } else {
      SoundService.instance.playWhistle();
    }

    // Coins: 1 per cell, +5 for 9/9, +10 if rarity < 100
    int coins = correctCount;
    if (correctCount == 9) coins += 5;
    if (correctCount == 9 && totalRarity < 100) coins += 10;

    // Build Wordle-style shareable emoji grid
    final buffer = StringBuffer();
    buffer.writeln('Touchline Grid: $correctCount/9 ($totalRarity%)');
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        final idx = r * 3 + c;
        buffer.write(_cellAnswers.containsKey(idx) ? '🟩' : '⬜');
      }
      buffer.writeln();
    }

    showPuzzleResultSheet(
      context: context,
      ref: ref,
      modeTitle: 'The Grid',
      modeCode: 'GRID',
      score: correctCount,
      maxScore: 9,
      timeSeconds: _secondsElapsed,
      coinsEarned: coins,
      rarityScore: totalRarity.toDouble(),
      shareableText: buffer.toString(),
      onPlayAgain: () {
        setState(() {
          _cellAnswers.clear();
          _cellRarity.clear();
          _usedPlayerIds.clear();
          _usedPlayerNames.clear();
          _guessesRemaining = 9;
          _secondsElapsed = 0;
          _isGameOver = false;
        });
        _loadPuzzle();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppPalette.darkInk : AppPalette.lightInk;
    final inkMuted = isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted;
    final border = isDark ? AppPalette.darkBorder : AppPalette.lightBorder;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('THE NINE — GRID')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final totalRarity = _cellRarity.values.fold<int>(0, (sum, val) => sum + val);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grid', style: AppTypography.heading(ink, fontSize: 22)),
            Text('3×3 Category Cross', style: AppTypography.bodySmall(inkMuted)),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppPalette.darkBorder : AppPalette.lightBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.touch_app_outlined, size: 14, color: AppPalette.gold),
                const SizedBox(width: 6),
                Text(
                  '$_guessesRemaining picks left',
                  style: AppTypography.statNumber(ink, fontSize: 12, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SOLVED: ${_cellAnswers.length} / 9',
                  style: AppTypography.sectionHeader(inkMuted),
                ),
                Text(
                  'TOTAL RARITY: $totalRarity%',
                  style: AppTypography.statNumber(AppPalette.gold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3x3 Grid Board
            _buildGridBoard(context, border, ink, inkMuted, isDark),

            const SizedBox(height: 20),

            AlmanacCard(
              sectionTitle: 'HOW TO PLAY',
              child: Text(
                '• 9 guesses total. Pick one player per cell satisfying both column & row.\n'
                '• Once-only rule: Each player can only be used once across the entire grid.\n'
                '• Rarity scoring: Obscure correct answers score lower percentages. Perfect 9 with <100% total gives IMMACULATE status (+10 bonus coins).',
                style: AppTypography.caption(inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridBoard(BuildContext context, Color border, Color ink, Color inkMuted, bool isDark) {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FlexColumnWidth(1.1),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1.2),
      },
      children: [
        // Header row (columns 1, 2, 3)
        TableRow(
          children: [
            const SizedBox.shrink(), // Top-left empty corner
            _buildHeaderCell(_puzzle!.colCategories[0], ink, inkMuted, border, isDark),
            _buildHeaderCell(_puzzle!.colCategories[1], ink, inkMuted, border, isDark),
            _buildHeaderCell(_puzzle!.colCategories[2], ink, inkMuted, border, isDark),
          ],
        ),
        // Grid Row 0
        TableRow(
          children: [
            _buildHeaderCell(_puzzle!.rowCategories[0], ink, inkMuted, border, isDark),
            _buildGridCell(0, 0, border, ink, isDark),
            _buildGridCell(0, 1, border, ink, isDark),
            _buildGridCell(0, 2, border, ink, isDark),
          ],
        ),
        // Grid Row 1
        TableRow(
          children: [
            _buildHeaderCell(_puzzle!.rowCategories[1], ink, inkMuted, border, isDark),
            _buildGridCell(1, 0, border, ink, isDark),
            _buildGridCell(1, 1, border, ink, isDark),
            _buildGridCell(1, 2, border, ink, isDark),
          ],
        ),
        // Grid Row 2
        TableRow(
          children: [
            _buildHeaderCell(_puzzle!.rowCategories[2], ink, inkMuted, border, isDark),
            _buildGridCell(2, 0, border, ink, isDark),
            _buildGridCell(2, 1, border, ink, isDark),
            _buildGridCell(2, 2, border, ink, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderCell(GridCategory cat, Color ink, Color inkMuted, Color border, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      margin: const EdgeInsets.all(2),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cat.title.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            cat.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 9,
              color: inkMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGridCell(int row, int col, Color border, Color ink, bool isDark) {
    final cellIndex = row * 3 + col;
    final answer = _cellAnswers[cellIndex];
    final rarity = _cellRarity[cellIndex];

    return AspectRatio(
      aspectRatio: 1.0,
      child: InkWell(
        onTap: () => _onCellTapped(row, col),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: answer != null
                ? AppPalette.positive.withValues(alpha: 0.12)
                : (isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: answer != null ? AppPalette.positive.withValues(alpha: 0.6) : border,
              width: answer != null ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.all(6),
          child: answer != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PlayerAvatar(name: answer.name, size: 28),
                    const SizedBox(height: 4),
                    Text(
                      answer.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (rarity != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$rarity%',
                        style: AppTypography.statNumber(
                          AppPalette.darkAccent,
                          fontSize: 10,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                )
              : Center(
                  child: Icon(
                    Icons.add,
                    size: 18,
                    color: isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted,
                  ),
                ),
        ),
      ),
    );
  }
}
