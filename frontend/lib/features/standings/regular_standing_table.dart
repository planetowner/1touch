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
      padding: const EdgeInsets.only(left: 24, right: 24),
      child: Container(
        key: const ValueKey('standing-table-card'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: appCardShadows(context),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExpandableClubColumn(
                standings: standings,
                currentTeamId: currentTeamId,
                leagueId: leagueId,
              ),
              Container(width: 1, color: AppColors.of(context).divider),
              Expanded(child: _buildStatsSide(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSide(BuildContext context) {
    return Container(
      color: AppColors.of(context).cardBackground,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: horizontalScrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                topRight:
                    isScrolledToEnd ? const Radius.circular(16) : Radius.zero,
              ),
              child: Container(
                color: AppColors.of(context).subtleBackground,
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 16,
                  top: 24,
                  bottom: 16,
                ),
                child: Row(
                  children: [
                    _buildHeaderCell(context, 'MP'),
                    _buildHeaderCell(context, 'W'),
                    _buildHeaderCell(context, 'D'),
                    _buildHeaderCell(context, 'L'),
                    _buildHeaderCell(context, 'GF'),
                    _buildHeaderCell(context, 'GA'),
                    _buildHeaderCell(context, 'GD'),
                    _buildHeaderCell(context, 'Pts'),
                    _buildHeaderCell(context, 'Last 5', isWide: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ...standings.map((team) => _buildStatRow(context, team)),
            ClipRRect(
              borderRadius: BorderRadius.only(
                bottomRight:
                    isScrolledToEnd ? const Radius.circular(16) : Radius.zero,
              ),
              child: Container(
                height: 24,
                color: AppColors.of(context).cardBackground,
              ),
            ),
          ],
        ),
      ),
    );
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
      padding: const EdgeInsets.only(left: 24, right: 16),
      child: Row(
        children: [
          _buildStatCell(context, '${team['mp']}', style: cellStyle),
          _buildStatCell(context, '${team['w']}', style: cellStyle),
          _buildStatCell(context, '${team['d']}', style: cellStyle),
          _buildStatCell(context, '${team['l']}', style: cellStyle),
          _buildStatCell(context, '${team['gf']}', style: cellStyle),
          _buildStatCell(context, '${team['ga']}', style: cellStyle),
          _buildStatCell(
            context,
            '${(team['gf'] as int) - (team['ga'] as int)}',
            style: cellStyle,
          ),
          _buildStatCell(context, '${team['pts']}', style: cellStyle),
          _buildLastFive(context, List<String>.from(team['last5'] as List)),
        ],
      ),
    );
  }

  Widget _buildLastFive(BuildContext context, List<String> results) {
    return SizedBox(
      width: 100,
      height: 44,
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
          return Icon(Icons.check_circle, size: 19, color: color);
        }).toList(),
      ),
    );
  }
}
