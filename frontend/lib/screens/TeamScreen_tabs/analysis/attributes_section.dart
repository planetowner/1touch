part of '../analysis.dart';

//
// ATTRIBUTES — radar chart comparing the current team to a chosen reference
// (same team, different season).
//

class AttributesSection extends StatefulWidget {
  final TeamOverview? team;
  final TeamAttributeRepository? repository;

  const AttributesSection({
    super.key,
    required this.team,
    this.repository,
  });

  @override
  State<AttributesSection> createState() => _AttributesSectionState();
}

class _AttributesSectionState extends State<AttributesSection> {
  TeamAttributeScores? _myScores;
  TeamAttributeScores? _comparisonScores;
  List<TeamAttributeSeasonOption> _comparisonOptions = const [];
  bool _isLoading = true;
  bool _isComparisonLoading = false;
  bool _comparisonFailed = false;
  int? _selectedComparisonSeasonId;
  int? _selectedComparisonTeamId;
  int _requestId = 0;
  int _comparisonRequestId = 0;

  int? get _teamId => widget.team?.id;
  TeamAttributeRepository get _repository =>
      widget.repository ?? teamAttributeRepository;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAttributes());
  }

  @override
  void didUpdateWidget(AttributesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This section's State is reused across team switches (the Team-tab
    // branch stays alive in the bottom-nav shell), so reload instead of
    // only loading once in initState.
    if (widget.team?.id != oldWidget.team?.id ||
        widget.repository != oldWidget.repository) {
      setState(_resetAttributes);
      unawaited(_loadAttributes());
    }
  }

  Future<void> _loadAttributes() async {
    final requestId = ++_requestId;
    final teamId = _teamId;

    if (teamId == null) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _resetAttributes();
        _isLoading = false;
      });
      return;
    }

    try {
      final baseline = await loadTeamAttributeBaseline(_repository, teamId);
      if (!mounted || requestId != _requestId || teamId != _teamId) return;
      setState(() {
        _applyAttributes(baseline.scores, baseline.options);
        _isLoading = false;
      });
    } on Object {
      if (!mounted || requestId != _requestId || teamId != _teamId) return;
      setState(() {
        _myScores = null;
        _comparisonScores = null;
        _comparisonOptions = const [];
        _selectedComparisonSeasonId = null;
        _selectedComparisonTeamId = null;
        _isComparisonLoading = false;
        _comparisonFailed = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadComparison(int teamId, int seasonId) async {
    final requestId = ++_comparisonRequestId;

    setState(() {
      _selectedComparisonSeasonId = seasonId;
      _selectedComparisonTeamId = teamId;
      _comparisonScores = null;
      _isComparisonLoading = true;
      _comparisonFailed = false;
    });

    try {
      final loaded = await _repository.loadForTeam(
        teamId,
        seasonId: seasonId,
      );
      if (!mounted ||
          requestId != _comparisonRequestId ||
          teamId != _selectedComparisonTeamId ||
          seasonId != _selectedComparisonSeasonId) {
        return;
      }

      TeamAttributeScores? comparison;
      for (final scores in loaded) {
        if (scores.seasonId == seasonId) {
          comparison = scores;
          break;
        }
      }

      setState(() {
        _comparisonScores = comparison;
        _isComparisonLoading = false;
        _comparisonFailed = comparison == null;
      });
    } on Object {
      if (!mounted ||
          requestId != _comparisonRequestId ||
          teamId != _selectedComparisonTeamId ||
          seasonId != _selectedComparisonSeasonId) {
        return;
      }
      setState(() {
        _comparisonScores = null;
        _isComparisonLoading = false;
        _comparisonFailed = true;
      });
    }
  }

  void _resetAttributes() {
    _comparisonRequestId++;
    _myScores = null;
    _comparisonScores = null;
    _comparisonOptions = const [];
    _selectedComparisonSeasonId = null;
    _selectedComparisonTeamId = null;
    _isLoading = true;
    _isComparisonLoading = false;
    _comparisonFailed = false;
  }

  void _applyAttributes(
    List<TeamAttributeScores> all,
    List<TeamAttributeSeasonOption> options,
  ) {
    _myScores = null;
    _comparisonScores = null;
    _comparisonOptions = const [];
    _selectedComparisonSeasonId = null;
    _selectedComparisonTeamId = null;
    _isComparisonLoading = false;
    _comparisonFailed = false;
    _comparisonRequestId++;
    if (all.isEmpty) return;

    final currentSeasonIds = options
        .where((option) => option.isCurrent)
        .map((option) => option.seasonId)
        .toSet();
    _myScores = all.firstWhere(
      (a) => currentSeasonIds.contains(a.seasonId),
      orElse: () => all.first,
    );

    // The options endpoint already returns only seasons with stored scores,
    // newest first. The current season is the red MY TEAM series, so only
    // historical seasons belong in the comparison picker.
    _comparisonOptions = List.unmodifiable(
      options.where((option) => option.seasonId != _myScores!.seasonId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamPrimaryColor = _analysisTeamPrimaryColor(widget.team);
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Center(child: FootballLoadingIndicator()),
      );
    }

    if (_myScores == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Text(tr(context, 'No attribute data available'),
            style: TextStyle(color: AppColors.of(context).mutedForeground)),
      );
    }

    final comparisonTeam = _comparisonScores == null
        ? null
        : teamRepository.findById(_comparisonScores!.teamId);
    final comparisonColor = comparisonTeam == null
        ? null
        : TeamComparisonColorResolver.resolve(
            anchorTeamName: widget.team?.name ??
                teamRepository.findById(_myScores!.teamId)?.name,
            anchorPrimaryFallback: teamPrimaryColor,
            opponentTeamName: comparisonTeam.name,
            opponentPrimaryFallback: Color(comparisonTeam.primaryColor),
            background: AppColors.of(context).cardBackground,
          ).opponent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //   Header: title + comparison picker
          _AnalysisSectionHeader(
            title: teamScreenLabel(context, 'ATTRIBUTES'),
            trailing: footballCatalog.seasons.value.any((season) =>
                    TeamPageEligibility.domesticBigFiveCompetitionIds
                        .contains(season.competitionId))
                ? _buildComparisonPill()
                : null,
          ),
          if (_isComparisonLoading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(
              key: ValueKey('analysis-attributes-comparison-loading'),
              minHeight: 2,
            ),
          ] else if (_comparisonFailed) ...[
            const SizedBox(height: 8),
            Text(
              tr(context, 'Comparison data unavailable'),
              key: const ValueKey('analysis-attributes-comparison-error'),
              style: TextStyle(color: AppColors.of(context).mutedForeground),
            ),
          ],
          const SizedBox(height: 16),

          //   Radar chart container
          Container(
            key: const ValueKey('analysis-attributes-card'),
            padding: const EdgeInsets.symmetric(vertical: 25),
            decoration: BoxDecoration(
              color: AppColors.of(context).cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: appCardShadows(context),
            ),
            child: TeamAttributeRadar(
              scores: _myScores!,
              comparisonScores: _comparisonScores,
              currentColor: teamPrimaryColor,
              comparisonColor: comparisonColor,
              balanceVerticalMargins: true,
            ),
          ),

          //   Legend
          const SizedBox(height: 16),
          SizedBox(
            key: const ValueKey('analysis-attributes-legend'),
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 20,
              runSpacing: 8,
              children: [
                _legendDot(teamPrimaryColor, tr(context, 'MY TEAM')),
                if (_comparisonScores != null)
                  _legendDot(
                    comparisonColor ?? Colors.white,
                    '${compactSeasonLabel(_comparisonScores!.seasonLabel)} '
                    '${teamNameLabel(context, _comparisonScores!.teamId, teamRepository.findById(_comparisonScores!.teamId)?.name ?? 'Unknown Team').toUpperCase()}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openComparisonFilter() async {
    final ownTeamId = _teamId;
    if (ownTeamId == null) return;
    final eligibleTeamIds = <int, Set<int>>{};
    for (final membership in footballCatalog.memberships) {
      if (TeamPageEligibility.domesticBigFiveCompetitionIds
          .contains(membership.competitionId)) {
        eligibleTeamIds
            .putIfAbsent(membership.seasonId, () => <int>{})
            .add(membership.teamId);
      }
    }
    // The current team's stored scores must not restrict seasons available
    // for other Big Five teams, including the current season.
    final seasons = footballCatalog.seasons.value.where(
      (season) =>
          TeamPageEligibility.domesticBigFiveCompetitionIds
              .contains(season.competitionId) &&
          (eligibleTeamIds[season.seasonId]?.any(
                (teamId) => teamRepository.findById(teamId) != null,
              ) ??
              false),
    );
    final options = <_AnalysisFilterOption<({int teamId, int seasonId})>>[
      for (final season in seasons)
        if (!teamRepository.allTeams.any((team) => team.teamId == ownTeamId))
          if (eligibleTeamIds[season.seasonId]?.contains(ownTeamId) ?? false)
            _AnalysisFilterOption(
              value: (teamId: ownTeamId, seasonId: season.seasonId),
              seasonId: season.seasonId,
              seasonName: season.name,
              teamId: ownTeamId,
              teamName:
                  teamNameLabel(context, ownTeamId, widget.team?.name ?? ''),
            ),
      for (final season in seasons)
        for (final team in teamRepository.allTeams)
          if (eligibleTeamIds[season.seasonId]?.contains(team.teamId) ?? false)
            _AnalysisFilterOption(
              value: (teamId: team.teamId, seasonId: season.seasonId),
              seasonId: season.seasonId,
              seasonName: season.name,
              teamId: team.teamId,
              teamName: teamNameLabel(context, team.teamId, team.name),
            ),
    ];
    if (options.isEmpty) return;
    final initialValue = _selectedComparisonSeasonId == null
        ? options
                .where((option) =>
                    option.teamId == ownTeamId &&
                    option.seasonId == _comparisonOptions.firstOrNull?.seasonId)
                .firstOrNull
                ?.value ??
            options.first.value
        : (
            teamId: _selectedComparisonTeamId ?? ownTeamId,
            seasonId: _selectedComparisonSeasonId!,
          );
    final selected = await showModalBottomSheet<({int teamId, int seasonId})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _AnalysisComparisonFilterSheet<({int teamId, int seasonId})>(
        options: options,
        initialValue: initialValue,
        optionKey: (value) =>
            'analysis-attributes-option-${value.teamId}-${value.seasonId}',
      ),
    );
    if (mounted && selected != null) {
      unawaited(_loadComparison(selected.teamId, selected.seasonId));
    }
  }

  Widget _buildComparisonPill() {
    TeamAttributeSeasonOption? selectedSeason;
    for (final season in _comparisonOptions) {
      if (season.seasonId == _selectedComparisonSeasonId) {
        selectedSeason = season;
        break;
      }
    }

    // Cross-league selections have different season IDs from this team's options.
    final selectedSeasonName = selectedSeason?.seasonName ??
        (_comparisonScores?.seasonId == _selectedComparisonSeasonId
            ? _comparisonScores?.seasonLabel
            : null);
    final label = selectedSeasonName == null
        ? trUpper(context, 'Season')
        : compactSeasonLabel(selectedSeasonName);
    final selectedTeamId = _selectedComparisonTeamId;
    final selectedTeam =
        selectedTeamId == null ? null : teamRepository.findById(selectedTeamId);
    final teamLabel = selectedTeamId == null
        ? trUpper(context, 'Team')
        : (selectedTeam?.shortCode?.trim().isNotEmpty == true
                ? selectedTeam!.shortCode!
                : teamNameLabel(
                    context,
                    selectedTeamId,
                    selectedTeam?.name ?? 'Unknown Team',
                  ))
            .toUpperCase();

    return _AnalysisComparisonFilterPill(
      filterKey: const ValueKey('analysis-attributes-filter'),
      dividerKey: const ValueKey('analysis-attributes-filter-divider'),
      seasonLabel: tr(context, label),
      teamLabel: teamLabel,
      onTap: _openComparisonFilter,
    );
  }

  Widget _legendDot(Color color, String label) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 48,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              tr(context, label),
              style: Body2_b.style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
