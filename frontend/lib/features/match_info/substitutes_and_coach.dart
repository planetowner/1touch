part of 'match_info_features.dart';

class SubstitutesAndCoach extends StatefulWidget {
  final List<Substitute> subsA;
  final List<Substitute> subsB;
  final String coachA;
  final String coachB;
  final String homeCode;
  final String awayCode;
  final void Function(BuildContext context, Substitute player)? onPlayerTap;

  const SubstitutesAndCoach({
    super.key,
    required this.subsA,
    required this.subsB,
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
            _SubList(subs: selectedSubs, onPlayerTap: widget.onPlayerTap),
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
  final void Function(BuildContext context, Substitute player)? onPlayerTap;

  const _SubList({
    required this.subs,
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
          if (sub.subIn) ...[
            const MatchEventIcon(type: LineupEventType.subIn),
          ],
          if (sub.minute != null) ...[
            Text("${sub.minute}'", style: Body1.style),
          ],
          if (sub.goal) ...[
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
