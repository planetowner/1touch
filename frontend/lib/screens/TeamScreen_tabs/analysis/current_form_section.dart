part of '../analysis.dart';

class CurrentFormSection extends StatefulWidget {
  final TeamOverview? team;
  final CurrentFormRepository? repository;

  const CurrentFormSection({
    super.key,
    required this.team,
    this.repository,
  });

  @override
  State<CurrentFormSection> createState() => _CurrentFormSectionState();
}

class _CurrentFormSectionState extends State<CurrentFormSection> {
  List<CurrentFormOption> _options = const [];
  CurrentFormOption? _selectedOption;
  CurrentFormComparison? _comparison;
  bool _isLoading = false;
  bool _loadFailed = false;
  int _loadRequestId = 0;
  int? _baselineSeasonId;
  int? _selectedFormRound;

  CurrentFormRepository get _repository =>
      widget.repository ?? currentFormRepository;

  int? get _teamId => widget.team?.id;

  String? get _currentSeasonName {
    final teamId = _teamId;
    final seasonId =
        teamId == null ? null : footballCatalog.resolve(teamId)?.seasonId;
    return footballCatalog.seasons.value
        .where((season) => season.seasonId == seasonId)
        .firstOrNull
        ?.name;
  }

  @override
  void initState() {
    super.initState();
    _startDefaultLoad();
  }

