part of 'standing_features.dart';

class _ExpandableClubColumn extends StatefulWidget {
  const _ExpandableClubColumn({
    required this.standings,
    required this.currentTeamId,
    required this.leagueId,
    required this.expandedWidth,
  });

  final List<Map<String, dynamic>> standings;
  final int? currentTeamId;
  final int leagueId;
  final double expandedWidth;

  @override
  State<_ExpandableClubColumn> createState() => _ExpandableClubColumnState();
}

class _ExpandableClubColumnState extends State<_ExpandableClubColumn> {
  static const _collapsedWidth = 130.0;
  static const _maximumExpandedWidth = 226.0;

  bool _isExpanded = false;

  void _toggleColumn() => setState(() => _isExpanded = !_isExpanded);

  @override
  Widget build(BuildContext context) {
    final expandedWidth = widget.expandedWidth
        .clamp(_collapsedWidth, _maximumExpandedWidth)
        .toDouble();
    const horizontalPadding = _standingTableHorizontalPadding;
    final teamNameWidth =
        _isExpanded ? expandedWidth - (horizontalPadding * 2) - 66 : 32.0;

    return AnimatedContainer(
      key: const ValueKey('standing-club-column'),
      width: _isExpanded ? expandedWidth : _collapsedWidth,
      duration: Duration.zero,
      decoration: BoxDecoration(
        color: AppColors.of(context).cardBackground,
      ),
      foregroundDecoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: AppColors.of(context).divider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const ValueKey('standing-club-header'),
            width: double.infinity,
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
                const SizedBox(width: 18),
                const SizedBox(width: 12),
                const SizedBox(width: 24),
                const SizedBox(width: 12),
                SizedBox(
                  width: teamNameWidth,
                  child: Text(
                    tr(context, 'Club'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: Body1.style,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ..._buildClubRows(
            context,
            horizontalPadding: horizontalPadding,
            teamNameWidth: teamNameWidth,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _buildClubRows(
    BuildContext context, {
    required double horizontalPadding,
    required double teamNameWidth,
  }) {
    return [
      for (var index = 0; index < widget.standings.length; index++) ...[
        _buildClubRow(
          context,
          widget.standings[index],
          horizontalPadding: horizontalPadding,
          teamNameWidth: teamNameWidth,
        ),
        if (index != widget.standings.length - 1) const SizedBox(height: 12),
      ],
    ];
  }

  Widget _buildClubRow(
    BuildContext context,
    Map<String, dynamic> team, {
    required double horizontalPadding,
    required double teamNameWidth,
  }) {
    final teamId = team['teamId'] as int;
    final teamName = '${team['team']}';
    final isCurrentTeam = teamId == widget.currentTeamId;
    final textStyle = Body2.style.copyWith(
      color: isCurrentTeam
          ? Theme.of(context).colorScheme.onSurface
          : AppColors.of(context).mutedForeground,
      fontWeight: isCurrentTeam ? FontWeight.bold : FontWeight.normal,
    );
    final marker =
        rulesForLeague(widget.leagueId)?.markerFor(team['rank'] as int);

    return SizedBox(
      width: double.infinity,
      height: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: -2,
            child: Container(
              key: ValueKey('standing-qualification-marker-$teamId'),
              width: 2,
              height: 24,
              color: marker?.color ?? Colors.transparent,
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                children: [
                  SizedBox(
                    key: ValueKey('standing-rank-$teamId'),
                    width: 18,
                    child: Text(
                      '${team['rank']}',
                      style: textStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    key: ValueKey('standing-logo-$teamId'),
                    onTap: isTeamPageSupported(teamId)
                        ? () => openTeamPage(context, teamId)
                        : null,
                    child: Image.network(
                      '${team['logo']}',
                      width: 24,
                      height: 24,
                      errorBuilder: (_, __, ___) =>
                          teamLogoFallback(teamId, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: teamNameWidth,
                    child: Semantics(
                      button: true,
                      label: _isExpanded
                          ? tr(context, 'Collapse club names to short codes')
                          : tr(context,
                              'Expand all club short codes to full names'),
                      child: GestureDetector(
                        key: ValueKey('standing-club-name-$teamId'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _toggleColumn,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Align(
                            key: ValueKey(_isExpanded),
                            alignment: Alignment.centerLeft,
                            child: _isExpanded
                                ? Text(
                                    key:
                                        ValueKey('standing-club-label-$teamId'),
                                    teamNameLabel(context, teamId, teamName),
                                    maxLines: 1,
                                    textAlign: TextAlign.left,
                                    style: textStyle,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : FittedBox(
                                    key:
                                        ValueKey('standing-club-label-$teamId'),
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _shortCode(teamId, teamName),
                                      maxLines: 1,
                                      softWrap: false,
                                      style: textStyle,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortCode(int teamId, String teamName) {
    final configured = teamRepository.findById(teamId)?.shortCode?.trim();
    if (configured != null && configured.isNotEmpty) {
      return configured.toUpperCase();
    }

    final words = teamName
        .replaceAll('-', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.length > 1) {
      return words.take(3).map((word) => word[0]).join().toUpperCase();
    }
    return teamName.substring(0, teamName.length.clamp(0, 3)).toUpperCase();
  }
}
