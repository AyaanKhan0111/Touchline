import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/player.dart';
import '../shared/widgets/almanac_card.dart';
import '../shared/widgets/player_avatar.dart';
import '../shared/widgets/player_search_field.dart';
import '../shared/widgets/puzzle_result_sheet.dart';
import '../shared/widgets/puzzle_timer_bar.dart';

class BingoSquare {
  final int index;
  final String title;
  final String description;
  final bool Function(Player) validator;
  final bool isFree;

  BingoSquare({
    required this.index,
    required this.title,
    required this.description,
    required this.validator,
    this.isFree = false,
  });
}

class BingoScreen extends ConsumerStatefulWidget {
  const BingoScreen({super.key});

  @override
  ConsumerState<BingoScreen> createState() => _BingoScreenState();
}

class _BingoScreenState extends ConsumerState<BingoScreen> {
  late List<BingoSquare> _squares;
  final Map<int, Player> _filledSquares = {};
  final Set<String> _usedPlayerIds = {};

  int _remainingSeconds = 360; // 6 minutes per Section 5.2
  Timer? _timer;
  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();
    _initBoard();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        t.cancel();
        _finishGame();
      }
    });
  }

  void _initBoard() {
    // 25 criteria pool per Section 5.2
    _squares = [
      BingoSquare(index: 0, title: 'Left-Footed', description: 'Preferred foot is left', validator: (p) => p.preferredFoot?.toLowerCase() == 'left'),
      BingoSquare(index: 1, title: 'Over 35', description: 'Age is 35 or older', validator: (p) => p.age != null && p.age! >= 35),
      BingoSquare(index: 2, title: '90+ Rating', description: 'Overall rating 90 or higher', validator: (p) => p.overall >= 90),
      BingoSquare(index: 3, title: 'South American', description: 'Brazil, Argentina, Uruguay, etc.', validator: (p) => ['Brazil', 'Argentina', 'Uruguay', 'Colombia', 'Chile'].contains(p.nationality)),
      BingoSquare(index: 4, title: 'Goalkeeper 85+', description: 'GK with rating 85+', validator: (p) => p.isGoalkeeper && p.overall >= 85),

      BingoSquare(index: 5, title: '100+ Goals', description: '100+ career goals recorded', validator: (p) => (p.careerGoals ?? 0) >= 100),
      BingoSquare(index: 6, title: '6\'4"+ (193cm+)', description: 'Height 193cm or taller', validator: (p) => (p.heightCm ?? 0) >= 193),
      BingoSquare(index: 7, title: 'Under 21', description: 'Age under 21 in season', validator: (p) => p.age != null && p.age! < 21),
      BingoSquare(index: 8, title: 'Played for RMA', description: 'Real Madrid squad member', validator: (p) => p.teamName.contains('Real Madrid')),
      BingoSquare(index: 9, title: 'African Star', description: 'Nigeria, Senegal, Egypt, Ivory Coast', validator: (p) => ['Nigeria', 'Senegal', 'Egypt', 'Ivory Coast', 'Cameroon', 'Ghana', 'Algeria', 'Morocco'].contains(p.nationality)),

      BingoSquare(index: 10, title: 'Shirt #10', description: 'Wore jersey #10', validator: (p) => p.shirtNumber == 10),
      BingoSquare(index: 11, title: 'Played for MUN', description: 'Manchester United member', validator: (p) => p.teamName.contains('Manchester United')),
      // Centre square is FREE per Section 5.2
      BingoSquare(index: 12, title: 'FREE SQUARE', description: 'Touchline Almanac Free Square', validator: (_) => true, isFree: true),
      BingoSquare(index: 13, title: 'French National', description: 'Nationality is France', validator: (p) => p.nationality == 'France'),
      BingoSquare(index: 14, title: '300+ Apps', description: '300+ career appearances', validator: (p) => (p.careerAppearances ?? 0) >= 300),

      BingoSquare(index: 15, title: 'Played for BAR', description: 'Barcelona squad member', validator: (p) => p.teamName.contains('Barcelona')),
      BingoSquare(index: 16, title: 'German National', description: 'Nationality is Germany', validator: (p) => p.nationality == 'Germany'),
      BingoSquare(index: 17, title: 'Spanish National', description: 'Nationality is Spain', validator: (p) => p.nationality == 'Spain'),
      BingoSquare(index: 18, title: 'Shirt #7', description: 'Wore jersey #7', validator: (p) => p.shirtNumber == 7),
      BingoSquare(index: 19, title: '90+ Pace', description: 'Pace rating 90 or higher', validator: (p) => p.pace >= 90),

      BingoSquare(index: 20, title: 'Italian National', description: 'Nationality is Italy', validator: (p) => p.nationality == 'Italy'),
      BingoSquare(index: 21, title: 'Played in Serie A', description: 'Juventus, Milan, Inter, Napoli, Roma', validator: (p) => ['Juventus', 'AC Milan', 'Inter', 'Napoli', 'AS Roma', 'Lazio'].any((c) => p.teamName.contains(c))),
      BingoSquare(index: 22, title: 'English National', description: 'Nationality is England', validator: (p) => p.nationality == 'England'),
      BingoSquare(index: 23, title: '85+ Physicality', description: 'PHY stat 85 or higher', validator: (p) => p.physicality >= 85),
      BingoSquare(index: 24, title: 'Shirt #9', description: 'Wore jersey #9', validator: (p) => p.shirtNumber == 9),
    ];
  }

  void _onSquareTapped(BingoSquare sq) {
    if (_isGameOver || sq.isFree) return;
    if (_filledSquares.containsKey(sq.index)) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              Text('BINGO SQUARE REQUIREMENT', style: AppTypography.sectionHeader(AppPalette.darkAccent)),
              const SizedBox(height: 6),
              Text(sq.title, style: AppTypography.titleMedium(Theme.of(context).colorScheme.onSurface)),
              Text(sq.description, style: AppTypography.bodySmall(AppPalette.lightInkMuted)),
              const SizedBox(height: 16),
              PlayerSearchField(
                autoFocus: true,
                hintText: 'Search player for this square...',
                onPlayerSelected: (player) {
                  Navigator.pop(context);
                  _submitPlayerForSquare(player, sq);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitPlayerForSquare(Player player, BingoSquare sq) {
    if (_usedPlayerIds.contains(player.playerId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${player.name} has already been used on this board!'), backgroundColor: AppPalette.negative),
      );
      return;
    }

    final isValid = sq.validator(player);
    if (isValid) {
      setState(() {
        _filledSquares[sq.index] = player;
        _usedPlayerIds.add(player.playerId);
      });
      if (_filledSquares.length == 24) { // 24 + 1 free = 25
        _finishGame();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${player.name} does not qualify for "${sq.title}"!'), backgroundColor: AppPalette.negative),
      );
    }
  }

  int _calculateCompletedLines() {
    int lines = 0;
    // Rows
    for (int r = 0; r < 5; r++) {
      bool full = true;
      for (int c = 0; c < 5; c++) {
        final idx = r * 5 + c;
        if (idx != 12 && !_filledSquares.containsKey(idx)) full = false;
      }
      if (full) lines++;
    }
    // Cols
    for (int c = 0; c < 5; c++) {
      bool full = true;
      for (int r = 0; r < 5; r++) {
        final idx = r * 5 + c;
        if (idx != 12 && !_filledSquares.containsKey(idx)) full = false;
      }
      if (full) lines++;
    }
    // Diagonals
    const diag1 = [0, 6, 12, 18, 24];
    if (diag1.every((idx) => idx == 12 || _filledSquares.containsKey(idx))) lines++;
    const diag2 = [4, 8, 12, 16, 20];
    if (diag2.every((idx) => idx == 12 || _filledSquares.containsKey(idx))) lines++;

    return lines;
  }

  void _finishGame() {
    _timer?.cancel();
    setState(() => _isGameOver = true);

    final squaresFilled = _filledSquares.length + 1; // + free square
    final lines = _calculateCompletedLines();
    final isFullHouse = squaresFilled == 25;

    // Scoring per Section 5.2: 2 pts per square, +10 per line, +40 for full house
    int score = (squaresFilled * 2) + (lines * 10) + (isFullHouse ? 40 : 0);
    int coins = score ~/ 5;

    final buffer = StringBuffer();
    buffer.writeln('Touchline Bingo: $squaresFilled/25 squares, $lines lines ($score pts)!');
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 5; c++) {
        final idx = r * 5 + c;
        buffer.write((idx == 12 || _filledSquares.containsKey(idx)) ? '🟩' : '⬜');
      }
      buffer.writeln();
    }

    showPuzzleResultSheet(
      context: context,
      ref: ref,
      modeTitle: 'Bingo',
      modeCode: 'BINGO',
      score: score,
      maxScore: 190,
      timeSeconds: 360 - _remainingSeconds,
      coinsEarned: coins,
      shareableText: buffer.toString(),
      onPlayAgain: () {
        setState(() {
          _filledSquares.clear();
          _usedPlayerIds.clear();
          _remainingSeconds = 360;
          _isGameOver = false;
        });
        _initBoard();
        _startTimer();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppPalette.darkInk : AppPalette.lightInk;
    final inkMuted = isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted;
    final border = isDark ? AppPalette.darkBorder : AppPalette.lightBorder;

    final lines = _calculateCompletedLines();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bingo', style: AppTypography.heading(ink, fontSize: 22)),
            Text('5×5 Knowledge Board', style: AppTypography.bodySmall(inkMuted)),
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
                const Icon(Icons.grid_on_rounded, size: 14, color: AppPalette.green),
                const SizedBox(width: 6),
                Text(
                  '$lines lines complete',
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
            // Timer Bar
            PuzzleTimerBar(remainingSeconds: _remainingSeconds, totalSeconds: 360),
            const SizedBox(height: 16),

            // 5x5 Bingo Board
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 25,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 0.95,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemBuilder: (context, index) {
                final sq = _squares[index];
                final answer = _filledSquares[index];
                final isFilled = sq.isFree || answer != null;

                return InkWell(
                  onTap: () => _onSquareTapped(sq),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isFilled
                          ? AppPalette.positive.withValues(alpha: 0.15)
                          : (isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isFilled ? AppPalette.positive.withValues(alpha: 0.6) : border,
                        width: isFilled ? 1.5 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: sq.isFree
                        ? Center(
                            child: Text(
                              'FREE\n★',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.warn,
                              ),
                            ),
                          )
                        : answer != null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  PlayerAvatar(name: answer.name, size: 20),
                                  const SizedBox(height: 2),
                                  Text(
                                    answer.name,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: ink,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              )
                            : Center(
                                child: Text(
                                  sq.title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: ink,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            AlmanacCard(
              sectionTitle: 'BINGO SCORING REGISTER',
              child: Text(
                '• 2 pts per square filled (+1 for free center).\n'
                '• +10 bonus pts per completed line (horizontal, vertical, diagonal).\n'
                '• +40 bonus pts for a Full House (all 25 squares). Coins = score ÷ 5.',
                style: AppTypography.caption(inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
