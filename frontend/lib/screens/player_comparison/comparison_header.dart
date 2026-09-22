part of 'player_comparison_screen.dart';

class _HeaderArea extends StatelessWidget {
  const _HeaderArea({
    required this.p1,
    required this.p2,
    required this.onBack,
    required this.onSearch,
    required this.onTap1,
    required this.onTap2,
  });

  final PlayerDetail? p1, p2;
  final VoidCallback onBack, onSearch;
  final VoidCallback? onTap1, onTap2;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final firstColor = _teamPrimary(p1);
    final secondColor = _comparisonColors(context, p1, p2).opponent;

    return SizedBox(
      height: 295,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              key: const ValueKey('comparison-header-gradient'),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? const [Color(0xFF000000), AppPalette.darkGrey]
                      : const [AppPalette.white, AppPalette.lightModeDarkGrey],
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
                    radius: .95,
                    colors: [
                      firstColor.withValues(alpha: .50),
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
                    center: const Alignment(.82, 1.2),
                    radius: .95,
                    colors: [
                      secondColor.withValues(alpha: .38),
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ),
          if (p1?.profile.teamImage != null)
            _HeaderTeamLogo(image: p1!.profile.teamImage!, left: true),
          if (p2?.profile.teamImage != null)
            _HeaderTeamLogo(image: p2!.profile.teamImage!, left: false),
          Positioned(
            left: 24,
            top: 51,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: foreground,
                  size: 24,
                ),
              ),
            ),
          ),
          Positioned(
            right: 36,
            top: 43,
            child: IconButton(
              onPressed: onSearch,
              icon: Icon(Icons.search, color: foreground, size: 32),
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
                    onTap: onTap1,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _PlayerChip(
                    player: p2,
                    slot: 2,
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
            child: _PlayerPhoto(player: p1, slot: 1),
          ),
          Positioned(
            right: 24,
            top: 167,
            width: 130,
            height: 128,
            child: _PlayerPhoto(player: p2, slot: 2),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 239,
            child: Center(
              child: Text(
                'VS',
                style: TextStyle(
                  color: foreground,
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

class _HeaderTeamLogo extends StatelessWidget {
  const _HeaderTeamLogo({required this.image, required this.left});
  final String image;
  final bool left;

  @override
  Widget build(BuildContext context) => Positioned(
        left: left ? -48 : null,
        right: left ? null : -48,
        top: 88,
        width: 176,
        height: 176,
        child: Opacity(
          opacity: left ? .20 : .16,
          child: PlayerRemoteImage(image, size: 176),
        ),
      );
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({
    required this.player,
    required this.slot,
    required this.onTap,
  });
  final PlayerDetail? player;
  final int slot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final season = player?.selectedSeason?.name;
    final shortSeason = season == null ? '' : _shortSeason(season);
    final prefix = shortSeason.substring(0, math.min(2, shortSeason.length));
    return Opacity(
      opacity: .8,
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
                  alignment: Alignment.center,
                  child: Text(
                    prefix,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    player!.profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0A0A0A),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ] else
                Expanded(
                  child: Text(
                    'PLAYER $slot',
                    style: const TextStyle(
                      color: Color(0xFF0A0A0A),
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
  const _PlayerPhoto({required this.player, required this.slot});
  final PlayerDetail? player;
  final int slot;

  @override
  Widget build(BuildContext context) => PlayerRemoteImage(
        player?.profile.image,
        key: Key('comparison-header-photo-$slot'),
        size: 130,
      );
}
