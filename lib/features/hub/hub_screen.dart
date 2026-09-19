import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../search/player_detail_sheet.dart';
import '../shared/widgets/almanac_card.dart';
import '../shared/widgets/player_search_field.dart';
import '../shared/widgets/settings_sheet.dart';

/// Hub V2 — Premium editorial home screen.
/// Bento-style layout with hero daily card, mode tiles, search, and coin counter.
/// No developer audit labels, no "IMPROVED"/"GO" badges.
class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppPalette.darkInk : AppPalette.lightInk;
    final inkMuted = isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted;
    final managerName = ref.watch(managerNameProvider);
    final coins = ref.watch(coinsProvider);

    final now = DateTime.now();
    final dateStr = '${_monthName(now.month)} ${now.day}';

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Top Bar ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo + greeting
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Touchline',
                            style: AppTypography.heading(
                              isDark ? AppPalette.gold : AppPalette.goldDark,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Hey, $managerName · $dateStr',
                            style: AppTypography.bodySmall(inkMuted),
                          ),
                        ],
                      ),
                    ),
                    // Coins
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppPalette.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: AppPalette.gold,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '¢',
                              style: TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppPalette.darkBg : Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            coins.toString(),
                            style: AppTypography.statNumber(ink, fontSize: 14, weight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Theme toggle
                    IconButton(
                      icon: Icon(
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        size: 20,
                        color: inkMuted,
                      ),
                      tooltip: 'Toggle Theme',
                      onPressed: () {
                        SoundService.instance.playClick();
                        ref.read(themeModeProvider.notifier).toggle();
                      },
                    ),
                    // Settings & Sound Toggle (Fix 18)
                    IconButton(
                      icon: Icon(
                        Icons.settings_rounded,
                        size: 20,
                        color: inkMuted,
                      ),
                      tooltip: 'Settings & Audio',
                      onPressed: () {
                        SoundService.instance.playClick();
                        SettingsSheet.show(context);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ─── Search ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: PlayerSearchField(
                  hintText: 'Search 24,651 players...',
                  onPlayerSelected: (player) {
                    showPlayerDetailSheet(context, player);
                  },
                ),
              ),
            ),

            // ─── Hero Career Banner ───────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: HeroCard(
                  onTap: () => context.push('/career'),
                  gradientColors: [
                    isDark ? const Color(0xFF1A2A20) : const Color(0xFFE8F0E8),
                    isDark ? const Color(0xFF141820) : const Color(0xFFFFFFFF),
                  ],
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppPalette.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.sports_soccer_rounded, color: AppPalette.green, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Career Mode',
                              style: AppTypography.titleMedium(ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Manage a club through 15 seasons',
                              style: AppTypography.bodySmall(inkMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, size: 20, color: inkMuted),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Daily Challenges ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Text(
                  "TODAY'S CHALLENGES",
                  style: AppTypography.sectionHeader(inkMuted),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ModeTile(
                    icon: Icons.grid_view_rounded,
                    iconColor: AppPalette.blue,
                    title: 'Grid',
                    subtitle: '3×3 category cross — clubs, nations, positions',
                    reward: 15,
                    onTap: () => context.push('/grid'),
                  ),
                  const SizedBox(height: 8),
                  _ModeTile(
                    icon: Icons.person_search_rounded,
                    iconColor: AppPalette.green,
                    title: 'Guess the Player',
                    subtitle: '6 clues, Wordle-style feedback',
                    reward: 10,
                    onTap: () => context.push('/identikit'),
                  ),
                  const SizedBox(height: 8),
                  _ModeTile(
                    icon: Icons.trending_up_rounded,
                    iconColor: AppPalette.gold,
                    title: 'Goal Chase',
                    subtitle: 'Hit the career milestone target',
                    reward: 12,
                    onTap: () => context.push('/goal_chase'),
                  ),
                  const SizedBox(height: 8),
                  _ModeTile(
                    icon: Icons.swap_vert_rounded,
                    iconColor: AppPalette.red,
                    title: 'Higher or Lower',
                    subtitle: 'Compare stats, beat your streak',
                    onTap: () => context.push('/higher_lower'),
                  ),
                  const SizedBox(height: 8),
                  _ModeTile(
                    icon: Icons.view_comfy_rounded,
                    iconColor: AppPalette.amber,
                    title: 'Bingo',
                    subtitle: '5×5 football knowledge board',
                    reward: 20,
                    onTap: () => context.push('/bingo'),
                  ),
                ]),
              ),
            ),

            // ─── More Modes ───────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Text(
                  'MORE TO PLAY',
                  style: AppTypography.sectionHeader(inkMuted),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ModeTile(
                    icon: Icons.group_work_rounded,
                    iconColor: AppPalette.blue,
                    title: 'Connections',
                    subtitle: 'Find the 4 hidden groups of 4 players',
                    reward: 12,
                    onTap: () => context.push('/connections'),
                  ),
                  const SizedBox(height: 8),
                  _ModeTile(
                    icon: Icons.build_circle_rounded,
                    iconColor: AppPalette.green,
                    title: 'Build-a-Player',
                    subtitle: 'Draft 6 attributes into a super card',
                    onTap: () => context.push('/frankenstein'),
                  ),
                  const SizedBox(height: 8),
                  _ModeTile(
                    icon: Icons.quiz_rounded,
                    iconColor: AppPalette.amber,
                    title: 'Quiz',
                    subtitle: 'Tiered football trivia from the database',
                    reward: 10,
                    onTap: () => context.push('/quiz'),
                  ),
                ]),
              ),
            ),

            // Bottom padding
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }

  static String _monthName(int m) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m];
  }
}

/// Individual mode tile — replaces the old _buildDailyTile.
/// Left icon in colored circle, title/subtitle, optional coin reward, forward arrow.
class _ModeTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int? reward;
  final VoidCallback onTap;

  const _ModeTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.reward,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppPalette.darkInk : AppPalette.lightInk;
    final inkMuted = isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted;

    return Material(
      color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashFactory: InkSparkle.splashFactory,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.caption(inkMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Reward + arrow
              if (reward != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '+$reward',
                    style: AppTypography.statNumber(
                      AppPalette.gold,
                      fontSize: 12,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? AppPalette.darkInkDim : AppPalette.lightInkDim),
            ],
          ),
        ),
      ),
    );
  }
}
