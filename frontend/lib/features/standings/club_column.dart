part of 'standing_features.dart';

class _ExpandableClubColumn extends StatefulWidget {
  const _ExpandableClubColumn({
    required this.standings,
    required this.currentTeamId,
    required this.leagueId,
  });

  final List<Map<String, dynamic>> standings;
  final int? currentTeamId;
  final int leagueId;

  @override
  State<_ExpandableClubColumn> createState() => _ExpandableClubColumnState();
}

class _ExpandableClubColumnState extends State<_ExpandableClubColumn> {
  static const _collapsedWidth = 146.0;
  static const _expandedWidth = 216.0;

  bool _isExpanded = false;

  void _toggleColumn() => setState(() => _isExpanded = !_isExpanded);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: const ValueKey('standing-club-column'),
      width: _isExpanded ? _expandedWidth : _collapsedWidth,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      color: AppColors.of(context).cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: AppColors.of(context).subtleBackground,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: 16,
            ),
            child: Text('Club', style: Body1.style),
          ),
          const SizedBox(height: 24),
          ...widget.standings.map((team) => _buildClubRow(context, team)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildClubRow(BuildContext context, Map<String, dynamic> team) {
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
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            color: marker?.color ?? Colors.transparent,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${team['rank']}',
                      style: textStyle,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => openTeamPage(context, teamId),
                    child: Image.network(
                      '${team['logo']}',
                      width: 20,
                      height: 20,
                      errorBuilder: (_, __, ___) =>
                          teamLogoFallback(teamId, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: _isExpanded
                          ? 'Collapse club names to short codes'
                          : 'Expand all club short codes to full names',
                      child: GestureDetector(
                        key: ValueKey('standing-club-name-$teamId'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _toggleColumn,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Align(
                            key: ValueKey(_isExpanded),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _isExpanded
                                  ? teamName
                                  : _shortCode(teamId, teamName),
                              maxLines: 1,
                              style: textStyle,
                              overflow: TextOverflow.ellipsis,
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
