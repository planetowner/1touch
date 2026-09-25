part of 'player_screen_features.dart';

class FavoritePlayersSection extends StatelessWidget {
  const FavoritePlayersSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: playerRepository.followedPlayerIds,
      builder: (context, _) {
        final players = playerRepository.favorites;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    tr(context, "FAVORITE PLAYERS"),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Body2_b.style,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const EditFollowingPlayersSheet(),
                    );
                  },
                  icon: Icon(
                    Icons.border_color,
                    size: 24,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 148,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  return GestureDetector(
                    onTap: () => openPlayerPage(context, player.id),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: SizedBox(
                        width: 82,
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                SizedBox(
                                  width: 74,
                                  height: 74,
                                  child: ClipOval(
                                      child: PlayerImage(player: player)),
                                ),
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  child: Container(
                                    key: const ValueKey(
                                      'favorite-player-number-badge',
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppPalette.lightGrey
                                          : AppPalette.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${player.jerseyNumber}',
                                      style: Body2_b.style.copyWith(
                                        color: colors.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              playerNameLabel(context, player.externalPlayerId,
                                  player.fullName),
                              style: Body1.style,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// 2. PlayerRankingBox + FullRankingPopup
