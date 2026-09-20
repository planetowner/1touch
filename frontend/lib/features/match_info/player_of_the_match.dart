part of 'match_info_features.dart';

class PlayerOfTheMatch extends StatelessWidget {
  final String rating;
  final String playerName;
  final String teamAndNumber; // e.g. "FC Barcelona • 9"

  const PlayerOfTheMatch({
    super.key,
    required this.rating,
    required this.playerName,
    required this.teamAndNumber,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("PLAYER OF THE MATCH", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('match-player-of-the-match-card'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isDark ? AppPalette.darkGrey : AppPalette.white,
            boxShadow: appCardShadows(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emoji_events_outlined,
                      color: foreground, size: 40),
                  const SizedBox(width: 16),
                  Text(rating, style: Heading2.style),
                ],
              ),
              const SizedBox(height: 42),
              Text(playerName,
                  style: Heading5.style,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(teamAndNumber,
                  style: Body2.style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
