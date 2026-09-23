part of 'standing_features.dart';

class StandingsLegend extends StatelessWidget {
  final int leagueId;

  const StandingsLegend({super.key, required this.leagueId});

  @override
  Widget build(BuildContext context) {
    final rules = rulesForLeague(leagueId);
    if (rules == null) return const SizedBox.shrink();

    final tiers = rules.availableTiers;
    if (tiers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 20,
        runSpacing: 8,
        children: tiers.map((tier) => _LegendItem(tier: tier)).toList(),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final QualificationTier tier;

  const _LegendItem({required this.tier});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: tier.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(tr(context, tier.label), style: Body2_b.style),
      ],
    );
  }
}
