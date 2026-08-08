part of 'player_comparison_screen.dart';

class _MostComparedSection extends StatelessWidget {
  final void Function(ComparisonPlayer, ComparisonPlayer) onTapPair;

  const _MostComparedSection({required this.onTapPair});

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 31, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MOST COMPARED',
            style: TextStyle(
              color: foreground,
              fontFamily: 'Archivo',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 15),
          ..._kMostCompared.map((pair) {
            final p1 = _findById(pair[0]);
            final p2 = _findById(pair[1]);
            if (p1 == null || p2 == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ComparisonCard(
                p1: p1,
                p2: p2,
                onTap: () => onTapPair(p1, p2),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final ComparisonPlayer p1, p2;
  final VoidCallback onTap;

  const _ComparisonCard({
    required this.p1,
    required this.p2,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final imageSurface = isDark ? AppPalette.darkGrey : AppPalette.lightGreyBox;
    final detailsSurface = isDark ? AppPalette.lightGrey : AppPalette.white;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 159,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: detailsSurface),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 96,
                child: ColoredBox(
                  key: ValueKey(
                    'comparison-card-image-${p1.id}-${p2.id}',
                  ),
                  color: imageSurface,
                ),
              ),
              if (p1.teamLogoAsset != null)
                Positioned(
                  left: -56,
                  top: -36,
                  width: 184,
                  height: 184,
                  child: Opacity(
                    opacity: 0.2,
                    child: Image.asset(
                      p1.teamLogoAsset!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              if (p2.teamLogoAsset != null)
                Positioned(
                  right: -55,
                  top: -36,
                  width: 184,
                  height: 184,
                  child: Opacity(
                    opacity: 0.2,
                    child: Image.asset(
                      p2.teamLogoAsset!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              Positioned(
                left: 24,
                top: 16,
                width: 80,
                height: 80,
                child: _CardPlayerImage(player: p1),
              ),
              Positioned(
                right: 24,
                top: 16,
                width: 80,
                height: 80,
                child: _CardPlayerImage(player: p2),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 96,
                bottom: 0,
                child: ColoredBox(
                  key: ValueKey(
                    'comparison-card-details-${p1.id}-${p2.id}',
                  ),
                  color: detailsSurface,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 41,
                child: Center(
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: foreground,
                      fontFamily: 'Archivo',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: 108,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _CardPlayerDetails(player: p1)),
                    Expanded(
                      child: _CardPlayerDetails(
                        player: p2,
                        alignRight: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardPlayerDetails extends StatelessWidget {
  final ComparisonPlayer player;
  final bool alignRight;

  const _CardPlayerDetails({
    required this.player,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          player.fullName,
          style: TextStyle(
            color: foreground,
            fontFamily: 'Archivo',
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
        ),
        const SizedBox(height: 4),
        Text(
          '${player.team} • #${player.number}',
          style: TextStyle(
            color: foreground,
            fontFamily: 'Archivo',
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
        ),
      ],
    );
  }
}

class _CardPlayerImage extends StatelessWidget {
  final ComparisonPlayer player;

  const _CardPlayerImage({required this.player});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      player.playerImageAsset ??
          'assets/player_comparison/player_placeholder.png',
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
    );
  }
}
