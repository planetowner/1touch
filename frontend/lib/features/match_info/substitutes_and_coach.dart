part of 'match_info_features.dart';

class SubstitutesAndCoach extends StatefulWidget {
  final List<Substitute> subsA;
  final List<Substitute> subsB;
  final Map<int, List<LineupEvent>> eventsByPlayer;
  final String coachA;
  final String coachB;
  final String homeCode;
  final String awayCode;
  final void Function(BuildContext context, Substitute player)? onPlayerTap;

  const SubstitutesAndCoach({
    super.key,
    required this.subsA,
    required this.subsB,
    required this.eventsByPlayer,
    required this.coachA,
    required this.coachB,
    required this.homeCode,
    required this.awayCode,
    this.onPlayerTap,
  });

  @override
  State<SubstitutesAndCoach> createState() => _SubstitutesAndCoachState();
}

class _SubstitutesAndCoachState extends State<SubstitutesAndCoach> {
  bool _showHome = true;

  @override
  Widget build(BuildContext context) {
    final selectedSubs = _showHome ? widget.subsA : widget.subsB;
    final selectedCoach = _showHome ? widget.coachA : widget.coachB;
    final hasSubstitutes = widget.subsA.isNotEmpty || widget.subsB.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSegmentedToggle<bool>(
          containerKey: const ValueKey('match-substitutes-team-toggle'),
          value: _showHome,
          lightTrackColor: const Color(0xFFF4F4F4),
          options: [
            AppSegmentedToggleOption(
              value: true,
              label: widget.homeCode,
              contentKey: const ValueKey('match-substitutes-home-toggle'),
            ),
            AppSegmentedToggleOption(
              value: false,
              label: widget.awayCode,
              contentKey: const ValueKey('match-substitutes-away-toggle'),
            ),
          ],
          onChanged: (showHome) => setState(() => _showHome = showHome),
        ),
        const SizedBox(height: 24),
        if (hasSubstitutes) ...[
          Text(tr(context, "SUBSTITUTES"), style: Body2_b.style),
          const SizedBox(height: 16),
          if (selectedSubs.isEmpty)
            Text('—', style: Body1.style)
          else
            _SubList(
              subs: selectedSubs,
              eventsByPlayer: widget.eventsByPlayer,
              onPlayerTap: widget.onPlayerTap,
            ),
          const SizedBox(height: 16),
        ],
        Text(tr(context, "COACH"), style: Body2_b.style),
        const SizedBox(height: 16),
        Text(selectedCoach, style: Body1.style),
      ],
    );
  }
}

class _SubList extends StatelessWidget {
  final List<Substitute> subs;
  final Map<int, List<LineupEvent>> eventsByPlayer;
  final void Function(BuildContext context, Substitute player)? onPlayerTap;

  const _SubList({
    required this.subs,
    required this.eventsByPlayer,
    required this.onPlayerTap,
  });

  @override
  Widget build(BuildContext context) {
    // 교체선수 등번호만 테마에 맞는 50% 색상으로 보여줘요.
    final numberColor = (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black)
        .withValues(alpha: 0.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: subs.map((sub) {
        final name = playerNameLabel(context, sub.playerId, sub.name);
        // 같은 분의 이벤트는 응답 순서를 유지해 부상과 교체 아웃을 일렬로 보여줘요.
        final events = (eventsByPlayer[sub.playerId] ?? const <LineupEvent>[])
            .asMap()
            .entries
            .toList()
          ..sort((a, b) {
            final byMinute =
                (a.value.minute ?? 999).compareTo(b.value.minute ?? 999);
            return byMinute != 0 ? byMinute : a.key.compareTo(b.key);
          });
        final children = [
          if (sub.jerseyNumber == null)
            Text(name, style: Body1.style)
          else
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${sub.jerseyNumber} ',
                  style: TextStyle(color: numberColor),
                ),
                TextSpan(text: name),
              ]),
              style: Body1.style,
            ),
          for (final entry in events)
            if ((entry.value.type == LineupEventType.subIn ||
                    entry.value.type == LineupEventType.subOut) &&
                entry.value.minute != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MatchEventIcon(
                    type: entry.value.type,
                    size: 20,
                    substituteCardStyle: true,
                  ),
                  const SizedBox(width: 3),
                  Text("${entry.value.minute}'", style: Body1.style),
                ],
              )
            else
              MatchEventIcon(
                type: entry.value.type,
                substituteCardStyle: true,
                size: entry.value.type == LineupEventType.subIn ||
                        entry.value.type == LineupEventType.subOut
                    ? 20
                    : 16,
              ),
        ];

        return GestureDetector(
          key: ValueKey(
            'match-substitute-player-${sub.teamId}-${sub.playerId}',
          ),
          behavior: HitTestBehavior.opaque,
          onTap: onPlayerTap == null ? null : () => onPlayerTap!(context, sub),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: children,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
