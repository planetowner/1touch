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
            boxShadow: appWatchCardShadows(context),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final portraitSize = constraints.maxHeight - 10;
                      return Stack(
                        children: [
                          Container(
                            key: const ValueKey('ones-to-watch-image-surface'),
                            width: double.infinity,
                            color: isDark
                                ? AppPalette.darkGrey
                                : appColors.subtleBackground,
                          ),
                          Positioned(
                            top: 10,
                            right: 0,
                            width: portraitSize,
                            height: portraitSize,
                            child: SizedBox(
                              key: ValueKey(
                                  'ones-to-watch-portrait-${player.id}'),
                              child: PlayerImage(player: player),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Text(
                              '${player.jerseyNumber}',
                              key:
                                  ValueKey('ones-to-watch-jersey-${player.id}'),
                              style: Heading2.style,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Container(
                  key: const ValueKey('ones-to-watch-info-surface'),
                  width: double.infinity,
                  height: 88,
                  color: isDark ? AppPalette.lightGrey : AppPalette.white,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: PlayerWatchName(
                          name: playerNameLabel(context,
                              player.externalPlayerId, player.fullName),
                          style:
                              Body1_b.style.copyWith(color: colors.onSurface),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        teamNameLabel(context, player.teamId, player.teamName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
