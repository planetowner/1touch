part of 'player_comparison_screen.dart';

class _HeaderArea extends StatelessWidget {
  final ComparisonPlayer? p1, p2;
  final String? s1, s2;
  final VoidCallback onBack, onSearch;
  final VoidCallback onTap1, onTap2;

  const _HeaderArea({
    required this.p1,
    required this.p2,
    required this.s1,
    required this.s2,
    required this.onBack,
    required this.onSearch,
    required this.onTap1,
    required this.onTap2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 295,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF000000), Color(0xFF282929)],
                ),
              ),
            ),
          ),
          if (p1 != null)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.82, 1.2),
                    radius: 0.95,
                    colors: [
                      p1!.teamColor.withValues(alpha: 0.50),
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ),
          if (p2 != null)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.82, 1.2),
                    radius: 0.95,
                    colors: [
                      p2!.teamColor.withValues(alpha: 0.38),
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ),
          if (p1?.headerTeamLogoAsset != null)
            Positioned(
              left: -48,
              top: 88,
              width: 176,
              height: 176,
              child: Opacity(
                opacity: 0.2,
                child: Image.asset(
                  p1!.headerTeamLogoAsset!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          if (p2?.teamLogoAsset != null)
            Positioned(
              right: -48,
              top: 88,
              width: 176,
              height: 176,
              child: Opacity(
                opacity: 0.16,
                child: Image.asset(
                  p2!.teamLogoAsset!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          Positioned(
            left: 24,
            top: 51,
            width: 24,
            height: 24,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          Positioned(
            right: 40,
            top: 47,
            width: 32,
            height: 32,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSearch,
              child: const Icon(Icons.search, color: Colors.white, size: 32),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: 103,
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: _PlayerChip(
                    player: p1,
                    slot: 1,
                    season: s1,
                    onTap: onTap1,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _PlayerChip(
                    player: p2,
                    slot: 2,
                    season: s2,
                    onTap: onTap2,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            top: 167,
            width: 130,
            height: 128,
            child: _PlayerPhoto(player: p1),
          ),
          Positioned(
            right: 24,
            top: 167,
            width: 130,
            height: 128,
            child: _PlayerPhoto(player: p2),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 239,
            child: Center(
              child: Text(
                'VS',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Archivo',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final ComparisonPlayer? player;
  final int slot;
  final String? season;
  final VoidCallback onTap;

  const _PlayerChip({
    required this.player,
    required this.slot,
    required this.season,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final seasonPrefix =
        season == null ? '' : season!.substring(0, math.min(2, season!.length));

    return Opacity(
      opacity: 0.8,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(player == null ? 16 : 8, 8, 8, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              if (player != null) ...[
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0A0A0A),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      seasonPrefix,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Archivo',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    player!.shortName,
                    style: const TextStyle(
                      color: Color(0xFF0A0A0A),
                      fontFamily: 'Archivo',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                Expanded(
                  child: Text(
                    'PLAYER $slot',
                    style: const TextStyle(
                      color: Color(0xFF0A0A0A),
                      fontFamily: 'Archivo',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFF0A0A0A),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerPhoto extends StatelessWidget {
  final ComparisonPlayer? player;

  const _PlayerPhoto({required this.player});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      player?.playerImageAsset ??
          'assets/player_comparison/player_placeholder.png',
      width: 130,
      height: 128,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
    );
  }
}
