import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/player.dart';
import '../../domain/models/transfer_offer.dart';
import '../shared/widgets/club_badge.dart';
import '../shared/widgets/player_avatar.dart';
import '../shared/widgets/stat_badge.dart';

/// Modal bottom sheet displaying active inbound transfer offers from AI clubs (Fix 28 / User Fix 6)
void showInboundOffersSheet(
  BuildContext context, {
  required List<TransferOffer> offers,
  required List<Player> userSquad,
  required Function(TransferOffer offer) onAccept,
  required Function(TransferOffer offer) onRefuse,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => InboundOffersSheet(
      offers: offers,
      userSquad: userSquad,
      onAccept: onAccept,
      onRefuse: onRefuse,
    ),
  );
}

class InboundOffersSheet extends StatelessWidget {
  final List<TransferOffer> offers;
  final List<Player> userSquad;
  final Function(TransferOffer offer) onAccept;
  final Function(TransferOffer offer) onRefuse;

  const InboundOffersSheet({
    super.key,
    required this.offers,
    required this.userSquad,
    required this.onAccept,
    required this.onRefuse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? AppPalette.darkSurfaceRaised : AppPalette.lightSurfaceRaised;
    final ink = isDark ? AppPalette.darkInk : AppPalette.lightInk;
    final inkMuted = isDark ? AppPalette.darkInkMuted : AppPalette.lightInkMuted;
    final border = isDark ? AppPalette.darkBorder : AppPalette.lightBorder;

    final pendingOffers = offers.where((o) => o.isPending).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: inkMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.mark_email_unread_rounded, color: AppPalette.gold, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('INBOUND TRANSFER BIDS', style: AppTypography.titleMedium(ink)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppPalette.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppPalette.gold.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '${pendingOffers.length}',
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.gold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Rival AI clubs approaching your stars with official transfer bids',
                        style: AppTypography.caption(inkMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),
          Divider(color: border, height: 1),

          // Offers List
          Flexible(
            child: pendingOffers.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: inkMuted.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            'No Pending Transfer Bids',
                            style: AppTypography.titleMedium(ink),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'AI clubs submit bids during open transfer windows as matchdays progress.',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption(inkMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: pendingOffers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 14),
                    itemBuilder: (ctx, index) {
                      final offer = pendingOffers[index];
                      return _buildOfferCard(context, offer, isDark, ink, inkMuted, border);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(
    BuildContext context,
    TransferOffer offer,
    bool isDark,
    Color ink,
    Color inkMuted,
    Color border,
  ) {
    final premium = offer.premiumPercent;
    final premiumStr = premium >= 0 ? '+${premium.toStringAsFixed(0)}%' : '${premium.toStringAsFixed(0)}%';
    final clubCode = offer.buyingClub.length >= 3 ? offer.buyingClub.substring(0, 3).toUpperCase() : offer.buyingClub.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : AppPalette.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.gold.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Buying Club Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppPalette.gold.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                ClubBadge(code: clubCode, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    offer.buyingClub,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    offer.buyingClubTier,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Player & Bid Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    PlayerAvatar(name: offer.playerName, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  offer.playerName,
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: ink,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              PositionBadge(position: offer.playerPosition),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Age ${offer.playerAge} • Season ${offer.season} Gameweek ${offer.gameweek}',
                            style: AppTypography.caption(inkMuted).copyWith(fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    StatBadge(value: offer.playerOverall, label: ''),
                  ],
                ),

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MARKET VALUATION', style: AppTypography.caption(inkMuted).copyWith(fontSize: 9.5)),
                          const SizedBox(height: 1),
                          Text(
                            '£${offer.playerMarketValue.toStringAsFixed(1)}M',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 14, color: AppPalette.gold),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('OFFERED TRANSFER BID', style: AppTypography.caption(inkMuted).copyWith(fontSize: 9.5)),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Text(
                                '£${offer.offeredFeeMillions.toStringAsFixed(1)}M',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppPalette.green,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppPalette.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppPalette.green.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  premiumStr,
                                  style: const TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppPalette.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                // Actions
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppPalette.red.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          onRefuse(offer);
                        },
                        child: const Text(
                          'Refuse Offer',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.red,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.green,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.black),
                        label: Text(
                          'Accept Bid (+£${offer.offeredFeeMillions.toStringAsFixed(1)}M)',
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          onAccept(offer);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
