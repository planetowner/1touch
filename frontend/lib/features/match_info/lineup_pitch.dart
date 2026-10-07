part of 'match_info_features.dart';

class LineupPitch extends StatelessWidget {
  /// Away team rows ordered GK → attackers (displayed top → bottom).
  final List<List<LineupPlayer>> awayRows;

  /// Home team rows ordered attackers → GK (displayed top → bottom in their half).
  final List<List<LineupPlayer>> homeRows;

  /// Called when the user taps a player dot.
  final void Function(BuildContext context, LineupPlayer player)? onPlayerTap;
  final Color homeColor;
  final Color awayColor;

  const LineupPitch({
    super.key,
    required this.awayRows,
    required this.homeRows,
    this.onPlayerTap,
    required this.homeColor,
    required this.awayColor,
  });

  static const double _centerGap = 64;
  static const double _pitchHeight = 784;
  static const double _verticalPadding = 20;
  static const double _minimumPlayerGap = 8;
  static const double _playerWidth = 64;
  static const double _meaningfulHorizontalOverlap = 8;

  double _requiredHalfHeight(
    List<List<LineupPlayer>> rows,
    double playerHeight,
  ) {
    const baseHalfHeight =
        (_pitchHeight - 2 * _verticalPadding - _centerGap) / 2;
    var halfHeight = baseHalfHeight;
    final minimumCenterGap = playerHeight + _minimumPlayerGap;
    final players = rows.expand((row) => row).toList();
    if (players.isEmpty) return halfHeight;
    if (players.any((player) => player.formationPosition == null)) {
      final required =
          rows.length * playerHeight + (rows.length - 1) * _minimumPlayerGap;
      return required > halfHeight ? required : halfHeight;
    }

    final positions = [
      for (final player in players) player.formationPosition!,
    ];
    final outfieldRows = [
      for (final row in rows)
        if (row.any((player) =>
            player.formationPosition!.dy < FormationLayout.goalkeeper.dy))
          row,
    ];
    final outfield = [
      for (final position in positions)
        if (position.dy < FormationLayout.goalkeeper.dy) position,
    ];
    var visualRows = outfieldRows.length;
    for (final row in outfieldRows) {
      final ys = row.map((player) => player.formationPosition!.dy).toList();
      if (ys.reduce((a, b) => a > b ? a : b) -
              ys.reduce((a, b) => a < b ? a : b) >
          FormationLayout.designSize.height / 8) {
        visualRows++;
      }
    }
    if (visualRows > 1 && outfield.isNotEmpty) {
      final highest = outfield
          .map((position) => position.dy)
          .reduce((a, b) => a < b ? a : b);
      final lowest = outfield
          .map((position) => position.dy)
          .reduce((a, b) => a > b ? a : b);
      final rowGap = (lowest - highest) / (visualRows - 1);
      if (rowGap > 0) {
        final required =
            FormationLayout.designSize.height * minimumCenterGap / rowGap;
        if (required > halfHeight) halfHeight = required;
      }
    }

    // 같은 줄의 선수 칸이 끝에서 조금 닿는 것만으로 피치 높이를 늘리지 않아요.
    for (var i = 0; i < positions.length; i++) {
      for (var j = i + 1; j < positions.length; j++) {
        final dx = (positions[i].dx - positions[j].dx).abs();
        final dy = (positions[i].dy - positions[j].dy).abs();
        if (dx >= _playerWidth - _meaningfulHorizontalOverlap || dy == 0) {
          continue;
        }
        final required =
            FormationLayout.designSize.height * minimumCenterGap / dy;
        if (required > halfHeight) halfHeight = required;
      }
    }
    final keeperClearance = (playerHeight - 16) /
        (1 - FormationLayout.goalkeeper.dy / FormationLayout.designSize.height);
    if (keeperClearance > halfHeight) halfHeight = keeperClearance;
    return halfHeight.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final playerHeight =
        32 + 9 + 20 * MediaQuery.textScalerOf(context).scale(1);
    final halfHeight = [
      _requiredHalfHeight(homeRows, playerHeight),
      _requiredHalfHeight(awayRows, playerHeight),
    ].reduce((a, b) => a > b ? a : b);
    final pitchHeight = 2 * halfHeight + _centerGap + 2 * _verticalPadding;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, "LINEUP"), style: Body2_b.style),
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('match-lineup-card'),
          height: pitchHeight,
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkGrey : AppPalette.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: appCardShadows(context),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _PitchMarkingsPainter(
                    isDark
                        ? const Color(0xFFB2B2B2)
                        : foreground.withValues(alpha: 0.3),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: _verticalPadding,
                  horizontal: 0,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: _LineupHalf(
                        rows: awayRows,
                        reverseVertical: true,
                        playerCircleColor: awayColor,
                        onTap: onPlayerTap == null
                            ? null
                            : (p) => onPlayerTap!(context, p),
                      ),
                    ),
                    // Gap that the center circle overlaps
                    const SizedBox(height: _centerGap),
                    Expanded(
                      child: _LineupHalf(
                        rows: homeRows,
                        reverseVertical: false,
                        playerCircleColor: homeColor,
                        onTap: onPlayerTap == null
                            ? null
                            : (p) => onPlayerTap!(context, p),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LineupHalf extends StatelessWidget {
  const _LineupHalf({
    required this.rows,
    required this.reverseVertical,
    required this.playerCircleColor,
    required this.onTap,
  });

  final List<List<LineupPlayer>> rows;
  final bool reverseVertical;
  final Color playerCircleColor;
  final void Function(LineupPlayer)? onTap;

  @override
  Widget build(BuildContext context) {
    final players = rows.expand((row) => row).toList();
    if (players.isNotEmpty &&
        players.every((player) => player.formationPosition != null)) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final scaleY =
              constraints.maxHeight / FormationLayout.designSize.height;
          final awayLift = reverseVertical
              ? (FormationLayout.designSize.height -
                          FormationLayout.goalkeeper.dy) *
                      scaleY -
                  16
              : 0.0;
          final playerWidth = (LineupPitch._playerWidth *
                  constraints.maxWidth /
                  FormationLayout.designSize.width)
              .clamp(0.0, LineupPitch._playerWidth);
          return FormationPlayerPositions<LineupPlayer>(
            players: players,
            positionOf: (player) => player.formationPosition,
            playerWidth: LineupPitch._playerWidth,
            reverseVertical: reverseVertical,
            playerBuilder: (player) {
              final dot = _PlayerDot(
                player: player,
                width: playerWidth,
                playerCircleColor: playerCircleColor,
                onTap: onTap == null ? null : () => onTap!(player),
              );
              return reverseVertical
                  ? Transform.translate(
                      offset: Offset(0, -awayLift), child: dot)
                  : dot;
            },
          );
        },
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final row in rows)
          _PlayerRow(
            players: row,
            playerCircleColor: playerCircleColor,
            onTap: onTap,
          ),
      ],
    );
  }
}

