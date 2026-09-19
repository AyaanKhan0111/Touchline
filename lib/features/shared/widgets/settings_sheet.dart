import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';

/// Editorial Settings Bottom Sheet (Fix 18)
/// Provides controls for Sound Effects (SFX), Haptic Feedback, Theme, and Profile.
class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink = theme.colorScheme.onSurface;
    final inkMuted = ink.withValues(alpha: 0.65);

    final soundEnabled = ref.watch(soundEnabledProvider);
    final hapticsEnabled = ref.watch(hapticsEnabledProvider);
    final themeMode = ref.watch(themeModeProvider);
    final managerName = ref.watch(managerNameProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: theme.dividerColor),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: inkMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Row
              Row(
                children: [
                  const Icon(Icons.settings_rounded, color: AppPalette.gold, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOUCHLINE SETTINGS', style: AppTypography.sectionHeader(AppPalette.gold)),
                        Text('Preferences, audio & game controls', style: AppTypography.bodySmall(inkMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Divider(color: theme.dividerColor, height: 1),
              const SizedBox(height: 16),

              // ─── SECTION 1: SOUND & HAPTICS (Fix 18) ─────────────
              Text('AUDIO & TACTILE CONTROLS', style: AppTypography.caption(AppPalette.gold).copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),

              // Sound Toggle Tile
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: soundEnabled,
                      activeThumbColor: AppPalette.gold,
                      onChanged: (val) {
                        ref.read(soundEnabledProvider.notifier).setEnabled(val);
                        SoundService.instance.setSoundEnabled(val);
                        if (val) {
                          SoundService.instance.playClick();
                        }
                      },
                      secondary: Icon(
                        soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        color: soundEnabled ? AppPalette.gold : inkMuted,
                      ),
                      title: Text(
                        'Sound Effects (SFX)',
                        style: AppTypography.bodyMedium(ink).copyWith(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Whistle, goal cheers, ball strikes, and game audio',
                        style: AppTypography.caption(inkMuted),
                      ),
                    ),

                    Divider(color: theme.dividerColor.withValues(alpha: 0.3), height: 1),

                    // Haptics Toggle Tile
                    SwitchListTile(
                      value: hapticsEnabled,
                      activeThumbColor: AppPalette.gold,
                      onChanged: (val) {
                        ref.read(hapticsEnabledProvider.notifier).setEnabled(val);
                        SoundService.instance.setHapticsEnabled(val);
                        if (val) {
                          SoundService.instance.mediumHaptic();
                        }
                      },
                      secondary: Icon(
                        hapticsEnabled ? Icons.vibration_rounded : Icons.smartphone_rounded,
                        color: hapticsEnabled ? AppPalette.gold : inkMuted,
                      ),
                      title: Text(
                        'Haptic Feedback',
                        style: AppTypography.bodyMedium(ink).copyWith(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Vibrations on guesses, goals, tackles, and button taps',
                        style: AppTypography.caption(inkMuted),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // SFX Test Bench
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppPalette.gold.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.music_note_rounded, color: AppPalette.gold, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'SFX & Haptics Test Bench',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.gold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTestButton(
                          label: 'Whistle',
                          icon: Icons.sports_rounded,
                          onPressed: () => SoundService.instance.playWhistle(),
                        ),
                        _buildTestButton(
                          label: 'Goal!',
                          icon: Icons.sports_soccer_rounded,
                          onPressed: () => SoundService.instance.playGoal(),
                        ),
                        _buildTestButton(
                          label: 'Chime',
                          icon: Icons.check_circle_rounded,
                          onPressed: () => SoundService.instance.playCorrect(),
                        ),
                        _buildTestButton(
                          label: 'Buzzer',
                          icon: Icons.cancel_rounded,
                          onPressed: () => SoundService.instance.playWrong(),
                        ),
                        _buildTestButton(
                          label: 'Kick',
                          icon: Icons.play_circle_fill_rounded,
                          onPressed: () => SoundService.instance.playKick(),
                        ),
                        _buildTestButton(
                          label: 'Click',
                          icon: Icons.touch_app_rounded,
                          onPressed: () => SoundService.instance.playClick(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ─── SECTION 2: APPEARANCE & PROFILE ─────────────────
              Text('APPEARANCE & PROFILE', style: AppTypography.caption(AppPalette.gold).copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  children: [
                    // Theme Tile
                    SwitchListTile(
                      value: themeMode == 'dark',
                      activeThumbColor: AppPalette.gold,
                      onChanged: (val) {
                        ref.read(themeModeProvider.notifier).setMode(val ? 'dark' : 'light');
                        SoundService.instance.playClick();
                      },
                      secondary: Icon(
                        themeMode == 'dark' ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: AppPalette.gold,
                      ),
                      title: Text(
                        'Dark Theme',
                        style: AppTypography.bodyMedium(ink).copyWith(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        themeMode == 'dark' ? 'Pitch-side charcoal aesthetic' : 'Bright stadium daytime aesthetic',
                        style: AppTypography.caption(inkMuted),
                      ),
                    ),

                    Divider(color: theme.dividerColor.withValues(alpha: 0.3), height: 1),

                    // Manager Name Tile
                    ListTile(
                      leading: const Icon(Icons.person_rounded, color: AppPalette.gold),
                      title: Text(
                        'Manager Name',
                        style: AppTypography.bodyMedium(ink).copyWith(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(managerName, style: AppTypography.caption(inkMuted)),
                      trailing: TextButton.icon(
                        icon: const Icon(Icons.edit_rounded, size: 14),
                        label: const Text('Edit'),
                        onPressed: () => _promptEditName(context, ref, managerName),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ─── SECTION 3: ABOUT TOUCHLINE ──────────────────────
              Text('ABOUT TOUCHLINE', style: AppTypography.caption(AppPalette.gold).copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Touchline Football Almanac', style: AppTypography.bodyMedium(ink).copyWith(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppPalette.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('v2.0 (Build 1)', style: AppTypography.caption(AppPalette.gold).copyWith(fontWeight: FontWeight.w800, fontSize: 10)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Offline SQLite database enriched with 24,651 canonical players, 5 divisions with authentic squads, realistic match engine, and 8 classic & puzzle game modes.',
                      style: AppTypography.caption(inkMuted),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 13, color: AppPalette.gold),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppPalette.gold,
        side: BorderSide(color: AppPalette.gold.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        textStyle: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  void _promptEditName(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Manager Name', style: AppTypography.titleMedium(Theme.of(context).colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Manager Name',
            hintText: 'Enter your name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.gold),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(managerNameProvider.notifier).setName(newName);
                SoundService.instance.playCorrect();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
