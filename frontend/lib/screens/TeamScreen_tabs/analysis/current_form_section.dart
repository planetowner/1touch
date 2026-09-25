part of '../Analysis.dart';

class CurrentFormSection extends StatefulWidget {
  final Map<String, dynamic>? team;
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

  int? get _teamId => widget.team?['id'] as int?;

  @override
  void initState() {
    super.initState();
    _startDefaultLoad();
  }

  @override
  void didUpdateWidget(CurrentFormSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_teamId != oldWidget.team?['id'] ||
        widget.repository != oldWidget.repository) {
      _startDefaultLoad();
    }
  }

  void _startDefaultLoad() {
    final teamId = _teamId;
    final requestId = ++_loadRequestId;
    final cachedOptions =
        teamId == null ? null : _repository.cachedOptionsFor(teamId);
    final baselineOption = teamId == null || cachedOptions == null
        ? null
        : _baselineOption(cachedOptions, teamId);
    final selectedOption = teamId == null || cachedOptions == null
        ? null
        : _defaultOption(cachedOptions, teamId);
    final cachedComparison = selectedOption == null
        ? null
        : _repository.cachedComparisonFor(
            teamId!,
            seasonId: baselineOption?.seasonId,
            compareTeamId: selectedOption.teamId,
            compareSeasonId: selectedOption.seasonId,
          );

    _options = cachedOptions ?? const [];
    _baselineSeasonId = baselineOption?.seasonId;
    _selectedOption = selectedOption;
    _comparison = cachedComparison;
    _selectedFormRound = null;
    _loadFailed = false;
    _isLoading = teamId != null &&
        (cachedOptions == null ||
            (baselineOption != null &&
                selectedOption != null &&
                cachedComparison == null));

    if (teamId == null) return;
    if (cachedOptions == null) {
      unawaited(_loadOptions(teamId, requestId));
    } else if (baselineOption != null &&
        selectedOption != null &&
        cachedComparison == null) {
      unawaited(
        _loadComparison(
          teamId,
          baselineOption.seasonId,
          selectedOption,
          requestId,
        ),
      );
    }
  }

  Future<void> _loadOptions(int teamId, int requestId) async {
    try {
      final options = await _repository.loadOptions(teamId);
      if (!mounted || requestId != _loadRequestId) return;

      final baselineOption = _baselineOption(options, teamId);
      final selectedOption = _defaultOption(options, teamId);
      final cachedComparison = baselineOption == null || selectedOption == null
          ? null
          : _repository.cachedComparisonFor(
              teamId,
              seasonId: baselineOption.seasonId,
              compareTeamId: selectedOption.teamId,
              compareSeasonId: selectedOption.seasonId,
            );
      setState(() {
        _options = options;
        _baselineSeasonId = baselineOption?.seasonId;
        _selectedOption = selectedOption;
        _comparison = cachedComparison;
        _isLoading = baselineOption != null &&
            selectedOption != null &&
            cachedComparison == null;
      });

      if (baselineOption != null &&
          selectedOption != null &&
          cachedComparison == null) {
        unawaited(
          _loadComparison(
            teamId,
            baselineOption.seasonId,
            selectedOption,
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

  CurrentFormOption? _defaultOption(
    List<CurrentFormOption> options,
    int teamId,
  ) {
    final sameTeam =
        options.where((option) => option.teamId == teamId).toList();
    // Backend options are newest-first, so the second same-team row is the
    // previous season while the full list remains available for comparison.
    if (sameTeam.length > 1) return sameTeam[1];
    if (sameTeam.isNotEmpty) return sameTeam.first;
    return null;
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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
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
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
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

  Widget _buildComparisonPicker() {
    final colors = Theme.of(context).colorScheme;
    final selectedOption = _selectedOption;
    final label = selectedOption == null
        ? tr(context, 'SEASON')
        : _compactSeasonLabel(selectedOption.seasonName);

    return AppDropdown<CurrentFormOption>(
      key: const ValueKey('analysis-form-filter'),
      value: selectedOption,
      selectedLabel: tr(context, label),
      minWidth: 86,
      matchMenuWidth: true,
      backgroundColor: AppColors.of(context).subtleBackground,
      foregroundColor: colors.onSurface,
      textStyle: Body2_b.style,
      enabled: !_isLoading,
      onChanged: _changeComparison,
      options: _options
          .map(
            (option) => AppDropdownOption<CurrentFormOption>(
              value: option,
              label:
                  '${_compactSeasonLabel(option.seasonName)} · ${(option.teamShortCode ?? teamNameLabel(context, option.teamId, option.teamName ?? '')).toUpperCase()}',
              optionKey: ValueKey(
                'analysis-form-option-${option.teamId}-${option.seasonId}',
              ),
            ),
          )
          .toList(),
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
    final currentTeam = teamRepository.findById(current.teamId);
    final comparisonTeam = teamRepository.findById(comparison.teamId);
    final comparisonColors = TeamComparisonColorResolver.resolve(
      anchorTeamName: current.teamName ?? currentTeam?.name,
      anchorPrimaryFallback: currentTeam == null
          ? _analysisTeamPrimaryColor(widget.team)
          : Color(currentTeam.primaryColor),
      opponentTeamName: comparison.teamName ?? comparisonTeam?.name,
      opponentPrimaryFallback:
          comparisonTeam == null ? null : Color(comparisonTeam.primaryColor),
      background: appColors.cardBackground,
    );
    final teamPrimaryColor = comparisonColors.anchor;
    final comparisonColor = comparisonColors.opponent;
    final maxRound = math.max(2, data.maxRound);
    final maxPoints = math.max(5, ((data.maxPoints + 4) ~/ 5) * 5).toDouble();
    final selectedRound = _selectedFormRound;
    final currentPoint =
        selectedRound == null ? null : _pointAtRound(current, selectedRound);
    final comparisonPoint =
        selectedRound == null ? null : _pointAtRound(comparison, selectedRound);
    final gridColor = colorScheme.onSurface.withValues(
      alpha: isDark ? 0.32 : 0.18,
    );

    return Container(
      key: const ValueKey('analysis-current-form-chart-card'),
      height: 346,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: appColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: appCardShadows(context),
      ),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chartSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return GestureDetector(
                  key: const ValueKey('analysis-current-form-chart'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => _selectFormRound(
                    details.localPosition.dx,
                    chartSize.width,
                    maxRound,
                    current,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CurrentFormGridPainter(
                            color: gridColor,
                            topLineInset: 68,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: LineChart(
                            LineChartData(
                              minX: 0,
                              maxX: maxRound.toDouble(),
                              minY: 0,
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
                                _formLine(current, teamPrimaryColor),
                                _formLine(comparison, comparisonColor),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (selectedRound != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _CurrentFormSelectionPainter(
                                round: selectedRound,
                                maxRound: maxRound,
                                maxPoints: maxPoints,
                                currentPoints:
                                    currentPoint?.cumulativePoints.toDouble(),
                                comparisonPoints: comparisonPoint
                                    ?.cumulativePoints
                                    .toDouble(),
                                currentColor: teamPrimaryColor,
                                comparisonColor: comparisonColor,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 4,
                        top: 0,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child:
                              Text(tr(context, 'POINTS'), style: Body2_b.style),
                        ),
                      ),
                      if (selectedRound != null && comparisonPoint != null)
                        _formTooltip(
                          chartSize: chartSize,
                          round: selectedRound,
                          points: comparisonPoint.cumulativePoints,
                          maxRound: maxRound,
                          maxPoints: maxPoints,
                          placeBefore: true,
                          isDark: isDark,
                          key: const ValueKey(
                            'analysis-current-form-comparison-tooltip',
                          ),
                        ),
                      if (selectedRound != null && currentPoint != null)
                        _formTooltip(
                          chartSize: chartSize,
                          round: selectedRound,
                          points: currentPoint.cumulativePoints,
                          maxRound: maxRound,
                          maxPoints: maxPoints,
                          placeBefore: false,
                          isDark: isDark,
                          key: const ValueKey(
                            'analysis-current-form-current-tooltip',
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(tr(context, 'ROUND'), style: Body2_b.style),
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

  void _selectFormRound(
    double localX,
    double chartWidth,
    int maxRound,
    CurrentFormSeries current,
  ) {
    if (chartWidth <= 0 || current.points.isEmpty) return;

    final targetRound = (localX / chartWidth * maxRound).clamp(0, maxRound);
    var nearest = current.points.first;
    for (final point in current.points.skip(1)) {
      if ((point.roundNo - targetRound).abs() <
          (nearest.roundNo - targetRound).abs()) {
        nearest = point;
      }
    }
    if (_selectedFormRound == nearest.roundNo) return;
    setState(() => _selectedFormRound = nearest.roundNo);
  }

  Widget _formTooltip({
    required Size chartSize,
    required int round,
    required int points,
    required int maxRound,
    required double maxPoints,
    required bool placeBefore,
    required bool isDark,
    required Key key,
  }) {
    const tooltipWidth = 128.0;
    const tooltipHeight = 40.0;
    const gap = 10.0;
    final anchorX = chartSize.width * round / maxRound;
    final anchorY = chartSize.height * (1 - points / maxPoints);
    final left = (placeBefore ? anchorX - tooltipWidth - gap : anchorX + gap)
        .clamp(0.0, math.max(0.0, chartSize.width - tooltipWidth))
        .toDouble();
    final top = (placeBefore ? anchorY - tooltipHeight - gap : anchorY + gap)
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
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? AppPalette.black : AppPalette.white,
          borderRadius: BorderRadius.circular(6),
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
            Expanded(
              flex: 3,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  tr(context, 'Round {round}', {'round': round}),
                  maxLines: 1,
                  style: Body2_b.style.copyWith(
                    color: foreground.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  tr(context, '{points} Pts', {'points': points}),
                  maxLines: 1,
                  style: Body2_b.style.copyWith(color: foreground),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _formLine(CurrentFormSeries series, Color color) {
    return LineChartBarData(
      spots: series.points
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

  Widget _buildLegend() {
    final appColors = AppColors.of(context);
    final current = _comparison!.current;
    final comparison = _comparison!.comparison;
    final currentTeam = teamRepository.findById(current.teamId);
    final comparisonTeam = teamRepository.findById(comparison.teamId);
    final comparisonColors = TeamComparisonColorResolver.resolve(
      anchorTeamName: current.teamName ?? currentTeam?.name,
      anchorPrimaryFallback: currentTeam == null
          ? _analysisTeamPrimaryColor(widget.team)
          : Color(currentTeam.primaryColor),
      opponentTeamName: comparison.teamName ?? comparisonTeam?.name,
      opponentPrimaryFallback:
          comparisonTeam == null ? null : Color(comparisonTeam.primaryColor),
      background: appColors.cardBackground,
    );
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
            _legendItem(comparisonColors.anchor, tr(context, 'CURRENT')),
            _legendItem(
              comparisonColors.opponent,
              '${_compactSeasonLabel(comparison.seasonName)} '
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
