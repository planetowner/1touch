part of 'player_screen_features.dart';

class OnesToWatchCard extends StatelessWidget {
  final Player player;

  const OnesToWatchCard({
    super.key,
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label:
          'Open ${playerNameLabel(context, player.externalPlayerId, player.fullName)}',
      child: GestureDetector(
        key: ValueKey('ones-to-watch-player-${player.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => openPlayerPage(context, player.id),
        child: Container(
          key: const ValueKey('ones-to-watch-card'),
          width: 150,
          height: 200,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: appCardShadows(context),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        key: const ValueKey('ones-to-watch-image-surface'),
                        width: double.infinity,
                        color: isDark
                            ? AppPalette.darkGrey
                            : appColors.subtleBackground,
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: SizedBox(
                          width: 88,
                          child: PlayerImage(player: player),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Text(
                          '#${player.jerseyNumber}',
                          key: ValueKey('ones-to-watch-jersey-${player.id}'),
                          style: Heading2.style,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  key: const ValueKey('ones-to-watch-info-surface'),
                  width: double.infinity,
                  color: isDark ? AppPalette.lightGrey : AppPalette.white,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playerNameLabel(
                            context, player.externalPlayerId, player.fullName),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Body1_b.style.copyWith(color: colors.onSurface),
                        textAlign: TextAlign.start,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${teamNameLabel(context, player.teamId, player.teamName)} • ${player.jerseyNumber}',
                        style: Eyebrow.style.copyWith(color: colors.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 4. FilterSheet + FilterPill
