part of '../Analysis.dart';

Color _analysisTeamPrimaryColor(TeamOverview? team) {
  final repositoryTeam = team == null ? null : teamRepository.findById(team.id);
  return TeamComparisonColorResolver.paletteFor(
    teamName: team?.name ?? repositoryTeam?.name,
    primaryFallback:
        repositoryTeam == null ? null : Color(repositoryTeam.primaryColor),
  ).primary;
}

class _AnalysisSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _AnalysisSectionHeader({
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final control = trailing;
    if (control == null) return Text(tr(context, title), style: Body2_b.style);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(context, title), style: Body2_b.style),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: control),
            ],
          );
        }

        return Row(
          children: [
            Text(tr(context, title), style: Body2_b.style),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: control,
              ),
            ),
          ],
        );
      },
    );
  }
}
