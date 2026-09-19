import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';

/// Full-screen editorial onboarding — asks for name, not "manager credentials".
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name to continue.');
      return;
    }
    await ref.read(managerNameProvider.notifier).setName(name);
    if (mounted) {
      context.go('/hub');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppPalette.darkInk : AppPalette.lightInk;
    final inkMuted = isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App identity
                  Text(
                    'Touchline',
                    style: AppTypography.heading(
                      isDark ? AppPalette.gold : AppPalette.goldDark,
                      fontSize: 42,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Football Knowledge & Management',
                    style: AppTypography.bodyLarge(inkMuted),
                  ),

                  const SizedBox(height: 56),

                  // Name prompt
                  Text(
                    'What\'s your name?',
                    style: AppTypography.titleLarge(ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No account needed. Just a name for the scoreboard.',
                    style: AppTypography.bodySmall(inkMuted),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    style: AppTypography.bodyLarge(ink),
                    decoration: InputDecoration(
                      hintText: 'e.g. Ayaan, Alex, Mo',
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Let\'s Go'),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18,
                            color: isDark ? AppPalette.darkBg : AppPalette.lightBg),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Footer
                  Center(
                    child: Text(
                      'Offline · 24,651 Players · 1966–2027',
                      style: AppTypography.caption(
                        isDark ? AppPalette.darkInkDim : AppPalette.lightInkDim,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
