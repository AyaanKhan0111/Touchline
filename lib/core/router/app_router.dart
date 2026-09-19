import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../storage/prefs_service.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/hub/hub_screen.dart';
import '../../features/debug/debug_screen.dart';
import '../../features/grid/grid_screen.dart';
import '../../features/identikit/identikit_screen.dart';
import '../../features/higher_lower/higher_lower_screen.dart';
import '../../features/goal_chase/goal_chase_screen.dart';
import '../../features/bingo/bingo_screen.dart';
import '../../features/connections/connections_screen.dart';
import '../../features/frankenstein/frankenstein_screen.dart';
import '../../features/quiz/quiz_screen.dart';
import '../../features/career/career_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) async {
          final isDone = await PrefsService.instance.isOnboardingCompleted();
          return isDone ? '/hub' : '/onboarding';
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/hub',
        builder: (context, state) => const HubScreen(),
      ),
      GoRoute(
        path: '/debug',
        builder: (context, state) => const DebugScreen(),
      ),
      GoRoute(
        path: '/grid',
        builder: (context, state) => const GridScreen(),
      ),
      GoRoute(
        path: '/identikit',
        builder: (context, state) => const IdentikitScreen(),
      ),
      GoRoute(
        path: '/higher_lower',
        builder: (context, state) => const HigherLowerScreen(),
      ),
      GoRoute(
        path: '/goal_chase',
        builder: (context, state) => const GoalChaseScreen(),
      ),
      GoRoute(
        path: '/bingo',
        builder: (context, state) => const BingoScreen(),
      ),
      GoRoute(
        path: '/connections',
        builder: (context, state) => const ConnectionsScreen(),
      ),
      GoRoute(
        path: '/frankenstein',
        builder: (context, state) => const FrankensteinScreen(),
      ),
      GoRoute(
        path: '/quiz',
        builder: (context, state) => const QuizScreen(),
      ),
      GoRoute(
        path: '/career',
        builder: (context, state) => const CareerScreen(),
      ),
    ],
  );
});
