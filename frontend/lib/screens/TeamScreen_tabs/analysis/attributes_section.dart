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
      List<TeamAttributeSeasonOption> options;
      try {
        options = await _repository.loadOptionsForTeam(teamId);
      } on Object {
        // Keep current-team attributes usable during a temporary options
        // failure. Historical teams require options because their season ID
        // cannot be inferred safely by the frontend.
        final all = await _repository.loadForTeam(teamId);
        if (!mounted || requestId != _requestId || teamId != _teamId) return;
        setState(() {
          _applyAttributes(all, const []);
          _isLoading = false;
        });
        return;
      }

      if (!mounted || requestId != _requestId || teamId != _teamId) return;

      if (options.isEmpty) {
        setState(() {
          _applyAttributes(const [], options);
          _isLoading = false;
        });
        return;
      }

      final baseline = options.firstWhere(
        (option) => option.isCurrent,
        orElse: () => options.first,
      );
      final all = await _repository.loadForTeam(
        teamId,
        seasonId: baseline.seasonId,
      );
      if (!mounted || requestId != _requestId || teamId != _teamId) return;

      setState(() {
        _applyAttributes(all, options);
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
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_myScores == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Text('No attribute data available',
            style: TextStyle(color: AppColors.of(context).mutedForeground)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //   Header: title + comparison picker
          _AnalysisSectionHeader(
            title: 'ATTRIBUTES',
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
              'Comparison data unavailable',
              key: const ValueKey('analysis-attributes-comparison-error'),
              style: TextStyle(color: AppColors.of(context).mutedForeground),
            ),
          ],
          const SizedBox(height: 16),

          //   Radar chart container
          Container(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.of(context).subtleBackground,
              borderRadius: BorderRadius.circular(24),
            ),
            child: _buildRadarChart(),
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
                _legendDot(const Color(0xFFE8434A), 'MY TEAM'),
                if (_comparisonScores != null)
                  _legendDot(
                    Theme.of(context).colorScheme.onSurface,
                    '${_compactSeasonLabel(_comparisonScores!.seasonLabel)} '
                    '${(teamRepository.findById(_comparisonScores!.teamId)?.name ?? 'Unknown Team').toUpperCase()}',
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
        ? 'SEASON'
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
        height: 44,
        constraints: const BoxConstraints(minWidth: 86),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.of(context).subtleBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: Body2_b.style.copyWith(color: colors.onSurface),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down,
              size: 24,
              color: colors.onSurface,
            ),
          ],
        ),
      ),
    );
  }

  //   Radar chart

  // Fixed frame for the radar's scale. fl_chart derives the chart's center and
  // radius from the min/max value across ALL datasets, so without a pinned
  // range MY TEAM's polygon would rescale (and visibly change shape) every time
  // a different comparison season is picked. Anchoring the floor/ceiling keeps
  // MY TEAM identical no matter what it's compared to. Attribute values are
  // clamped to 5-95, so 0..100 gives clean headroom and aligns with tickCount.
  static const double _radarFloor = 0;
  static const double _radarCeil = 100;

  Widget _buildRadarChart() {
    final appColors = AppColors.of(context);
    final comparisonColor = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: 260,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          tickCount: 4,
          gridBorderData: BorderSide(color: appColors.divider, width: 1),
          radarBorderData: BorderSide(color: appColors.divider, width: 1),
          tickBorderData: BorderSide(color: appColors.divider, width: 1),
          ticksTextStyle:
              const TextStyle(color: Colors.transparent, fontSize: 0),
          getTitle: (index, _) {
            final label = teamAttributeLabels[index];
            final moveOutward = label == 'Progression' || label == 'Possession';
            return RadarChartTitle(
              text: label,
              angle: 0,
              positionPercentageOffset: moveOutward ? 0.3 : null,
            );
          },
          titleTextStyle: Eyebrow.style,
          titlePositionPercentageOffset: 0.15,
          dataSets: [
            // MY TEAM — red
            RadarDataSet(
              fillColor: const Color(0xFFE8434A).withValues(alpha: 0.3),
              borderColor: const Color(0xFFE8434A),
              borderWidth: 2,
              entryRadius: 0,
              dataEntries: _myScores!.radarValues
                  .map((v) => RadarEntry(value: v))
                  .toList(),
            ),
            // Comparison — white outline
            if (_comparisonScores != null)
              RadarDataSet(
                fillColor: comparisonColor.withValues(alpha: 0.1),
                borderColor: comparisonColor.withValues(alpha: 0.85),
                borderWidth: 2,
                entryRadius: 0,
                dataEntries: _comparisonScores!.radarValues
                    .map((v) => RadarEntry(value: v))
                    .toList(),
              ),
            // Invisible anchor — pins the scale to a fixed [floor, ceil] range
            // so the visible polygons never rescale between comparisons.
            _scaleAnchorDataSet(),
          ],
        ),
      ),
    );
  }

  // Fully transparent dataset carrying one floor value and the rest at the
  // ceiling, so both minEntry and maxEntry across the chart stay constant.
  RadarDataSet _scaleAnchorDataSet() {
    final count = _myScores!.radarValues.length;
    return RadarDataSet(
      fillColor: Colors.transparent,
      borderColor: Colors.transparent,
      borderWidth: 0,
      entryRadius: 0,
      dataEntries: List.generate(
        count,
        (i) => RadarEntry(value: i == 0 ? _radarFloor : _radarCeil),
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
              label,
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
