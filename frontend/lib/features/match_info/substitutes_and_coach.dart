part of 'match_info_features.dart';

class SubstitutesAndCoach extends StatelessWidget {
  final List<Substitute> subsA;
  final List<Substitute> subsB;
  final String coachA;
  final String coachB;
  final void Function(BuildContext context, Substitute player)? onPlayerTap;

  const SubstitutesAndCoach({
    super.key,
    required this.subsA,
    required this.subsB,
    required this.coachA,
    required this.coachB,
    this.onPlayerTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasSubstitutes = subsA.isNotEmpty || subsB.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasSubstitutes) ...[
          Text(tr(context, "SUBSTITUTES"), style: Body2_b.style),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SubList(
                  subs: subsA,
                  alignEnd: false,
                  onPlayerTap: onPlayerTap,
                ),
              ),
              Expanded(
                child: _SubList(
                  subs: subsB,
                  alignEnd: true,
                  onPlayerTap: onPlayerTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        Text(tr(context, "COACH"), style: Body2_b.style),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(coachA, style: Eyebrow.style),
            Text(coachB, style: Eyebrow.style),
          ],
        ),
      ],
    );
  }
}

class _SubList extends StatelessWidget {
  final List<Substitute> subs;
  final bool alignEnd;
  final void Function(BuildContext context, Substitute player)? onPlayerTap;

  const _SubList({
    required this.subs,
    required this.alignEnd,
    required this.onPlayerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: subs.map((sub) {
        final children = [
          Flexible(
            child: Text(sub.name,
                style: Eyebrow.style, overflow: TextOverflow.ellipsis),
          ),
          if (sub.subIn) ...[
            const SizedBox(width: 4),
            const MatchEventIcon(type: LineupEventType.subIn),
          ],
          if (sub.minute != null) ...[
            const SizedBox(width: 4),
            Text("${sub.minute}'", style: Eyebrow.style),
          ],
          if (sub.goal) ...[
            const SizedBox(width: 4),
            const MatchEventIcon(type: LineupEventType.goal),
          ],
        ];

        return GestureDetector(
          key: ValueKey(
            'match-substitute-player-${sub.teamId}-${sub.playerId}',
          ),
          behavior: HitTestBehavior.opaque,
          onTap: onPlayerTap == null ? null : () => onPlayerTap!(context, sub),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment:
                  alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: alignEnd ? children.reversed.toList() : children,
            ),
          ),
        );
      }).toList(),
    );
  }
}
