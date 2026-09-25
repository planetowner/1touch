part of 'standing_features.dart';

class StandingTable extends StatelessWidget {
  final List<Map<String, dynamic>> standings;
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: horizontalScrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topRight: isScrolledToEnd
                        ? const Radius.circular(24)
                        : Radius.zero,
                  ),
                  child: Container(
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
                        _buildHeaderCell(context, tr(context, 'MP')),
                        const SizedBox(width: 8),
                        _buildHeaderCell(context, tr(context, 'W')),
                        const SizedBox(width: 8),
                        _buildHeaderCell(context, tr(context, 'D')),
                        const SizedBox(width: 8),
                        _buildHeaderCell(context, tr(context, 'L')),
                        const SizedBox(width: 8),
                        _buildHeaderCell(context, tr(context, 'GF')),
                        const SizedBox(width: 8),
                        _buildHeaderCell(context, tr(context, 'GA')),
                        const SizedBox(width: 8),
                        _buildHeaderCell(context, tr(context, 'GD')),
                        const SizedBox(width: 8),
                        _buildHeaderCell(context, tr(context, 'Pts')),
                        const SizedBox(width: 12),
                        _buildHeaderCell(context, tr(context, 'Last 5'),
                            isWide: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ..._buildStatRows(context),
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    bottomRight: isScrolledToEnd
                        ? const Radius.circular(24)
                        : Radius.zero,
                  ),
                  child: Container(
                    height: 24,
                    color: AppColors.of(context).cardBackground,
                  ),
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

  Widget _buildStatRow(BuildContext context, Map<String, dynamic> team) {
    final isCurrentTeam = team['teamId'] == currentTeamId;
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
          _buildStatCell(context, '${team['mp']}', style: cellStyle),
          const SizedBox(width: 8),
          _buildStatCell(context, '${team['w']}', style: cellStyle),
          const SizedBox(width: 8),
          _buildStatCell(context, '${team['d']}', style: cellStyle),
          const SizedBox(width: 8),
          _buildStatCell(context, '${team['l']}', style: cellStyle),
          const SizedBox(width: 8),
          _buildStatCell(context, '${team['gf']}', style: cellStyle),
          const SizedBox(width: 8),
          _buildStatCell(context, '${team['ga']}', style: cellStyle),
          const SizedBox(width: 8),
          _buildStatCell(
            context,
            '${(team['gf'] as int) - (team['ga'] as int)}',
            style: cellStyle,
          ),
          const SizedBox(width: 8),
          _buildStatCell(context, '${team['pts']}', style: cellStyle),
          const SizedBox(width: 12),
          _buildLastFive(context, List<String>.from(team['last5'] as List)),
        ],
      ),
    );
  }

  Widget _buildLastFive(BuildContext context, List<String> results) {
    return SizedBox(
      width: 100,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: results.map((result) {
          Color color;
          switch (result) {
            case 'W':
              color = Colors.blue;
              break;
            case 'D':
              color = Colors.grey;
              break;
            case 'L':
              color = Colors.red;
              break;
            default:
              color = Theme.of(context).colorScheme.onSurface;
          }
          return Icon(Icons.check_circle, size: 20, color: color);
        }).toList(),
      ),
    );
  }
}