  @override
  void didUpdateWidget(CurrentFormSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_teamId != oldWidget.team?.id ||
        widget.repository != oldWidget.repository) {
      _startDefaultLoad();
    }
  }

  void _startDefaultLoad() {
    final teamId = _teamId;
    final requestId = ++_loadRequestId;
    final cachedOptions = teamId == null
        ? null
        : _repository.cachedOptionsFor(teamId, seasonName: _currentSeasonName);
    final baselineOption = teamId == null || cachedOptions == null
        ? null
        : _baselineOption(cachedOptions, teamId);
    final bootstrapOption = baselineOption;
    final cachedComparison = bootstrapOption == null
        ? null
        : _repository.cachedComparisonFor(
            teamId!,
            seasonId: baselineOption?.seasonId,
            compareTeamId: bootstrapOption.teamId,
            compareSeasonId: bootstrapOption.seasonId,
          );

    _options = cachedOptions ?? const [];
    _baselineSeasonId = baselineOption?.seasonId;
    _selectedOption = null;
    _comparison = cachedComparison;
    _selectedFormRound = null;
    _loadFailed = false;
    _isLoading = teamId != null &&
        (cachedOptions == null ||
            (bootstrapOption != null && cachedComparison == null));

    if (teamId == null) return;
    if (cachedOptions == null) {
      unawaited(_loadOptions(teamId, requestId));
    } else if (bootstrapOption != null && cachedComparison == null) {
      unawaited(
        _loadComparison(
          teamId,
          bootstrapOption.seasonId,
          bootstrapOption,
          requestId,
        ),
      );
    }
  }

  Future<void> _loadOptions(int teamId, int requestId) async {
    try {
      final options =
          await _repository.loadOptions(teamId, seasonName: _currentSeasonName);
      if (!mounted || requestId != _loadRequestId) return;

      final baselineOption = _baselineOption(options, teamId);
      final bootstrapOption = baselineOption;
      final cachedComparison = bootstrapOption == null
          ? null
          : _repository.cachedComparisonFor(
              teamId,
              seasonId: bootstrapOption.seasonId,
              compareTeamId: bootstrapOption.teamId,
              compareSeasonId: bootstrapOption.seasonId,
            );
      setState(() {
        _options = options;
        _baselineSeasonId = baselineOption?.seasonId;
        _selectedOption = null;
        _comparison = cachedComparison;
        _isLoading = bootstrapOption != null && cachedComparison == null;
      });

      if (baselineOption != null &&
          bootstrapOption != null &&
          cachedComparison == null) {
        unawaited(
          _loadComparison(
            teamId,
            baselineOption.seasonId,
            bootstrapOption,
            requestId,
          ),
        );
      }
    } on Object {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _loadComparison(
    int teamId,
    int baselineSeasonId,
    CurrentFormOption option,
    int requestId,
  ) async {
    try {
      final comparison = await _repository.loadComparison(
        teamId,
        seasonId: baselineSeasonId,
        compareTeamId: option.teamId,
        compareSeasonId: option.seasonId,
      );
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _comparison = comparison;
        _isLoading = false;
      });
    } on Object {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  CurrentFormOption? _baselineOption(
    List<CurrentFormOption> options,
    int teamId,
  ) {
    for (final option in options) {
      if (option.teamId == teamId) return option;
    }
    return null;
  }

  void _changeComparison(CurrentFormOption option) {
    final teamId = _teamId;
    final baselineSeasonId = _baselineSeasonId;
    if (teamId == null ||
        baselineSeasonId == null ||
        identical(option, _selectedOption)) {
      return;
    }

    final requestId = ++_loadRequestId;
    final cached = _repository.cachedComparisonFor(
      teamId,
      seasonId: baselineSeasonId,
      compareTeamId: option.teamId,
      compareSeasonId: option.seasonId,
    );
    setState(() {
      _selectedOption = option;
      _comparison = cached;
      _selectedFormRound = null;
      _isLoading = cached == null;
      _loadFailed = false;
    });

    if (cached == null) {
      unawaited(
        _loadComparison(teamId, baselineSeasonId, option, requestId),
      );
    }
  }

  void _retryLoad() {
    final teamId = _teamId;
    if (teamId == null) return;

    final option = _selectedOption;
    final baselineSeasonId = _baselineSeasonId;
    if (option == null || baselineSeasonId == null) {
      setState(_startDefaultLoad);
      return;
    }

    final requestId = ++_loadRequestId;
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    unawaited(
      _loadComparison(teamId, baselineSeasonId, option, requestId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('analysis-current-form-section'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnalysisSectionHeader(
            title: tr(context, 'CURRENT FORM'),
            trailing: _baselineSeasonId != null && _options.isNotEmpty
                ? _buildComparisonPicker()
                : null,
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox.square(
                  key: ValueKey('analysis-current-form-loading'),
                  dimension: 56,
                  child: FootballLoadingIndicator(),
                ),
              ),
            )
          else if (_loadFailed)
            Row(
              key: const ValueKey('analysis-current-form-error'),
              children: [
                Expanded(
                  child: Text(
                    tr(context, 'Unable to load current form'),
                    style: Body2.style,
                  ),
                ),
                TextButton(
                    onPressed: _retryLoad, child: Text(tr(context, 'RETRY'))),
              ],
            )
          else if (_comparison == null || _comparison!.current.points.isEmpty)
            _buildEmptyState()
          else
            _buildChart(),
          if (!_isLoading &&
              !_loadFailed &&
              _comparison != null &&
              _comparison!.current.points.isNotEmpty)
            _buildLegend(),
        ],
      ),
    );
  }

  Future<void> _openComparisonFilter() async {
    final teamId = _teamId;
    if (teamId == null) return;
    final repository = _repository;
    final baselineSeasonId = _baselineSeasonId;
    final initialSeasonName = _selectedOption?.seasonName ??
        _comparison?.current.seasonName ??
        _options.first.seasonName;
    // 팀 목록과 시즌 목록을 분리해야 아직 조회하지 않은 시즌도 선택할 수 있어요.
    final seasons = {
      for (final season in footballCatalog.seasons.value)
        if (TeamPageEligibility.domesticBigFiveCompetitionIds
            .contains(season.competitionId))
          season.name,
      for (final option in _options) option.seasonName,
      initialSeasonName,
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    List<_AnalysisFilterOption<CurrentFormOption>> filterOptions(
      List<CurrentFormOption> options,
    ) =>
        options
            .where((option) =>
                option.teamId != teamId || option.seasonId != baselineSeasonId)
            .map((option) => _AnalysisFilterOption<CurrentFormOption>(
                  value: option,
                  seasonId: option.seasonId,
                  seasonName: option.seasonName,
                  teamId: option.teamId,
                  teamName: teamNameLabel(
                      context, option.teamId, option.teamName ?? ''),
                ))
            .toList();
    final selected = await showModalBottomSheet<CurrentFormOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AnalysisComparisonFilterSheet<CurrentFormOption>(
        options: filterOptions([if (_selectedOption != null) _selectedOption!]),
        initialValue: _selectedOption,
        seasonNames: seasons,
        initialSeasonName: initialSeasonName,
        loadSeasonOptions: (seasonName) async {
          final options =
              await repository.loadAllOptions(teamId, seasonName: seasonName);
          if (!mounted) return [];
          return filterOptions(options);
        },
        optionKey: (option) =>
            'analysis-form-option-${option.teamId}-${option.seasonId}',
        onClearSelection: () => setState(_startDefaultLoad),
      ),
    );
    if (mounted &&
        teamId == _teamId &&
        repository == _repository &&
        selected != null) {
      _changeComparison(selected);
    }
  }

  Widget _buildComparisonPicker() {
    final colors = Theme.of(context).colorScheme;
    final selectedOption = _selectedOption;
    final label = selectedOption == null
        ? tr(context, 'SEASON')
        : compactSeasonLabel(selectedOption.seasonName);

    return InkWell(
      key: const ValueKey('analysis-form-filter'),
      onTap: _isLoading ? null : _openComparisonFilter,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 165,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.of(context).subtleBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(tr(context, label),
                    style: Body2_b.style.copyWith(color: colors.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            Icon(Icons.keyboard_arrow_down, color: colors.onSurface, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      key: const ValueKey('analysis-current-form-empty'),
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.of(context).subtleBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: appCardShadows(context),
      ),
      alignment: Alignment.center,
      child: Text(
        tr(context, 'Current form data is not available yet'),
        style: Body2.style.copyWith(
          color: AppColors.of(context).mutedForeground,
        ),
      ),
    );
  }

  Widget _buildChart() {
    final appColors = AppColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = _comparison!;
    final current = data.current;
    final comparison = data.comparison;
    final showComparison = _selectedOption != null;
    final comparisonColors = _currentFormColors(current, comparison);
    final teamPrimaryColor = comparisonColors.anchor;
    final comparisonColor = comparisonColors.opponent;
    final latestRound = current.points.fold<int>(
      1,
      (latest, point) => math.max(latest, point.roundNo),
    );
    final roundWindow = RoundChartWindow.centeredThrough(latestRound);
    final chartPoints = [
      ...current.points.where((point) => roundWindow.contains(point.roundNo)),
      if (showComparison)
        ...comparison.points
            .where((point) => roundWindow.contains(point.roundNo)),
    ];
    final lowestPoints = chartPoints.fold<int>(
      chartPoints.isEmpty ? 0 : chartPoints.first.cumulativePoints,
      (lowest, point) => math.min(lowest, point.cumulativePoints),
    );
    final highestPoints = chartPoints.fold<int>(
      0,
      (highest, point) => math.max(highest, point.cumulativePoints),
    );
    final minPoints = math.max(0, (lowestPoints ~/ 3) * 3 - 3).toDouble();
    final maxPoints = (((highestPoints / 3).ceil() + 1) * 3).toDouble();
    final availableRounds = current.points
        .where((point) => roundWindow.contains(point.roundNo))
        .map((point) => point.roundNo)
        .toList()
      ..sort();
    final initialRound =
        availableRounds.where((round) => round <= 7).lastOrNull ??
            availableRounds.firstOrNull;
    final selectedRound = availableRounds.contains(_selectedFormRound)
        ? _selectedFormRound
        : initialRound;
    final currentPoint =
        selectedRound == null ? null : _pointAtRound(current, selectedRound);
    final comparisonPoint = !showComparison || selectedRound == null
        ? null
        : _pointAtRound(comparison, selectedRound);
    final gridColor = colorScheme.onSurface.withValues(
      alpha: isDark ? 0.32 : 0.18,
    );

    return Container(
      key: const ValueKey('analysis-current-form-chart-card'),
      height: RoundChartVisuals.cardHeight,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: appColors.cardBackground,
        borderRadius: BorderRadius.circular(RoundChartVisuals.cardRadius),
        boxShadow: appCardShadows(context),
      ),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewportSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                final chartSize = Size(
                  roundWindow.contentWidth(viewportSize.width),
                  viewportSize.height - RoundChartSelectionHandle.height,
                );
                final pointsAxisLabel = tr(context, 'POINTS');
                final pointsAxisLabelStyle = Body2_b.style;
                final insetLineCount = roundChartInsetLineCount(
                  context,
                  chartSize,
                  pointsAxisLabel,
                  pointsAxisLabelStyle,
                );
                var currentTooltipCenterY = currentPoint == null
                    ? null
                    : chartSize.height *
                        (1 -
                            (currentPoint.cumulativePoints - minPoints) /
                                (maxPoints - minPoints));
                var comparisonTooltipCenterY = comparisonPoint == null
                    ? null
                    : chartSize.height *
                        (1 -
                            (comparisonPoint.cumulativePoints - minPoints) /
                                (maxPoints - minPoints));
                if (currentPoint != null &&
                    comparisonPoint != null &&
                    currentTooltipCenterY != null &&
                    comparisonTooltipCenterY != null) {
                  const tooltipHeight = 32.0;
                  const tooltipGap = 8.0;
                  const minimumCenterSeparation = tooltipHeight + tooltipGap;
                  final distance =
                      (currentTooltipCenterY - comparisonTooltipCenterY).abs();
                  if (distance < minimumCenterSeparation) {
                    final midpoint =
                        (currentTooltipCenterY + comparisonTooltipCenterY) / 2;
                    var upperCenter = midpoint - minimumCenterSeparation / 2;
                    var lowerCenter = midpoint + minimumCenterSeparation / 2;
                    const minimumCenter = tooltipHeight / 2;
                    final maximumCenter = chartSize.height - minimumCenter;
                    if (upperCenter < minimumCenter) {
                      lowerCenter += minimumCenter - upperCenter;
                      upperCenter = minimumCenter;
                    }
                    if (lowerCenter > maximumCenter) {
                      upperCenter -= lowerCenter - maximumCenter;
                      lowerCenter = maximumCenter;
                    }
                    if (currentPoint.cumulativePoints >
                        comparisonPoint.cumulativePoints) {
                      currentTooltipCenterY = upperCenter;
                      comparisonTooltipCenterY = lowerCenter;
                    } else if (currentPoint.cumulativePoints <
                        comparisonPoint.cumulativePoints) {
                      currentTooltipCenterY = lowerCenter;
                      comparisonTooltipCenterY = upperCenter;
                    } else {
                      comparisonTooltipCenterY = upperCenter;
                      currentTooltipCenterY = lowerCenter;
                    }
                  }
                }
                return Stack(
                  children: [
                    Positioned.fill(
                      bottom: RoundChartSelectionHandle.height,
                      child: CustomPaint(
                        key: const ValueKey('analysis-current-form-grid'),
                        painter: RoundChartGridPainter(
                          color: gridColor,
                          insetLineCount: insetLineCount,
                        ),
                      ),
                    ),
                    RoundChartViewport(
                      key: const ValueKey('analysis-current-form-viewport'),
                      roundWindow: roundWindow,
                      viewportSize: viewportSize,
                      selectedRound: selectedRound,
                      selectableRounds: availableRounds,
                      onRoundChanged: (round) =>
                          setState(() => _selectedFormRound = round),
                      builder: (context, _) => Stack(
                        key: const ValueKey('analysis-current-form-chart'),
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: LineChart(
                                LineChartData(
                                  minX: roundWindow.firstRound.toDouble(),
                                  maxX: roundWindow.lastRound.toDouble(),
                                  minY: minPoints,
                                  maxY: maxPoints,
                                  gridData: const FlGridData(show: false),
                                  borderData: FlBorderData(show: false),
                                  titlesData: const FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    topTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                  lineTouchData:
                                      const LineTouchData(enabled: false),
                                  lineBarsData: [
                                    _formLine(
                                        current, teamPrimaryColor, roundWindow),
                                    if (showComparison)
                                      _formLine(comparison, comparisonColor,
                                          roundWindow),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (selectedRound != null)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  key: const ValueKey(
                                      'analysis-current-form-selection-guide'),
                                  painter: _CurrentFormSelectionPainter(
                                    round: selectedRound,
                                    roundWindow: roundWindow,
                                    minPoints: minPoints,
                                    maxPoints: maxPoints,
                                    currentPoints: currentPoint
                                        ?.cumulativePoints
                                        .toDouble(),
                                    comparisonPoints: comparisonPoint
                                        ?.cumulativePoints
                                        .toDouble(),
                                    currentColor: teamPrimaryColor,
                                    comparisonColor: comparisonColor,
                                  ),
                                ),
                              ),
                            ),
                          if (selectedRound != null && comparisonPoint != null)
                            _formTooltip(
                              chartSize: chartSize,
                              viewportWidth: viewportSize.width,
                              round: selectedRound,
                              points: comparisonPoint.cumulativePoints,
                              roundWindow: roundWindow,
                              minPoints: minPoints,
                              maxPoints: maxPoints,
                              verticalCenter: comparisonTooltipCenterY,
                              placeBefore: true,
                              isDark: isDark,
                              key: const ValueKey(
                                'analysis-current-form-comparison-tooltip',
                              ),
                            ),
                          if (selectedRound != null && currentPoint != null)
                            _formTooltip(
                              chartSize: chartSize,
                              viewportWidth: viewportSize.width,
                              round: selectedRound,
                              points: currentPoint.cumulativePoints,
                              roundWindow: roundWindow,
                              minPoints: minPoints,
                              maxPoints: maxPoints,
                              verticalCenter: currentTooltipCenterY,
                              placeBefore: false,
                              isDark: isDark,
                              key: const ValueKey(
                                'analysis-current-form-current-tooltip',
                              ),
                            ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: RotatedBox(
                        key: const ValueKey(
                            'analysis-current-form-points-label'),
                        quarterTurns: 1,
                        child:
                            Text(pointsAxisLabel, style: pointsAxisLabelStyle),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              tr(context, 'ROUND'),
              key: const ValueKey('analysis-current-form-round-label'),
              style: Body2_b.style,
            ),
          ),
        ],
      ),
    );
  }

  CurrentFormPoint? _pointAtRound(CurrentFormSeries series, int round) {
    for (final point in series.points) {
      if (point.roundNo == round) return point;
    }
    return null;
  }

  Widget _formTooltip({
    required Size chartSize,
    required double viewportWidth,
    required int round,
    required int points,
    required RoundChartWindow roundWindow,
    required double minPoints,
    required double maxPoints,
    required double? verticalCenter,
    required bool placeBefore,
    required bool isDark,
    required Key key,
  }) {
    const pointRadius = 4.0;
    const pointToTooltipGap = 4.0;
    const anchorGap = pointRadius + pointToTooltipGap;
    const contentGap = 8.0;
    const tooltipPadding = 8.0;
    final tooltipTextStyle = Eyebrow.style.copyWith(
      fontWeight: FontWeight.w700,
    );
    final roundLabel = tr(context, 'Round {round}', {'round': round});
    final pointsLabel = tr(context, '{points} Pts', {'points': points});
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final roundPainter = TextPainter(
      text: TextSpan(text: roundLabel, style: tooltipTextStyle),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final pointsPainter = TextPainter(
      text: TextSpan(text: pointsLabel, style: tooltipTextStyle),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final tooltipWidth = math.min(
      viewportWidth,
      roundPainter.width +
          pointsPainter.width +
          contentGap +
          tooltipPadding * 2 +
          4,
    );
    final tooltipHeight = math.max(roundPainter.height, pointsPainter.height) +
        tooltipPadding * 2 +
        2;
    final anchorY =
        chartSize.height * (1 - (points - minPoints) / (maxPoints - minPoints));
    final left = roundChartTooltipLeft(
      roundWindow: roundWindow,
      round: round,
      viewportWidth: viewportWidth,
      tooltipWidth: tooltipWidth,
      gap: anchorGap,
      preferLeft: placeBefore,
    );
    final top = ((verticalCenter ?? anchorY) - tooltipHeight / 2)
        .clamp(0.0, math.max(0.0, chartSize.height - tooltipHeight))
        .toDouble();
    final foreground = isDark ? AppPalette.white : AppPalette.black;

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      height: tooltipHeight,
      child: Container(
        key: key,
        padding: const EdgeInsets.all(tooltipPadding),
        decoration: BoxDecoration(
          color: isDark ? AppPalette.black : AppPalette.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: isDark
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x1F090A0A),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Text(
              roundLabel,
              maxLines: 1,
              softWrap: false,
              style: tooltipTextStyle.copyWith(
                color: foreground.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(width: contentGap),
            Flexible(
              child: Text(
                pointsLabel,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: tooltipTextStyle.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _formLine(
    CurrentFormSeries series,
    Color color,
    RoundChartWindow roundWindow,
  ) {
    return LineChartBarData(
      spots: series.points
          .where((point) => roundWindow.contains(point.roundNo))
          .map(
            (point) => FlSpot(
              point.roundNo.toDouble(),
              point.cumulativePoints.toDouble(),
            ),
          )
          .toList(),
      color: color,
      barWidth: 2,
      isCurved: false,
      dotData: const FlDotData(show: false),
    );
  }

  TeamComparisonColors _currentFormColors(
    CurrentFormSeries current,
    CurrentFormSeries comparison,
  ) {
    final currentTeam = teamRepository.findById(current.teamId);
    final comparisonTeam = teamRepository.findById(comparison.teamId);
    final currentName = current.teamName ?? currentTeam?.name;
    final comparisonName = comparison.teamName ?? comparisonTeam?.name;
    final missingColor = AppColors.of(context).mutedForeground;
    final currentMissing = teamColorPaletteForName(currentName ?? '') == null;
    final comparisonMissing =
        teamColorPaletteForName(comparisonName ?? '') == null;
    final resolved = TeamComparisonColorResolver.resolve(
      anchorTeamName: currentName,
      anchorPrimaryFallback: currentMissing
          ? missingColor
          : currentTeam == null
              ? _analysisTeamPrimaryColor(widget.team)
              : Color(currentTeam.primaryColor),
      opponentTeamName: comparisonName,
      opponentPrimaryFallback: comparisonMissing
          ? missingColor
          : comparisonTeam == null
              ? null
              : Color(comparisonTeam.primaryColor),
      background: AppColors.of(context).cardBackground,
    );
    return TeamComparisonColors(
      anchor: currentMissing ? missingColor : resolved.anchor,
      opponent: comparisonMissing ? missingColor : resolved.opponent,
    );
  }

  Widget _buildLegend() {
    final current = _comparison!.current;
    final comparison = _comparison!.comparison;
    final showComparison = _selectedOption != null;
    final comparisonColors = _currentFormColors(current, comparison);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        key: const ValueKey('analysis-current-form-legend'),
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 20,
          runSpacing: 8,
          children: [
            _legendItem(comparisonColors.anchor, tr(context, 'MY TEAM')),
            if (showComparison)
              _legendItem(
                comparisonColors.opponent,
                '${compactSeasonLabel(comparison.seasonName)} '
                '${(comparison.teamShortCode ?? teamNameLabel(context, comparison.teamId, comparison.teamName ?? '')).toUpperCase()}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
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
