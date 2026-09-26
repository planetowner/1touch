part of 'team_best_eleven_section.dart';

class BestElevenPitch extends StatelessWidget {
  BestElevenPitch({
    super.key,
    required this.teamId,
    required this.formation,
    required List<BestElevenEntry> players,
  }) : _players = List.unmodifiable(
          players.map(
            (player) => _BestElevenPitchPlayer(
              slotKey: player.slotKey,
              playerId: player.playerId,
              playerName: player.playerName,
              jerseyNumber: player.jerseyNumber,
            ),
          ),
        );

  final int teamId;
  final String formation;
  final List<_BestElevenPitchPlayer> _players;

  @override
  Widget build(BuildContext context) {
    if (_players.isEmpty) return const SizedBox.shrink();
    final appColors = AppColors.of(context);
    final pitchBackground = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.lightGrey
        : appColors.cardBackground;
    final team = teamRepository.findById(teamId);
    final playerCircleColor = TeamComparisonColorResolver.paletteFor(
      teamName: team?.name,
      primaryFallback: team == null ? null : Color(team.primaryColor),
    ).primary;
    final jerseyNumberColor = ColorUtils.monochromeTextColor(
      playerCircleColor,
    );

    final layoutFormation = bestElevenLayoutFormation(formation);
    final layout = bestElevenFormationLayouts[layoutFormation] ??
        buildFallbackBestElevenLayout(layoutFormation);

    return Container(
      key: const ValueKey('team-best-eleven-card'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: appCardShadows(context),
      ),
      child: Material(
        color: pitchBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: double.infinity,
          child: AspectRatio(
            aspectRatio: BestElevenFormationLayout.designSize.width /
                BestElevenFormationLayout.designSize.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scaleX = constraints.maxWidth /
                    BestElevenFormationLayout.designSize.width;
                final scaleY = constraints.maxHeight /
                    BestElevenFormationLayout.designSize.height;
                return CustomPaint(
                  painter: _HalfCirclePainter(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.15),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final player in _players)
                        if (layout.positionForSlot(
                          bestElevenLayoutSlotKey(
                            formation,
                            player.slotKey,
                          ),
                        )
                            case final position?)
                          Positioned(
                            left: position.dx * scaleX - 31,
                            top: position.dy * scaleY - 16,
                            child: _BestElevenPlayerDot(
                              player: player,
                              circleColor: playerCircleColor,
                              jerseyNumberColor: jerseyNumberColor,
                            ),
                          ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BestElevenPlayerDot extends StatelessWidget {
  const _BestElevenPlayerDot({
    required this.player,
    required this.circleColor,
    required this.jerseyNumberColor,
  });

  final _BestElevenPitchPlayer player;
  final Color circleColor;
  final Color jerseyNumberColor;

  @override
  Widget build(BuildContext context) {
    final playerName = player.playerName?.trim();
    final label = playerName == null || playerName.isEmpty
        ? tr(context, 'Unknown')
        : playerNameLabel(context, player.playerId, playerName, short: true);
    return Semantics(
      button: true,
      label: 'Open $label',
      child: InkWell(
        key: ValueKey('best-eleven-player-link-${player.playerId}'),
        onTap: () => openPlayerPage(context, player.playerId.toString()),
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 62,
          child: Column(
            children: [
              Container(
                key: ValueKey('best-eleven-player-dot-${player.slotKey}'),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: circleColor,
                ),
                alignment: Alignment.center,
                child: Text(
                  player.jerseyNumber?.toString() ?? '—',
                  style: Heading5.style.copyWith(color: jerseyNumberColor),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr(context, label),
                style: Eyebrow.style,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BestElevenPitchPlayer {
  const _BestElevenPitchPlayer({
    required this.slotKey,
    required this.playerId,
    required this.playerName,
    required this.jerseyNumber,
  });

  final String slotKey;
  final int playerId;
  final String? playerName;
  final int? jerseyNumber;
}
