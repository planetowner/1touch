part of '../analysis.dart';

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

class _AnalysisComparisonFilterPill extends StatelessWidget {
  final Key filterKey;
  final Key dividerKey;
  final String seasonLabel;
  final String teamLabel;
  final VoidCallback? onTap;

  const _AnalysisComparisonFilterPill({
    required this.filterKey,
    required this.dividerKey,
    required this.seasonLabel,
    required this.teamLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyle =
        Body2_b.style.copyWith(color: colors.onSurface, height: 1.30);

    return InkWell(
      key: filterKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.of(context).subtleBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(seasonLabel, style: textStyle),
            const SizedBox(width: 8),
            SizedBox(
              key: dividerKey,
              width: 1,
              height: 26,
              child: ColoredBox(
                color: colors.onSurface.withValues(alpha: 0.30),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                teamLabel,
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
