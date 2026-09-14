part of 'match_info_features.dart';

class SubstitutesAndCoach extends StatelessWidget {
  final List<Substitute> subsA;
  final List<Substitute> subsB;
  final String coachA;
  final String coachB;

  const SubstitutesAndCoach({
    super.key,
    required this.subsA,
    required this.subsB,
    required this.coachA,
    required this.coachB,
  });

  @override
  Widget build(BuildContext context) {
    final hasSubstitutes = subsA.isNotEmpty || subsB.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasSubstitutes) ...[
          const Text("SUBSTITUTES", style: Body2_b.style),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _SubList(subs: subsA, alignEnd: false)),
              Expanded(child: _SubList(subs: subsB, alignEnd: true)),
            ],
          ),
          const SizedBox(height: 24),
        ],
        const Text("COACH", style: Body2_b.style),
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

  const _SubList({required this.subs, required this.alignEnd});

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: subs.map((sub) {
        final children = [
          if (!alignEnd)
            Flexible(
              child: Text(sub.name,
                  style: Eyebrow.style, overflow: TextOverflow.ellipsis),
            ),
          if (sub.subIn) ...[
            const SizedBox(width: 4),
            Icon(Icons.arrow_circle_left, size: 20, color: foreground),
          ],
          if (sub.minute != null) ...[
            const SizedBox(width: 4),
            Text("${sub.minute}'", style: Eyebrow.style),
          ],
          if (sub.goal) ...[
            const SizedBox(width: 4),
            Icon(Icons.sports_soccer, size: 20, color: foreground),
          ],
          if (alignEnd)
            Flexible(
              child: Text(sub.name,
                  style: Eyebrow.style, overflow: TextOverflow.ellipsis),
            ),
        ];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment:
                alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: children,
          ),
        );
      }).toList(),
    );
  }
}
