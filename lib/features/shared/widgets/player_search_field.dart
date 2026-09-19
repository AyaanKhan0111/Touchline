import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/models/player.dart';
import 'player_avatar.dart';
import 'stat_badge.dart';

/// Debounced (120ms) instant FTS5 player search field.
/// Optional [showRating] flag to hide ratings in puzzle contexts.
class PlayerSearchField extends ConsumerStatefulWidget {
  final ValueChanged<Player> onPlayerSelected;
  final String hintText;
  final bool autoFocus;
  final bool showRating;

  const PlayerSearchField({
    super.key,
    required this.onPlayerSelected,
    this.hintText = 'Search player by name, club or nation...',
    this.autoFocus = false,
    this.showRating = false,
  });

  @override
  ConsumerState<PlayerSearchField> createState() => _PlayerSearchFieldState();
}

class _PlayerSearchFieldState extends ConsumerState<PlayerSearchField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      ref.read(playerSearchQueryProvider.notifier).state = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppPalette.darkInk : AppPalette.lightInk;
    final inkMuted = isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted;
    final searchResultsAsync = ref.watch(playerSearchResultsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          autofocus: widget.autoFocus,
          onChanged: _onChanged,
          style: AppTypography.bodyMedium(ink),
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: inkMuted),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, size: 18, color: inkMuted),
                    onPressed: () {
                      _controller.clear();
                      ref.read(playerSearchQueryProvider.notifier).state = '';
                      setState(() {});
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        searchResultsAsync.when(
          data: (players) {
            if (players.isEmpty && _controller.text.trim().length >= 2) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No players found for "${_controller.text}"',
                    style: AppTypography.bodySmall(inkMuted),
                  ),
                ),
              );
            }
            if (players.isEmpty) return const SizedBox.shrink();

            return Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: players.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  indent: 56,
                  color: isDark ? AppPalette.darkBorder : AppPalette.lightBorder,
                ),
                itemBuilder: (context, index) {
                  final player = players[index];
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    leading: PlayerAvatar(
                      name: player.name,
                      size: 36,
                      position: player.primaryPosition,
                    ),
                    title: Text(
                      player.name,
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _formatPlayerSubtitle(player),
                      style: AppTypography.caption(inkMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: widget.showRating
                        ? StatBadge(value: player.overall, label: player.primaryPosition)
                        : PositionBadge(position: player.primaryPosition, isSmall: true),
                    onTap: () {
                      widget.onPlayerSelected(player);
                      _controller.clear();
                      ref.read(playerSearchQueryProvider.notifier).state = '';
                      setState(() {});
                    },
                  );
                },
              ),
            );
          },
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text('Error: $e', style: AppTypography.caption(AppPalette.red)),
        ),
      ],
    );
  }

  String _formatPlayerSubtitle(Player player) {
    if (player.teamName.isNotEmpty) {
      if (player.nationality != null && player.nationality!.isNotEmpty) {
        if (player.teamName.trim().toLowerCase() == player.nationality!.trim().toLowerCase()) {
          return '${player.primaryPosition} · ${player.nationality}';
        }
        return '${player.teamName} · ${player.nationality}';
      }
      return player.teamName;
    }
    return player.nationality ?? player.primaryPosition;
  }
}
