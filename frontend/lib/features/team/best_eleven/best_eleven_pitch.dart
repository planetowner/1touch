part of 'team_best_eleven_section.dart';

class BestElevenPitch extends StatelessWidget {
  BestElevenPitch({
    super.key,
    required this.teamId,
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

    final Map<int, List<_BestElevenPitchPlayer>> byRow = {};
    for (final player in _players) {
      final parts = player.slotKey.split(':');
      final row = int.parse(parts[0]);
      byRow.putIfAbsent(row, () => []).add(player);
    }
    for (final list in byRow.values) {
      list.sort((a, b) {
        final aColumn = int.parse(a.slotKey.split(':')[1]);
        final bColumn = int.parse(b.slotKey.split(':')[1]);
        return aColumn.compareTo(bColumn);
      });
    }
    final rowKeys = byRow.keys.toList()..sort((a, b) => b.compareTo(a));

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
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(color: pitchBackground),
          child: Column(
            children: [
              CustomPaint(
                painter: _HalfCirclePainter(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.15),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: rowKeys.map((key) {
                      final rowPlayers = byRow[key]!;
                      return _BestElevenRow(
                        players: rowPlayers,
                        playerCircleColor: playerCircleColor,
                        jerseyNumberColor: jerseyNumberColor,
                        isDefensiveRow: key == rowKeys.last,
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _BestElevenRow extends StatelessWidget {
  const _BestElevenRow({
    required this.players,
    required this.playerCircleColor,
    required this.jerseyNumberColor,
    this.isDefensiveRow = false,
  });

  final List<_BestElevenPitchPlayer> players;
  final Color playerCircleColor;
  final Color jerseyNumberColor;
  final bool isDefensiveRow;

  @override
  Widget build(BuildContext context) {
    Widget dotWithOffset(int columnIndex) {
      var topOffset = 0.0;
      if (isDefensiveRow && players.length == 4) {
        if (columnIndex == 0 || columnIndex == players.length - 1) {
          topOffset = -10;
        }
      }
      return Padding(
        padding: const EdgeInsets.only(top: 0),
        child: Transform.translate(
          offset: Offset(0, topOffset),
          child: _BestElevenPlayerDot(
            player: players[columnIndex],
            circleColor: playerCircleColor,
            jerseyNumberColor: jerseyNumberColor,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(players.length, dotWithOffset),
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
        : playerName.split(' ').last;
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
