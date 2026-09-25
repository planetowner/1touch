part of 'standing_features.dart';

class XgTable extends StatelessWidget {
  static const double _minimumStatsWidth = 215;
  static const double _statCellWidth = 36;

  final List<Map<String, dynamic>> standings;
  final int? currentTeamId;
  final int leagueId;
  final ScrollController horizontalScrollController;
  final bool isScrolledToEnd;

  const XgTable({
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
            key: const ValueKey('xg-standing-table-card'),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth < _minimumStatsWidth
            ? _minimumStatsWidth
            : constraints.maxWidth;

        return Container(
          color: AppColors.of(context).cardBackground,
          child: Stack(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: horizontalScrollController,
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              _buildXgHeaderCell(context, tr(context, 'MP')),
                              const SizedBox(width: 8),
                              _buildXgHeaderCell(context, 'xG'),
                              const SizedBox(width: 8),
                              _buildXgHeaderCell(context, 'xGA'),
                              const SizedBox(width: 8),
                              _buildXgHeaderCell(context, 'xPts'),
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
              ),
              if (!isScrolledToEnd && constraints.maxWidth < contentWidth)
                _buildStandingRightFade(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildXgHeaderCell(BuildContext context, String title) {
    return SizedBox(
      width: _statCellWidth,
      child: Text(
        title,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        textAlign: TextAlign.center,
        style: Body1.style,
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
          _buildXgStatCell('${team['mp']}', cellStyle),
          const SizedBox(width: 8),
          _buildXgStatCell(_formatXg(team['xg']), cellStyle),
          const SizedBox(width: 8),
          _buildXgStatCell(_formatXg(team['xga']), cellStyle),
          const SizedBox(width: 8),
          _buildXgStatCell(_formatXpts(team['xpts']), cellStyle),
        ],
      ),
    );
  }

  Widget _buildXgStatCell(String value, TextStyle style) {
    return SizedBox(
      width: _statCellWidth,
      height: 20,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          maxLines: 1,
          softWrap: false,
          style: style,
        ),
      ),
    );
  }

  String _formatXg(dynamic value) {
    if (value is num) return value.toStringAsFixed(1);
    return '—';
  }

  String _formatXpts(dynamic value) {
    if (value is num) return value.toStringAsFixed(1);
    return '—';
  }
}
