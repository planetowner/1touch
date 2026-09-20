part of 'player_screen_features.dart';

class PlayerRankingBox extends StatefulWidget {
  final List<Player> players;

  const PlayerRankingBox({super.key, required this.players});

  @override
  State<PlayerRankingBox> createState() => _PlayerRankingBoxState();
}

class _PlayerRankingBoxState extends State<PlayerRankingBox> {
  @override
  Widget build(BuildContext context) {
    final visibleCount = widget.players.length < 5 ? widget.players.length : 5;
    final appColors = AppColors.of(context);

    return Container(
      key: const ValueKey('players-ranking-card'),
      decoration: BoxDecoration(
        color: appColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: appCardShadows(context),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          for (int i = 0; i < visibleCount; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text("${i + 1}", style: Heading3.style),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: ClipOval(
                      child: PlayerImage(player: widget.players[i]),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.players[i].fullName, style: Heading5.style),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.players[i].teamName} • #${widget.players[i].jerseyNumber}',
                          style: Body2.style,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    widget.players[i].rankingScore.toStringAsFixed(1),
                    textAlign: TextAlign.right,
                    style: Heading5.style,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor:
                    isDark ? AppPalette.darkGrey : AppPalette.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const FractionallySizedBox(
                  heightFactor: 0.85,
                  child: FullRankingPopup(),
                ),
              );
            },
            child: Text("See All", style: Body2.style),
          ),
        ],
      ),
    );
  }
}

class FullRankingPopup extends StatelessWidget {
  const FullRankingPopup({super.key});

  @override
  Widget build(BuildContext context) {
    final players = playerRepository.ranking;
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      key: const ValueKey('full-ranking-sheet'),
      backgroundColor: appColors.cardBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      "1Touch Ranking",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Heading5.style.copyWith(color: colors.onSurface),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: colors.onSurface),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: appColors.subtleBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Look for players",
                          hintStyle: Body1.style.copyWith(
                            color: appColors.mutedForeground,
                          ),
                          border: InputBorder.none,
                        ),
                        style: TextStyle(color: colors.onSurface),
                      ),
                    ),
                    Icon(Icons.search, color: colors.onSurface),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final rank = index + 1;
                  final player = players[index];
                  final showStar = playerRepository.isFollowing(player.id);
                  final showArrow = player.rankingChange != 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Text("$rank", style: Heading4.style),
                        const SizedBox(width: 8),
                        if (showArrow)
                          const Icon(Icons.arrow_drop_up,
                              color: Colors.blueAccent)
                        else
                          const SizedBox(width: 24),
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: ClipOval(child: PlayerImage(player: player)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(player.fullName, style: Heading5.style),
                              const SizedBox(height: 2),
                              Text(
                                '${player.teamName} • #${player.jerseyNumber}',
                                style: Body2.style,
                              ),
                            ],
                          ),
                        ),
                        if (showStar) Icon(Icons.star, color: colors.onSurface),
                        Text(
                          player.rankingScore.toStringAsFixed(1),
                          style: Heading5.style,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 3. OnesToWatchCard
