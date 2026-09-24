part of '../Analysis.dart';

//
// ATTRIBUTES — radar chart comparing the current team to a chosen reference
// (same team, different season).
//

class AttributesSection extends StatefulWidget {
  final Map<String, dynamic>? team;
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
  int _requestId = 0;
  int _comparisonRequestId = 0;

  int? get _teamId => widget.team?['id'] as int?;
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
    if (widget.team?['id'] != oldWidget.team?['id'] ||
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
        _isComparisonLoading = false;
        _comparisonFailed = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadComparison(int seasonId) async {
    final requestId = ++_comparisonRequestId;
    final teamId = _teamId;

    if (teamId == null) return;

    setState(() {
      _selectedComparisonSeasonId = seasonId;
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
          teamId != _teamId ||
          seasonId != _selectedComparisonSeasonId) {
        return;
      }

      TeamAttributeScores? comparison;
      for (final scores in loaded) {
        if (scores.seasonId == seasonId &&
            scores.competitionId == _myScores?.competitionId) {
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
          teamId != _teamId ||
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
        child: Center(child: CircularProgressIndicator()),
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
            anchorTeamName: widget.team?['name'] as String? ??
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
            title: tr(context, 'ATTRIBUTES'),
            trailing:
                _comparisonOptions.isNotEmpty ? _buildComparisonPill() : null,
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
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.of(context).cardBackground,
              borderRadius: BorderRadius.circular(24),
              boxShadow: appCardShadows(context),
            ),
            child: TeamAttributeRadar(
              scores: _myScores!,
              comparisonScores: _comparisonScores,
              currentColor: teamPrimaryColor,
              comparisonColor: comparisonColor,
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
                    '${_compactSeasonLabel(_comparisonScores!.seasonLabel)} '
                    '${teamNameLabel(context, _comparisonScores!.teamId, teamRepository.findById(_comparisonScores!.teamId)?.name ?? 'Unknown Team').toUpperCase()}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //   Comparison picker pill (season-only for now)

  Widget _buildComparisonPill() {
    final colors = Theme.of(context).colorScheme;

    TeamAttributeSeasonOption? selectedSeason;
    for (final season in _comparisonOptions) {
      if (season.seasonId == _selectedComparisonSeasonId) {
        selectedSeason = season;
        break;
      }
    }

    final label = selectedSeason == null
        ? tr(context, 'SEASON')
        : _compactSeasonLabel(selectedSeason.seasonName);

    return PopupMenuButton<int>(
      key: const ValueKey('analysis-attributes-filter'),
      tooltip: '',
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      color: AppColors.of(context).cardBackground,
      onSelected: (seasonId) {
        unawaited(_loadComparison(seasonId));
      },
      itemBuilder: (_) => _comparisonOptions
          .map(
            (season) => PopupMenuItem<int>(
              value: season.seasonId,
              child: Text(
                _compactSeasonLabel(season.seasonName),
                style: Body2_b.style.copyWith(color: colors.onSurface),
              ),
            ),
          )
          .toList(),
      child: Container(
        height: AppDropdownTokens.height,
        constraints: const BoxConstraints(minWidth: 86),
        padding: AppDropdownTokens.triggerPadding,
        decoration: BoxDecoration(
          color: AppColors.of(context).subtleBackground,
          borderRadius: BorderRadius.circular(AppDropdownTokens.radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              tr(context, label),
              style: Body2_b.style.copyWith(color: colors.onSurface),
            ),
            const SizedBox(width: AppDropdownTokens.gap),
            AppDropdownChevron(color: colors.onSurface),
          ],
        ),
      ),
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
