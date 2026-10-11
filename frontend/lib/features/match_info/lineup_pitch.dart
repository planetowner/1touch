part of 'match_info_features.dart';

class LineupPitch extends StatelessWidget {
  /// 원정팀은 골키퍼부터 공격수 순서로 위에서 아래에 배치해요.
  final List<List<LineupPlayer>> awayRows;

  /// 홈팀은 공격수부터 골키퍼 순서로 자기 진영의 위에서 아래에 배치해요.
  final List<List<LineupPlayer>> homeRows;

  /// 사용자가 선수 표시를 누르면 호출해요.
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

  static const double _playerWidth = 64;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, "LINEUP"), style: Body2_b.style),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: FormationLayout.designSize.width /
              (FormationLayout.designSize.height * 2),
          child: Container(
            key: const ValueKey('match-lineup-card'),
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
                // Past 시안은 392px 진영 두 개를 추가 여백 없이 이어 붙여요.
                Column(
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
              ],
            ),
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
          final playerWidth = (LineupPitch._playerWidth *
                  constraints.maxWidth /
                  FormationLayout.designSize.width)
              .clamp(0.0, LineupPitch._playerWidth);
          return FormationPlayerPositions<LineupPlayer>(
            players: players,
            positionOf: (player) {
              final position = player.formationPosition!;
              // 위쪽도 이름을 원 아래에 두므로 반전 후 20px 올려요.
              // 시안의 골키퍼 중심은 위쪽 y=40, 아래쪽 y=724예요.
              return reverseVertical ? position.translate(0, 20) : position;
            },
            playerWidth: LineupPitch._playerWidth,
            reverseVertical: reverseVertical,
            playerBuilder: (player) => _PlayerDot(
              player: player,
              width: playerWidth,
              playerCircleColor: playerCircleColor,
              onTap: onTap == null ? null : () => onTap!(player),
            ),
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final row in rows)
            _PlayerRow(
              players: row,
              playerCircleColor: playerCircleColor,
              onTap: onTap,
            ),
        ],
      ),
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
    // 카드 그림은 16px 배지 안에서 8px이므로 간격을 좁혀 실제 그림을 겹쳐요.
    final cards = cardEvents.isEmpty
        ? null
        : _EventBadges(events: cardEvents.toList(), offset: 5);
    final scoring = scoringEvents.isEmpty
        ? null
        : _EventBadges(events: scoringEvents.toList());
    final right =
        rightEvents.isEmpty ? null : _EventBadges(events: rightEvents.toList());
    // 한 개일 때의 위치를 중심으로 여러 배지를 양쪽에 펼쳐요.
    final cardLeft = cards == null ? 0.0 : -4.0 - (cards.width - 16) / 2;
    final rightLeft = right == null ? 21.0 : 21.0 - (right.width - 16) / 2;
    final centeredScoringLeft =
        scoring == null ? 0.0 : -4.0 - (scoring.width - 16) / 2;
    // 오른쪽 교체 배지와 최소 2px 간격을 두고 필요할 때만 왼쪽으로 옮겨요.
    final scoringLeft = scoring == null ||
            right == null ||
            centeredScoringLeft <= rightLeft - 2 - scoring.width
        ? centeredScoringLeft
        : rightLeft - 2 - scoring.width;
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
                      left: cardLeft,
                      child: cards,
                    ),
                  if (scoring != null)
                    Positioned(
                      key: const ValueKey('lineup-scoring-badges'),
                      left: scoringLeft,
                      bottom: -3,
                      child: scoring,
                    ),
                  if (right != null)
                    Positioned(
                      key: const ValueKey('lineup-pitch-out-badge'),
                      left: rightLeft,
                      // 오른쪽 이벤트는 이름과 1px 간격을 남기고 내려요.
                      bottom: -3,
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
          const SizedBox(height: FormationLayout.playerNameGap),
          SizedBox(
            width: width,
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
  final double offset;
  const _EventBadges({required this.events, this.offset = 9});

  static const double _badgeSize = 16;

  // 선발 명단의 교체 화살표와 부상 아이콘은 18px, 나머지는 16px이에요.
  double _iconSize(LineupEventType type) => type == LineupEventType.subIn ||
          type == LineupEventType.subOut ||
          type == LineupEventType.injury
      ? 18
      : _badgeSize;

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
    var extent = 0.0;
    for (var index = 0; index < _orderedEvents.length; index++) {
      final end = index * offset + _iconSize(_orderedEvents[index].type);
      if (end > extent) extent = end;
    }
    return extent;
  }

  @override
  Widget build(BuildContext context) {
    final orderedEvents = _orderedEvents;
    final height =
        orderedEvents.any((event) => _iconSize(event.type) > _badgeSize)
            ? 18.0
            : _badgeSize;
    return SizedBox(
      key: const ValueKey('lineup-event-badge-groups'),
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < orderedEvents.length; index++)
            Positioned(
              left: index * offset,
              bottom: 0,
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
      size: _iconSize(event.type),
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
