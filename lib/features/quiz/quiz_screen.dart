import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/db_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/player.dart';
import '../shared/widgets/almanac_card.dart';
import '../shared/widgets/puzzle_result_sheet.dart';

class QuizQuestion {
  final String questionText;
  final String category;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestion({
    required this.questionText,
    required this.category,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  final List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedOption;
  bool _answered = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateQuiz();
  }

  Future<void> _generateQuiz() async {
    setState(() => _isLoading = true);
    final db = await DatabaseService.instance.database;

    // Fetch random star players to generate dynamic factual questions
    final results = await db.rawQuery('''
      SELECT * FROM players
      WHERE overall >= 82 AND nationality IS NOT NULL AND career_goals IS NOT NULL
      ORDER BY RANDOM()
      LIMIT 25
    ''');

    final players = results.map((r) => Player.fromMap(r)).toList();
    final rng = Random();

    final generated = <QuizQuestion>[];

    // Q1: Nationality question
    if (players.length >= 4) {
      final target = players[0];
      final correct = target.nationality!;
      final wrongNations = ['England', 'France', 'Spain', 'Germany', 'Brazil', 'Argentina', 'Italy', 'Portugal', 'Netherlands']
          .where((n) => n != correct)
          .toList()..shuffle(rng);
      final opts = [correct, wrongNations[0], wrongNations[1], wrongNations[2]]..shuffle(rng);
      generated.add(QuizQuestion(
        questionText: 'What is the official nationality of ${target.name}?',
        category: 'NATIONALITY',
        options: opts,
        correctIndex: opts.indexOf(correct),
        explanation: '${target.name} represents $correct.',
      ));
    }

    // Q2: Career goals comparison
    if (players.length >= 6) {
      final p1 = players[1];
      final p2 = players[2];
      final g1 = (p1.careerGoals ?? 0).toInt();
      final g2 = (p2.careerGoals ?? 0).toInt();
      final more = g1 >= g2 ? p1 : p2;
      final opts = [p1.name, p2.name]..shuffle(rng);
      generated.add(QuizQuestion(
        questionText: 'Who has recorded more career senior goals on record: ${p1.name} or ${p2.name}?',
        category: 'CAREER STATS',
        options: opts,
        correctIndex: opts.indexOf(more.name),
        explanation: '${p1.name} has $g1 goals vs ${p2.name} with $g2 goals.',
      ));
    }

    // Q3: Position question
    if (players.length >= 8) {
      final target = players[3];
      final correct = target.primaryPosition;
      final wrongPos = ['ST', 'CB', 'CM', 'CAM', 'GK', 'RW', 'LB', 'CDM']
          .where((p) => p != correct)
          .toList()..shuffle(rng);
      final opts = [correct, wrongPos[0], wrongPos[1], wrongPos[2]]..shuffle(rng);
      generated.add(QuizQuestion(
        questionText: 'What is ${target.name}\'s primary registered tactical position?',
        category: 'TACTICAL POSITION',
        options: opts,
        correctIndex: opts.indexOf(correct),
        explanation: '${target.name} is primarily registered as $correct.',
      ));
    }

    // Q4: Club question
    if (players.length >= 10) {
      final target = players[4];
      final correct = target.teamName;
      final wrongClubs = ['Real Madrid', 'Barcelona', 'Manchester United', 'Liverpool', 'Bayern Munich', 'Chelsea', 'Arsenal']
          .where((c) => !target.teamName.contains(c))
          .toList()..shuffle(rng);
      final opts = [correct, wrongClubs[0], wrongClubs[1], wrongClubs[2]]..shuffle(rng);
      generated.add(QuizQuestion(
        questionText: 'Which squad did ${target.name} represent in the ${target.season} season snapshot?',
        category: 'CLUB ROSTERS',
        options: opts,
        correctIndex: opts.indexOf(correct),
        explanation: '${target.name} featured for $correct in ${target.season}.',
      ));
    }

    // Q5: Overall Rating comparison
    if (players.length >= 14) {
      final slice = players.sublist(5, 9)..sort((a, b) => b.overall.compareTo(a.overall));
      final highest = slice.first;
      final opts = slice.map((p) => p.name).toList()..shuffle(rng);
      generated.add(QuizQuestion(
        questionText: 'Which of the following footballers boasts the highest overall rating (OVR) in our database?',
        category: 'RATINGS MATRIX',
        options: opts,
        correctIndex: opts.indexOf(highest.name),
        explanation: '${highest.name} leads with an OVR rating of ${highest.overall}.',
      ));
    }

    setState(() {
      _questions.addAll(generated);
      _isLoading = false;
    });
  }

  void _chooseOption(int index) {
    if (_answered) return;
    setState(() {
      _selectedOption = index;
      _answered = true;
      if (index == _questions[_currentIndex].correctIndex) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _answered = false;
      });
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    final coins = _score * 2;
    final buffer = StringBuffer();
    buffer.writeln('Touchline Interrogation: $_score/${_questions.length} correct!');
    for (int i = 0; i < _score; i++) {
      buffer.write('🟩');
    }
    for (int i = 0; i < (_questions.length - _score); i++) {
      buffer.write('⬜');
    }

    showPuzzleResultSheet(
      context: context,
      ref: ref,
      modeTitle: 'Trivia Quiz',
      modeCode: 'QUIZ',
      score: _score,
      maxScore: _questions.length,
      timeSeconds: 90,
      coinsEarned: coins,
      shareableText: buffer.toString(),
      onPlayAgain: () {
        setState(() {
          _questions.clear();
          _currentIndex = 0;
          _score = 0;
          _selectedOption = null;
          _answered = false;
        });
        _generateQuiz();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppPalette.darkInk : AppPalette.lightInk;
    final inkMuted = isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted;
    final border = isDark ? AppPalette.darkBorder : AppPalette.lightBorder;

    if (_isLoading || _questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trivia Quiz')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final q = _questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trivia Quiz', style: AppTypography.heading(ink, fontSize: 22)),
            Text('Question ${_currentIndex + 1} of ${_questions.length}', style: AppTypography.bodySmall(inkMuted)),
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
                const Icon(Icons.star_outline_rounded, size: 14, color: AppPalette.gold),
                const SizedBox(width: 6),
                Text(
                  'Score: $_score/${_questions.length}',
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
            // Question Card
            AlmanacCard(
              sectionTitle: q.category,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.questionText,
                    style: AppTypography.titleMedium(ink).copyWith(fontSize: 18),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Multiple Choice Options
            ...List.generate(q.options.length, (idx) {
              final opt = q.options[idx];
              Color optBg = isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised;
              Color optBorder = border;

              if (_answered) {
                if (idx == q.correctIndex) {
                  optBg = AppPalette.positive.withValues(alpha: 0.15);
                  optBorder = AppPalette.positive;
                } else if (idx == _selectedOption) {
                  optBg = AppPalette.negative.withValues(alpha: 0.15);
                  optBorder = AppPalette.negative;
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => _chooseOption(idx),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: optBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: optBorder, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: inkMuted),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            String.fromCharCode(65 + idx), // A, B, C, D
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            opt,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),

            // Explanation & Next Button
            if (_answered) ...[
              AlmanacCard(
                borderColor: _selectedOption == q.correctIndex ? AppPalette.positive : AppPalette.warn,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _selectedOption == q.correctIndex ? 'CORRECT VERDICT' : 'FACTUAL RECORD',
                      style: AppTypography.sectionHeader(
                        _selectedOption == q.correctIndex ? AppPalette.positive : AppPalette.warn,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(q.explanation, style: AppTypography.bodySmall(ink)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _nextQuestion,
                      child: Text(_currentIndex < _questions.length - 1 ? 'NEXT QUESTION →' : 'VIEW FINAL RESULTS'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