//   One formation row

class _PlayerRow extends StatelessWidget {
  final List<LineupPlayer> players;
  final Color playerCircleColor;
  final void Function(LineupPlayer)? onTap;

  const _PlayerRow({
    required this.players,
    required this.playerCircleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final playerWidth = players.isEmpty
            ? 64.0
            : (constraints.maxWidth / players.length).clamp(0.0, 64.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: players
              .map((p) => _PlayerDot(
                    player: p,
                    width: playerWidth,
                    playerCircleColor: playerCircleColor,
                    onTap: onTap == null ? null : () => onTap!(p),
                  ))
              .toList(),
        );
      },
    );
  }
}

//   Single player dot: circle + badges + name

class _PlayerDot extends StatelessWidget {
  final LineupPlayer player;
  final double width;
  final Color playerCircleColor;
  final VoidCallback? onTap;

  const _PlayerDot({
    required this.player,
    required this.width,
    required this.playerCircleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardEvents = player.events.where((event) => switch (event.type) {
          LineupEventType.yellowCard ||
          LineupEventType.secondYellowCard ||
          LineupEventType.redCard =>
            true,
          _ => false,
        });
    final scoringEvents = player.events.where((event) =>
        event.type == LineupEventType.goal ||
        event.type == LineupEventType.assist);
    final rightEvents = player.events.where((event) =>
        event.type == LineupEventType.subIn ||
        event.type == LineupEventType.subOut ||
        event.type == LineupEventType.injury);
    final pitchInMinutes = player.events
        .where((event) => event.type == LineupEventType.subIn)
        .map((event) => event.minute)
        .whereType<int>()
        .map((minute) => "$minute'")
        .join(' · ');
    final pitchOutMinutes = player.events
        .where((event) => event.type == LineupEventType.subOut)
        .map((event) => event.minute)
        .whereType<int>()
        .map((minute) => "$minute'")
        .join(' · ');
    final cards =
        cardEvents.isEmpty ? null : _EventBadges(events: cardEvents.toList());
    final scoring = scoringEvents.isEmpty
        ? null
        : _EventBadges(events: scoringEvents.toList());
    final right =
        rightEvents.isEmpty ? null : _EventBadges(events: rightEvents.toList());
    return GestureDetector(
      key: ValueKey(
        'match-lineup-player-${player.teamId}-${player.playerId}',
      ),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _PlayerCircle(
                    number: player.number,
                    circleColor: playerCircleColor,
                  ),
                  if (cards != null)
                    Positioned(
                      key: const ValueKey('lineup-card-badges'),
                      top: -4,
                      left: -4,
                      child: cards,
                    ),
                  if (scoring != null)
                    Positioned(
                      key: const ValueKey('lineup-scoring-badges'),
                      left: -4,
                      bottom: -6,
                      child: scoring,
                    ),
                  if (right != null)
                    Positioned(
                      key: const ValueKey('lineup-pitch-out-badge'),
                      left: 24,
                      bottom: -6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          right,
                          if (pitchInMinutes.isNotEmpty) ...[
                            const SizedBox(width: 3),
                            Text(pitchInMinutes, style: Eyebrow.style),
                          ],
                          if (pitchOutMinutes.isNotEmpty) ...[
                            const SizedBox(width: 3),
                            Text(pitchOutMinutes, style: Eyebrow.style),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: width,
            height: 20 * MediaQuery.textScalerOf(context).scale(1),
            child: Center(
              child: Text(
                playerNameLabel(context, player.playerId, player.name,
                    short: true),
                style: Eyebrow.style,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//   Player circle

class _PlayerCircle extends StatelessWidget {
  final int? number;
  final Color circleColor;

  const _PlayerCircle({required this.number, required this.circleColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('lineup-player-circle'),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: circleColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(number?.toString() ?? '—',
            style: Heading5.style.copyWith(
              color: ColorUtils.monochromeTextColor(circleColor),
            )),
      ),
    );
  }
}

//   이벤트 종류별로 선수 원의 지정된 모서리에 겹쳐 표시하는 배지

class _EventBadges extends StatelessWidget {
  final List<LineupEvent> events;
  const _EventBadges({required this.events});

  static const double _badgeSize = 16;
  static const double _badgeOffset = 9;

  List<LineupEvent> get _displayEvents {
    final otherEvents = events.where((event) {
      return event.type != LineupEventType.yellowCard &&
          event.type != LineupEventType.secondYellowCard &&
          event.type != LineupEventType.redCard;
    }).toList();
    final yellowCards = events
        .where((event) => event.type == LineupEventType.yellowCard)
        .toList();
    final secondYellow = events
        .where((event) => event.type == LineupEventType.secondYellowCard)
        .firstOrNull;
    final directRed = events
        .where((event) => event.type == LineupEventType.redCard)
        .firstOrNull;

    if (directRed != null) {
      return [...otherEvents, directRed];
    }
    if (secondYellow != null) {
      final firstYellow = yellowCards.firstOrNull ??
          LineupEvent(
            type: LineupEventType.yellowCard,
            minute: secondYellow.minute,
          );
      return [
        ...otherEvents,
        firstYellow,
        LineupEvent(type: LineupEventType.redCard, minute: secondYellow.minute),
      ];
    }
    return [...otherEvents, ...yellowCards];
  }

  String _categoryFor(LineupEventType type) {
    return switch (type) {
      LineupEventType.yellowCard ||
      LineupEventType.secondYellowCard ||
      LineupEventType.redCard =>
        'card',
      _ => type.name,
    };
  }

  Map<String, List<LineupEvent>> get _groups {
    final groups = <String, List<LineupEvent>>{};
    for (final event in _displayEvents) {
      groups.putIfAbsent(_categoryFor(event.type), () => []).add(event);
    }
    return groups;
  }

  List<LineupEvent> get _orderedEvents => [
        for (final group in _groups.values) ...group,
      ];

  double get width {
    final eventCount = _orderedEvents.length;
    return eventCount == 0 ? 0 : _badgeSize + (eventCount - 1) * _badgeOffset;
  }

  @override
  Widget build(BuildContext context) {
    final orderedEvents = _orderedEvents;
    return SizedBox(
      key: const ValueKey('lineup-event-badge-groups'),
      width: width,
      height: _badgeSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < orderedEvents.length; index++)
            Positioned(
              left: index * _badgeOffset,
              child: KeyedSubtree(
                key: ValueKey(
                  'lineup-event-${orderedEvents[index].type.name}-$index',
                ),
                child: _iconFor(orderedEvents[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _iconFor(LineupEvent event) {
    final key = switch (event.type) {
      LineupEventType.goal => 'lineup-goal-icon',
      LineupEventType.assist => 'lineup-assist-icon',
      LineupEventType.subIn => 'lineup-sub-in-icon',
      LineupEventType.subOut => 'lineup-sub-out-icon',
      LineupEventType.injury => 'lineup-injury-icon',
      _ => null,
    };
    return MatchEventIcon(
      key: key == null ? null : ValueKey(key),
      type: event.type,
      size: _badgeSize,
      outlined: true,
    );
  }
}

//   Pitch markings

class _PitchMarkingsPainter extends CustomPainter {
  const _PitchMarkingsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 345 × 784 시안의 경기장 선을 실제 카드 너비에 비례시켜 그려요.
    final scaleX = size.width / 345;
    final scaleY = size.height / 784;
    final midY = 392 * scaleY;

    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), paint);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, midY),
        width: 192 * scaleX,
        height: 192 * scaleY,
      ),
      paint,
    );

    for (final (width, depth) in [(200.0, 120.0), (120.0, 40.0)]) {
      final left = (size.width - width * scaleX) / 2;
      final right = size.width - left;
      final top = depth * scaleY;
      final bottom = size.height - top;
      canvas.drawLine(Offset(left, 0), Offset(left, top), paint);
      canvas.drawLine(Offset(left, top), Offset(right, top), paint);
      canvas.drawLine(Offset(right, top), Offset(right, 0), paint);
      canvas.drawLine(Offset(left, size.height), Offset(left, bottom), paint);
      canvas.drawLine(Offset(left, bottom), Offset(right, bottom), paint);
      canvas.drawLine(Offset(right, bottom), Offset(right, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PitchMarkingsPainter oldDelegate) =>
      oldDelegate.color != color;
}
