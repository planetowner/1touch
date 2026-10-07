part of 'standing_features.dart';

class StandingTable extends StatelessWidget {
  final List<Standing> standings;
  final int? currentTeamId;
  final int leagueId;
  final ScrollController horizontalScrollController;
  final bool isScrolledToEnd;

  const StandingTable({
    super.key,
    required this.standings,
    required this.currentTeamId,
    required this.leagueId,
    required this.horizontalScrollController,
    required this.isScrolledToEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final expandedClubWidth =
              (constraints.maxWidth - 136).clamp(130.0, 226.0).toDouble();

          return Container(
            key: const ValueKey('standing-table-card'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: appCardShadows(context),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ExpandableClubColumn(
                        standings: standings,
                        teamIdOf: (standing) => standing.teamId,
                        rankOf: (standing) => standing.position,
                        teamNameOf: (standing) =>
                            standing.teamName ?? 'Unknown Team',
                        teamLogoOf: (standing) => standing.teamLogo ?? '',
                        currentTeamId: currentTeamId,
                        leagueId: leagueId,
                        expandedWidth: expandedClubWidth,
                      ),
                      Expanded(child: _buildStatsSide(context)),
                    ],
                  ),
                  Positioned(
                    key: const ValueKey('standing-header-divider'),
                    left: 0,
                    right: 0,
                    top: 59,
                    child: Container(
                      height: 1,
                      color: AppColors.of(context).divider,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsSide(BuildContext context) {
    return Container(
      color: AppColors.of(context).cardBackground,
      child: Stack(
        children: [
          Positioned(
            key: const ValueKey('standing-stats-header-backdrop'),
            top: 0,
            left: 0,
            right: 0,
            height: 59,
            child: ColoredBox(color: AppColors.of(context).subtleBackground),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: horizontalScrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  key: const ValueKey('standing-stats-header'),
                  height: 59,
                  color: AppColors.of(context).subtleBackground,
                  padding: const EdgeInsets.fromLTRB(
                    _standingTableHorizontalPadding,
                    24,
                    _standingTableHorizontalPadding,
                    16,
                  ),
                  child: Row(
                    children: [
                      _buildHeaderCell(
                        context,
                        'Pts',
                        key: const ValueKey('standing-header-pts'),
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderCell(
                        context,
                        'MP',
                        key: const ValueKey('standing-header-mp'),
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderCell(
                        context,
                        'W',
                        key: const ValueKey('standing-header-w'),
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderCell(
                        context,
                        'D',
                        key: const ValueKey('standing-header-d'),
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderCell(
                        context,
                        'L',
                        key: const ValueKey('standing-header-l'),
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderCell(
                        context,
                        'GF',
                        key: const ValueKey('standing-header-gf'),
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderCell(
                        context,
                        'GA',
                        key: const ValueKey('standing-header-ga'),
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderCell(
                        context,
                        'GD',
                        key: const ValueKey('standing-header-gd'),
                      ),
                      const SizedBox(width: 12),
                      _buildHeaderCell(
                        context,
                        'Last 5',
                        isWide: true,
                        key: const ValueKey('standing-header-last-five'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ..._buildStatRows(context),
                Container(
                  height: 24,
                  color: AppColors.of(context).cardBackground,
                ),
              ],
            ),
          ),
          if (!isScrolledToEnd) _buildStandingRightFade(context),
        ],
      ),
    );
  }

  List<Widget> _buildStatRows(BuildContext context) {
    return [
      for (var index = 0; index < standings.length; index++) ...[
        _buildStatRow(context, standings[index]),
        if (index != standings.length - 1) const SizedBox(height: 12),
      ],
    ];
  }

  Widget _buildStatRow(BuildContext context, Standing team) {
    final isCurrentTeam = team.teamId == currentTeamId;
    final teamId = team.teamId;
    final cellStyle = Body2.style.copyWith(
      color: isCurrentTeam
          ? Theme.of(context).colorScheme.onSurface
          : AppColors.of(context).mutedForeground,
      fontWeight: isCurrentTeam ? FontWeight.bold : FontWeight.normal,
    );

    return Container(
      color: AppColors.of(context).cardBackground,
      padding: const EdgeInsets.symmetric(
        horizontal: _standingTableHorizontalPadding,
      ),
      child: Row(
        children: [
          _buildStatCell(
            context,
            '${team.points}',
            style: cellStyle,
            key: ValueKey('standing-stat-$teamId-pts'),
          ),
          const SizedBox(width: 8),
          _buildStatCell(
            context,
            '${team.matchesPlayed}',
            style: cellStyle,
            key: ValueKey('standing-stat-$teamId-mp'),
          ),
          const SizedBox(width: 8),
          _buildStatCell(
            context,
            '${team.won}',
            style: cellStyle,
            key: ValueKey('standing-stat-$teamId-w'),
          ),
          const SizedBox(width: 8),
          _buildStatCell(
            context,
            '${team.draw}',
            style: cellStyle,
            key: ValueKey('standing-stat-$teamId-d'),
          ),
          const SizedBox(width: 8),
          _buildStatCell(
            context,
            '${team.lost}',
            style: cellStyle,
            key: ValueKey('standing-stat-$teamId-l'),
          ),
          const SizedBox(width: 8),
          _buildStatCell(
            context,
            '${team.goalsFor}',
            style: cellStyle,
            key: ValueKey('standing-stat-$teamId-gf'),
          ),
          const SizedBox(width: 8),
          _buildStatCell(
            context,
            '${team.goalsAgainst}',
            style: cellStyle,
            key: ValueKey('standing-stat-$teamId-ga'),
          ),
          const SizedBox(width: 8),
          _buildStatCell(
            context,
            '${team.goalDiff}',
            style: cellStyle,
            key: ValueKey('standing-stat-$teamId-gd'),
          ),
          const SizedBox(width: 12),
          _buildLastFive(
            context,
            team.last5Form,
            teamId: teamId,
          ),
        ],
      ),
    );
  }

  Widget _buildLastFive(
    BuildContext context,
    List<String> results, {
    required int teamId,
  }) {
    return SizedBox(
      width: _standingLastFiveWidth,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var index = 0; index < results.length; index++)
            Icon(
              switch (results[index]) {
                'W' => Icons.check_circle,
                'D' => Icons.remove_circle,
                'L' => Icons.cancel,
                _ => Icons.help_outline,
              },
              key: ValueKey('standing-last-five-$teamId-$index'),
              size: 16,
              color: switch (results[index]) {
                'W' => Colors.green,
                'D' => Colors.grey,
                'L' => Colors.red,
                _ => Theme.of(context).colorScheme.onSurface,
              },
            ),
        ],
      ),
    );
  }
}
