part of 'match_info_features.dart';

class LineupPitch extends StatelessWidget {
  /// Away team rows ordered GK → attackers (displayed top → bottom).
  final List<List<LineupPlayer>> awayRows;

  /// Home team rows ordered attackers → GK (displayed top → bottom in their half).
  final List<List<LineupPlayer>> homeRows;

  /// Called when the user taps a player dot.
  final void Function(BuildContext context, LineupPlayer player)? onPlayerTap;
  final String? homeFormation;
  final String? awayFormation;

  const LineupPitch({
    super.key,
    required this.awayRows,
    required this.homeRows,
    this.onPlayerTap,
    this.homeFormation,
    this.awayFormation,
  });

  static const double _centerGap = 64;
  // Total pitch height — generous enough for either half to hold ~5-6 rows
  // comfortably. Bounded on purpose: each half below is `Expanded`, and
  // `MainAxisAlignment.spaceBetween` spreads whatever rows it actually has
  // evenly across that space — so the row *count* alone decides the
  // spacing, with no per-row pixel guess and no leftover gap anywhere.
  static const double _pitchHeight = 820;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("LINEUP", style: Body2_b.style),
            const Spacer(),
            Flexible(
              child: Text(
                'HOME ${homeFormation ?? '—'}  •  AWAY ${awayFormation ?? '—'}',
                style: Eyebrow.style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('match-lineup-card'),
          height: _pitchHeight,
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkGrey : AppPalette.white,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _PitchMarkingsPainter(
                    foreground.withValues(alpha: 0.18),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
                child: Column(
                  children: [
                    // Away: GK pinned to the top edge, attackers pinned to
                    // the halfway line — whatever rows fall in between
                    // spread out evenly across this half automatically.
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final row in awayRows)
                            _PlayerRow(
                              players: row,
                              isHome: false,
                              onTap: onPlayerTap == null
                                  ? null
                                  : (p) => onPlayerTap!(context, p),
                            ),
                        ],
                      ),
                    ),
                    // Gap that the center circle overlaps
                    const SizedBox(height: _centerGap),
                    // Home: attackers pinned to the halfway line, GK
                    // pinned to the bottom edge, same even spread.
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final row in homeRows)
                            _PlayerRow(
                              players: row,
                              isHome: true,
                              onTap: onPlayerTap == null
                                  ? null
                                  : (p) => onPlayerTap!(context, p),
                            ),
                        ],
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

//   One formation row

class _PlayerRow extends StatelessWidget {
  final List<LineupPlayer> players;
  final bool isHome;
  final void Function(LineupPlayer)? onTap;

  const _PlayerRow({
    required this.players,
    required this.isHome,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: players
          .map((p) => _PlayerDot(
                player: p,
                isHome: isHome,
                onTap: onTap == null ? null : () => onTap!(p),
              ))
          .toList(),
    );
  }
}

//   Single player dot: circle + badges + name

class _PlayerDot extends StatelessWidget {
  final LineupPlayer player;
  final bool isHome;
  final VoidCallback? onTap;

  const _PlayerDot({
    required this.player,
    required this.isHome,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pitchOutEvents = player.events
        .where((event) => event.type == LineupEventType.subOut)
        .toList();
    final lowerEvents = player.events
        .where((event) => event.type != LineupEventType.subOut)
        .toList();
    final substitutionMinutes = player.events
        .where(
          (event) =>
              event.type == LineupEventType.subIn ||
              event.type == LineupEventType.subOut,
        )
        .map((event) => event.minute)
        .whereType<int>()
        .map((minute) => "$minute'")
        .join(' · ');
    final badges =
        lowerEvents.isEmpty ? null : _EventBadges(events: lowerEvents);
    final badgeLeft = badges == null ? 0.0 : (32 - badges.width) / 2;
    final minuteLeft = badges == null ? 40.0 : badgeLeft + badges.width + 4;
    return GestureDetector(
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
                  _PlayerCircle(number: player.number, isHome: isHome),
                  if (pitchOutEvents.isNotEmpty)
                    Positioned(
                      key: const ValueKey('lineup-pitch-out-badge'),
                      top: -4,
                      right: -4,
                      child: _EventBadges(events: pitchOutEvents),
                    ),
                  if (badges != null)
                    Positioned(
                      left: badgeLeft,
                      bottom: -6,
                      child: badges,
                    ),
                  if (substitutionMinutes.isNotEmpty)
                    Positioned(
                      left: minuteLeft,
                      bottom: -5,
                      child: Center(
                        child: Text(substitutionMinutes, style: Body2.style),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: 64,
            child: Text(
              player.name,
              style: Eyebrow.style,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
  final bool isHome;

  const _PlayerCircle({required this.number, required this.isHome});

  static const _accent = Color(0xFFD82457);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('lineup-player-circle'),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isHome ? _accent : Colors.white,
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
              color: isHome ? Colors.white : Colors.black,
            )),
      ),
    );
  }
}

//   Event badges (to the right of the circle)

class _EventBadges extends StatelessWidget {
  final List<LineupEvent> events;
  const _EventBadges({required this.events});

  static const double _badgeSize = 12;
  static const double _badgeOffset = 7;

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
    if (secondYellow != null || yellowCards.length >= 2) {
      final firstYellow = yellowCards.firstOrNull ?? secondYellow!;
      final dismissal = secondYellow ?? yellowCards[1];
      return [
        ...otherEvents,
        firstYellow,
        LineupEvent(type: LineupEventType.redCard, minute: dismissal.minute),
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
    switch (event.type) {
      case LineupEventType.yellowCard:
        return SizedBox.square(
          dimension: _badgeSize,
          child: Center(
            child: Container(
              width: 7,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC00),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        );
      case LineupEventType.secondYellowCard:
      case LineupEventType.redCard:
        return SizedBox.square(
          dimension: _badgeSize,
          child: Center(
            child: Container(
              width: 7,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFE8000A),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        );
      case LineupEventType.goal:
        return SvgPicture.asset(
          'assets/match_info/soccer_ball.svg',
          key: const ValueKey('lineup-goal-icon'),
          width: _badgeSize,
          height: _badgeSize,
        );
      case LineupEventType.assist:
        return Container(
          key: const ValueKey('lineup-assist-icon'),
          width: _badgeSize,
          height: _badgeSize,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Text(
            'A',
            style: TextStyle(
              color: Colors.black,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        );
      case LineupEventType.subIn:
        return Container(
          key: const ValueKey('lineup-sub-in-icon'),
          width: _badgeSize,
          height: _badgeSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 9,
            color: Color(0xFF20B972),
          ),
        );
      case LineupEventType.subOut:
        return Container(
          key: const ValueKey('lineup-sub-out-icon'),
          width: _badgeSize,
          height: _badgeSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: const Icon(
            Icons.arrow_forward_rounded,
            size: 9,
            color: Color(0xFFFF4F5E),
          ),
        );
      case LineupEventType.injury:
        return Container(
          key: const ValueKey('lineup-injury-icon'),
          width: _badgeSize,
          height: _badgeSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: const Icon(
            Icons.add,
            size: 10,
            color: Color(0xFFFF4F5E),
          ),
        );
    }
  }
}

//   Pitch markings (halfway line + center circle)

class _PitchMarkingsPainter extends CustomPainter {
  const _PitchMarkingsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final midY = size.height / 2;

    // Halfway line
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), paint);

    // Center circle (~22% of width radius)
    canvas.drawCircle(Offset(size.width / 2, midY), size.width * 0.22, paint);
  }

  @override
  bool shouldRepaint(covariant _PitchMarkingsPainter oldDelegate) =>
      oldDelegate.color != color;
}
