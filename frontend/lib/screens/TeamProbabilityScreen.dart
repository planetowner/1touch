import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/app_snack_bar.dart';
import 'package:onetouch/core/app_info_button.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/number_display.dart';
import 'package:onetouch/core/round_chart_window.dart';
import 'package:onetouch/core/round_chart_visuals.dart';
import 'package:onetouch/core/interactive_back_page.dart';
import 'package:onetouch/core/probability_display.dart';
import 'package:onetouch/features/team/probability/probability_number.dart';
import 'package:onetouch/features/team/team_standing_label.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/team_probability/team_probability_repository.dart';
import 'package:onetouch/data/team_probability/team_probability_repository_provider.dart';
import 'package:onetouch/data/fixtures/fixture_repository.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart'
    as fixture_providers;
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/fixture_labels.dart';
import 'package:onetouch/models/team_probability.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/screens/team_probability_what_if_screen.dart';

const _fallbackProbabilityColor = Color(0xFFD82457);

class TeamProbabilityScreen extends StatefulWidget {
  const TeamProbabilityScreen({
    super.key,
    required this.teamId,
    required this.event,
    this.initialSnapshot,
    this.repository,
    this.fixtureRepository,
    this.teamPrimaryColor,
  });

  final int teamId;
  final String event;
  final TeamProbabilitySnapshot? initialSnapshot;
  final TeamProbabilityRepository? repository;
  final FixtureRepository? fixtureRepository;
  final Color? teamPrimaryColor;

  @override
  State<TeamProbabilityScreen> createState() => _TeamProbabilityScreenState();
}

class _TeamProbabilityScreenState extends State<TeamProbabilityScreen> {
  TeamProbabilitySnapshot? _snapshot;
  Object? _error;
  bool _isLoading = false;

  TeamProbabilityRepository get _repository =>
      widget.repository ?? teamProbabilityRepository;

  FixtureRepository get _fixtureRepository =>
      widget.fixtureRepository ?? fixture_providers.fixtureRepository;

  @override
  void initState() {
    super.initState();
    _snapshot =
        widget.initialSnapshot ?? _repository.cachedForTeam(widget.teamId);
    // 유럽 상세는 저장된 응답이 있어도 진입할 때 최신 데이터를 확인해요.
    final isEuropean = _isEuropeanTitleEvent(widget.event);
    if (_snapshot == null || isEuropean) {
      _load(forceRefresh: isEuropean);
    }
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      final snapshot = await _repository.loadForTeam(
        widget.teamId,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('team-probability-detail-screen'),
      backgroundColor: mainPageBackground(context),
      body: _buildBody(context),
    );
  }

  Color _teamPrimaryColor() {
    final repositoryTeam = teamRepository.findById(widget.teamId);
    return widget.teamPrimaryColor ??
        (repositoryTeam == null
            ? _fallbackProbabilityColor
            : Color(repositoryTeam.primaryColor));
  }

  Widget _buildWhatIfButton(
    BuildContext context,
    TeamProbabilitySnapshot snapshot,
    Color teamPrimaryColor,
  ) {
    return ColoredBox(
      color: mainPageBackground(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton(
            key: const ValueKey('probability-what-if-button'),
            onPressed: () => _openWhatIf(
              context,
              snapshot,
              teamPrimaryColor,
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Theme.of(context).colorScheme.onSurface,
              foregroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(trUpper(context, 'What if?'), style: Body2_b.style),
          ),
        ),
      ),
    );
  }

  Future<void> _openWhatIf(
    BuildContext context,
    TeamProbabilitySnapshot snapshot,
    Color teamPrimaryColor,
  ) async {
    final isEuropean = _isEuropeanTitleEvent(widget.event);
    final whatIf = snapshot.whatIf;
    if (!isEuropean && whatIf == null) {
      showAppSnackBar(context, tr(context, 'What-if data is unavailable.'));
      return;
    }
    Fixture? europeanFixture;
    if (isEuropean) {
      final competitionId = snapshot.cards
          .where((card) => card.event == widget.event)
          .firstOrNull
          ?.competitionId;
      if (competitionId != null) {
        try {
          final upcoming = await _fixtureRepository.loadForTeam(
            snapshot.teamId,
            status: FixtureStatus.upcoming,
            limit: 200,
          );
          final matching = upcoming
              .where((fixture) =>
                  fixture.competitionId == competitionId &&
                  fixture.kickoff != null)
              .toList()
            ..sort((a, b) => a.kickoff!.compareTo(b.kickoff!));
          final predictedFixtureId = snapshot.europeanTitle?.whatIf?.fixtureId;
          europeanFixture = predictedFixtureId == null
              ? matching.firstOrNull
              : matching
                      .where(
                          (fixture) => fixture.fixtureId == predictedFixtureId)
                      .firstOrNull ??
                  matching.firstOrNull;
        } on Object {
          // 일정 조회가 실패해도 리그 경기를 대신 표시하지 않아요.
        }
      }
      if (!context.mounted) return;
      if (europeanFixture == null) {
        showAppSnackBar(context, tr(context, 'What-if data is unavailable.'));
        return;
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TeamProbabilityWhatIfScreen(
          snapshot: snapshot,
          event: widget.event,
          teamPrimaryColor: teamPrimaryColor,
          europeanFixture: europeanFixture,
          homeTeam: teamRepository.findById(
              europeanFixture?.homeTeamId ?? whatIf!.fixture.homeTeamId),
          awayTeam: teamRepository.findById(
              europeanFixture?.awayTeamId ?? whatIf!.fixture.awayTeamId),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final snapshot = _snapshot;
    if (_isLoading &&
        (snapshot == null || _isEuropeanTitleEvent(widget.event))) {
      return const Center(child: FootballLoadingIndicator());
    }
    if (_error != null &&
        (snapshot == null || _isEuropeanTitleEvent(widget.event))) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr(context, 'Prediction unavailable.'),
                  textAlign: TextAlign.center, style: Body1.style),
              const SizedBox(height: 16),
              TextButton(
                key: const ValueKey('team-probability-detail-retry'),
                onPressed: () => _load(
                  forceRefresh: _isEuropeanTitleEvent(widget.event),
                ),
                child: Text(tr(context, 'Retry probability')),
              ),
            ],
          ),
        ),
      );
    }
    if (snapshot == null) {
      return const Center(child: FootballLoadingIndicator());
    }

    final card = _findCard(snapshot.cards, widget.event);
    if (card == null) {
      return const Center(child: Text('아직 준비중이에요ㅠㅠ'));
    }

    final contentTop = appBarContentTop(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? const [Color(0xFF282929), Color(0x00282929)]
        : const [Color(0x333D3D3D), Color(0x003D3D3D)];
    final teamPrimaryColor = _teamPrimaryColor();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          key: const ValueKey('team-probability-gradient'),
          height: contentTop + 211,
          padding: EdgeInsets.fromLTRB(24, contentTop, 24, 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: gradientColors,
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 32,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        key: const ValueKey('probability-back-button'),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          fixedSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          alignment: Alignment.centerLeft,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 24),
                      ),
                    ),
                    Text(tr(context, 'Probability'), style: Body1.style),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        key: const ValueKey('probability-search-button'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        onPressed: () => context.push('/search'),
                        icon: const Icon(Icons.search, size: 32),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: _ProbabilityHero(
                    card: card,
                    color: teamPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _SectionTitle(tr(context, 'PROBABILITY HISTORY')),
                    ),
                  ),
                  if (_isEuropeanTitleEvent(widget.event)) ...[
                    const SizedBox(width: 4),
                    const AppInfoButton(
                      key: ValueKey('european-probability-history-info'),
                      title: 'PROBABILITY HISTORY',
                      message:
                          "Tracks how your team's chance of winning the competition changes over time. Winning a first leg raises it, and once the tie is decided, that probability carries into the next round",
                      layoutSize: 14,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              InteractiveBackGestureExclusion(
                // 기록은 이미 지나온 단계의 우승 확률이에요. 미래 단계의 진출 확률과 섞지 않아요.
                child: _isEuropeanTitleEvent(widget.event)
                    ? snapshot.europeanTitle?.history.isNotEmpty == true
                        ? _EuropeanStageHistoryCard(
                            history: snapshot.europeanTitle!.history,
                            color: teamPrimaryColor,
                          )
                        : const _EuropeanUnavailableCard()
                    : _ProbabilityHistoryCard(
                        history: snapshot.history,
                        event: widget.event,
                        maximumRound: (snapshot.maximumPoints / 3).round(),
                        color: teamPrimaryColor,
                      ),
              ),
              if (_isEuropeanTitleEvent(widget.event)) ...[
                const SizedBox(height: 48),
                _SectionTitle(tr(context, 'HOW FAR WILL THEY GO')),
                const SizedBox(height: 16),
                if (snapshot.europeanTitle?.stageProbabilities.isNotEmpty ==
                    true)
                  _EuropeanProgression(
                    stages: snapshot.europeanTitle!.stageProbabilities,
                    color: teamPrimaryColor,
                  )
                else
                  Text(tr(context, 'Not ready yet'), style: Body1.style),
              ],
              if (!_isEuropeanTitleEvent(widget.event)) ...[
                const SizedBox(height: 48),
                _SectionTitle(tr(context, 'PROJECTED FINAL POSITION')),
                const SizedBox(height: 16),
                _ProjectedPositions(
                  positions: snapshot.positions,
                  color: teamPrimaryColor,
                  showLast: widget.event == 'direct_relegation' ||
                      widget.event == 'relegation_playoff',
                ),
              ],
              const SizedBox(height: 48),
              if (_isEuropeanTitleEvent(widget.event)) ...[
                _SectionTitle(tr(context, 'TITLE CONTENDERS')),
                const SizedBox(height: 16),
                if (snapshot.europeanTitle?.titleContenders.teams.isNotEmpty ==
                    true)
                  _TitleContendersCard(
                    teamId: snapshot.teamId,
                    contenders: snapshot.europeanTitle!.titleContenders,
                    color: teamPrimaryColor,
                  )
                else
                  const _EuropeanUnavailableCard(),
              ] else ...[
                _SectionTitle(tr(context, 'PROJECTED POINTS')),
                const SizedBox(height: 16),
                _ProjectedPointsCard(
                  projectedPoints: snapshot.projectedPoints,
                  maximumPoints: snapshot.maximumPoints,
                  color: teamPrimaryColor,
                ),
              ],
            ],
          ),
        ),
        _buildWhatIfButton(context, snapshot, teamPrimaryColor),
      ],
    );
  }
}

class _ProbabilityHero extends StatelessWidget {
  const _ProbabilityHero({required this.card, required this.color});

  final TeamProbabilityCard card;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final delta = card.changePercentagePoints;
    final showDelta = delta != null && delta != 0;
    final isPositive = (delta ?? 0) > 0;
    return SizedBox(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ProbabilityNumber(
                        card: card, keyPrefix: 'probability-detail'),
                    if (showDelta) ...[
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: Icon(
                          key: const ValueKey('probability-detail-delta-icon'),
                          isPositive
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          color: color,
                          size: 24,
                        ),
                      ),
                      Text(
                        '${formatDisplayNumber(delta.abs(), trimTrailingZeros: true)}%',
                        style: Heading5.style,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 160,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(_eventIcon(card.event), size: 56),
                const SizedBox(height: 4),
                SizedBox(
                  width: 160,
                  height: 39,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      tr(context, probabilityEventTitle(card.event)),
                      key: const ValueKey('probability-event-title'),
                      maxLines:
                          Localizations.localeOf(context).languageCode == 'ko'
                              ? 1
                              : 2,
                      softWrap: false,
                      textAlign: TextAlign.right,
                      style: Body1.style,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProbabilityHistoryCard extends StatefulWidget {
  const _ProbabilityHistoryCard({
    required this.history,
    required this.event,
    required this.maximumRound,
    required this.color,
  });

  final List<TeamProbabilityHistoryPoint> history;
  final String event;
  final int maximumRound;
  final Color color;

  @override
  State<_ProbabilityHistoryCard> createState() =>
      _ProbabilityHistoryCardState();
}

class _ProbabilityHistoryCardState extends State<_ProbabilityHistoryCard> {
  int? _selectedRound;

  @override
  void didUpdateWidget(covariant _ProbabilityHistoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event != widget.event ||
        oldWidget.history != widget.history ||
        oldWidget.maximumRound != widget.maximumRound) {
      _selectedRound = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = <({int played, double probability})>[];
    for (final item in widget.history) {
      final eventValue = item.event(widget.event);
      if (eventValue != null) {
        points.add((played: item.played, probability: eventValue.probability));
      }
    }
    if (points.isEmpty) return const _UnavailableCard();
    points.sort((a, b) => a.played.compareTo(b.played));

    final colors = AppColors.of(context);
    final latestRound =
        points.map((point) => point.played).reduce((a, b) => a > b ? a : b);
    final roundWindow = RoundChartWindow.centeredThrough(latestRound);
    final visiblePoints =
        points.where((point) => roundWindow.contains(point.played)).toList();
    final spots = [
      for (final point in visiblePoints)
        FlSpot(point.played.toDouble(), point.probability * 100),
    ];
    final highestProbability =
        spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    // 0%를 기준선으로 두고 표시할 최고 확률을 20% 단위로 올려요.
    final maxY = (highestProbability / 20).ceil().clamp(1, 5) * 20;
    final gridColor = Theme.of(context).colorScheme.onSurface.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.32 : 0.18,
        );
    final initialPoint = visiblePoints.last;
    final selectedPoint = visiblePoints
            .where((point) => point.played == _selectedRound)
            .firstOrNull ??
        initialPoint;

    return Container(
      key: const ValueKey('probability-history-card'),
      height: RoundChartVisuals.cardHeight,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(RoundChartVisuals.cardRadius),
        boxShadow: appCardShadows(context),
      ),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final plotViewportSize = constraints.biggest;
                final axisLabelStyle = Body2_b.style;
                const labelPadding = 4.0;
                final topLabel = '$maxY%';
                final middleLabel = '${maxY ~/ 2}%';
                double labelHeight(String label) {
                  final painter = TextPainter(
                    text: TextSpan(text: label, style: axisLabelStyle),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                    maxLines: 1,
                  )..layout();
                  return painter.width + labelPadding * 2;
                }

                final plotHeight =
                    plotViewportSize.height - RoundChartSelectionHandle.height;
                final topLabelHeight = labelHeight(topLabel);
                final middleLabelHeight = labelHeight(middleLabel);
                final insetLineIndices = <int>{
                  for (var index = 0;
                      index < RoundChartVisuals.horizontalLineCount;
                      index++)
                    if (plotHeight *
                                index /
                                (RoundChartVisuals.horizontalLineCount - 1) <
                            topLabelHeight ||
                        (plotHeight *
                                        index /
                                        (RoundChartVisuals.horizontalLineCount -
                                            1) -
                                    plotHeight / 2)
                                .abs() <
                            middleLabelHeight / 2)
                      index,
                };
                Widget axisLabel(String label, Key key) => ColoredBox(
                      color: colors.cardBackground,
                      child: Padding(
                        padding: const EdgeInsets.all(labelPadding),
                        child: RotatedBox(
                          key: key,
                          quarterTurns: 1,
                          child: Text(label, style: axisLabelStyle),
                        ),
                      ),
                    );
                // 초기 라운드에서는 더 왼쪽으로 스크롤할 수 없으므로 선택점이
                // 뒤로 갈수록 축 라벨에 가린 눈금선의 시작점을 드러내요.
                final revealStart =
                    math.min(latestRound, RoundChartWindow.centerIntervalCount);
                final revealOffset = _selectedRound == null || revealStart == 0
                    ? 0.0
                    : RoundChartVisuals.axisLineInset *
                        ((revealStart - selectedPoint.played) / revealStart)
                            .clamp(0.0, 1.0);
                return Stack(
                  children: [
                    Positioned.fill(
                      bottom: RoundChartSelectionHandle.height,
                      child: CustomPaint(
                        key: const ValueKey('probability-history-grid'),
                        painter: RoundChartGridPainter(
                          color: gridColor,
                          insetLineCount: 0,
                          // Clear every line crossing either rotated label.
                          insetLineIndices: insetLineIndices,
                        ),
                      ),
                    ),
                    // Clip the line's stroke at the fixed plot edge while the
                    // chart slides; the label mask below covers its gutter.
                    ClipRect(
                      key: const ValueKey('probability-history-plot-clip'),
                      child: AnimatedSlide(
                        key: const ValueKey('probability-history-reveal-slide'),
                        offset:
                            Offset(revealOffset / plotViewportSize.width, 0),
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOutCubic,
                        child: RoundChartViewport(
                          key: const ValueKey('probability-history-viewport'),
                          roundWindow: roundWindow,
                          viewportSize: plotViewportSize,
                          selectedRound: selectedPoint.played,
                          selectableRounds: [
                            for (final point in visiblePoints) point.played
                          ],
                          onRoundChanged: (round) =>
                              setState(() => _selectedRound = round),
                          builder: (context, contentSize) => Stack(
                            key: const ValueKey('probability-history-chart'),
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: LineChart(
                                  key: const ValueKey(
                                      'probability-history-line-chart'),
                                  LineChartData(
                                    minX: roundWindow.firstRound.toDouble(),
                                    maxX: roundWindow.lastRound.toDouble(),
                                    minY: 0,
                                    maxY: maxY.toDouble(),
                                    gridData: const FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                    titlesData: const FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      rightTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      topTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                    ),
                                    lineTouchData:
                                        const LineTouchData(enabled: false),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: spots,
                                        color: widget.color,
                                        barWidth: 2,
                                        isCurved: false,
                                        isStepLineChart: true,
                                        dotData: const FlDotData(show: false),
                                        belowBarData: BarAreaData(show: false),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    key: const ValueKey(
                                      'probability-history-selector-line',
                                    ),
                                    painter:
                                        _ProbabilityHistorySelectionPainter(
                                      round: selectedPoint.played,
                                      roundWindow: roundWindow,
                                      probability:
                                          selectedPoint.probability * 100,
                                      minimumProbability: 0,
                                      maximumProbability: maxY.toDouble(),
                                      color: widget.color,
                                      guideColor:
                                          RoundChartVisuals.selectionGuideColor(
                                              context),
                                    ),
                                  ),
                                ),
                              ),
                              _probabilityTooltip(
                                context: context,
                                chartSize: contentSize,
                                viewportWidth: plotViewportSize.width,
                                point: selectedPoint,
                                roundWindow: roundWindow,
                                minimumProbability: 0,
                                maximumProbability: maxY.toDouble(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Hide the line in the Y-axis gutter until dragging the
                    // handle slides that part of the chart into the plot.
                    Positioned(
                      left: 0,
                      top: 0,
                      width: RoundChartVisuals.axisLineInset,
                      height: topLabelHeight,
                      child: IgnorePointer(
                        child: ColoredBox(
                          key: const ValueKey(
                              'probability-history-top-gutter-mask'),
                          color: colors.cardBackground,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: IgnorePointer(
                        child: axisLabel(
                          topLabel,
                          const ValueKey('probability-history-top-label'),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      bottom: RoundChartSelectionHandle.height,
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: axisLabel(
                            middleLabel,
                            const ValueKey('probability-history-middle-label'),
                          ),
                        ),
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
              trUpper(context, 'Round'),
              key: const ValueKey('probability-history-round-label'),
              style: Body2_b.style,
            ),
          ),
        ],
      ),
    );
  }

  Widget _probabilityTooltip({
    required BuildContext context,
    required Size chartSize,
    required double viewportWidth,
    required ({int played, double probability}) point,
    required RoundChartWindow roundWindow,
    required double minimumProbability,
    required double maximumProbability,
  }) {
    const pointGap = 8.0;
    const contentGap = 8.0;
    const tooltipPadding = 8.0;
    final textStyle = Eyebrow.style.copyWith(fontWeight: FontWeight.w700);
    final roundLabel = formatRoundLabel(
        roundName: '${point.played}', locale: Localizations.localeOf(context))!;
    final valueLabel = '${(point.probability * 100).round()}%';
    final roundPainter = TextPainter(
      text: TextSpan(text: roundLabel, style: textStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final valuePainter = TextPainter(
      text: TextSpan(text: valueLabel, style: textStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = math.min(
      viewportWidth,
      roundPainter.width +
          valuePainter.width +
          contentGap +
          tooltipPadding * 2 +
          4,
    );
    final height = math.max(roundPainter.height, valuePainter.height) +
        tooltipPadding * 2 +
        2;
    final anchorY = chartSize.height *
        (1 -
            (point.probability * 100 - minimumProbability) /
                (maximumProbability - minimumProbability));
    final left = roundChartTooltipLeft(
      roundWindow: roundWindow,
      round: point.played,
      viewportWidth: viewportWidth,
      tooltipWidth: width,
      gap: pointGap,
      preferLeft: false,
    );
    final top = (anchorY - height / 2).clamp(0.0, chartSize.height - height);
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: _ProbabilityChartTooltip(
        key: const ValueKey('probability-history-tooltip'),
        label: roundLabel,
        value: valueLabel,
      ),
    );
  }
}

class _ProbabilityChartTooltip extends StatelessWidget {
  const _ProbabilityChartTooltip({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? AppPalette.white : AppPalette.black;
    final style = Eyebrow.style.copyWith(fontWeight: FontWeight.w700);
    return Container(
      padding: const EdgeInsets.all(8),
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
            label,
            maxLines: 1,
            softWrap: false,
            style: style.copyWith(
              color: foreground.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

bool _isEuropeanTitleEvent(String event) =>
    event == 'ucl_winner' || event == 'uel_winner' || event == 'uecl_winner';

@visibleForTesting
List<T> titleContendersWindow<T>(List<T> ranked, int currentIndex) {
  if (ranked.length <= 5) return ranked;
  // 상위 5위까지는 첫 다섯 팀을, 그 아래는 현재 팀 중심의 다섯 팀을 보여줘요.
  final start =
      (currentIndex < 5 ? 0 : currentIndex - 2).clamp(0, ranked.length - 5);
  return ranked.sublist(start, start + 5);
}

class _TitleContendersCard extends StatelessWidget {
  const _TitleContendersCard({
    required this.teamId,
    required this.contenders,
    required this.color,
  });

  final int teamId;
  final TitleContenders contenders;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ranked = contenders.teams;
    final ownIndex = ranked.indexWhere((team) => team.teamId == teamId);
    final visible = titleContendersWindow(ranked, ownIndex);
    final rankWidth = visible.any((team) => team.rank >= 10) ? 24.0 : 8.0;
    return Container(
      key: const ValueKey('title-contenders-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: appCardShadows(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TeamStandingLabel(
            competitionId: null,
            label: '#${contenders.rank}',
            style: Heading1.latinStyle.copyWith(height: 0.9),
            rankDelta: contenders.rankChange,
            crossAxisAlignment: CrossAxisAlignment.center,
            movementKey: const ValueKey('title-contenders-rank-movement'),
            risingIcon: SvgPicture.asset(
              'assets/standings/rank_up.svg',
              width: 24,
              height: 24,
            ),
            fallingIcon: Transform.flip(
              flipY: true,
              child: SvgPicture.asset(
                'assets/standings/rank_down.svg',
                width: 24,
                height: 24,
              ),
            ),
            risingValueStyle: Heading5.style,
            fallingValueStyle: Heading5.style,
          ),
          const SizedBox(height: 12),
          Text(tr(context, 'in odds to win title'), style: Body2.style),
          const SizedBox(height: 16),
          for (var i = 0; i < visible.length; i++) ...[
            Row(
              key: ValueKey('title-contender-row-${visible[i].teamId}'),
              children: [
                SizedBox(
                  width: rankWidth,
                  child: Text('${visible[i].rank}',
                      style: Body2_b.style.copyWith(
                        color: colors.mutedForeground,
                      )),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    _contenderCode(visible[i]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Body2_b.style,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 10,
                      color: colors.subtleBackground,
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: visible[i].probability,
                        heightFactor: 1,
                        child: Opacity(
                          opacity: visible[i].teamId == teamId ? 1 : 0.5,
                          child: ColoredBox(
                            key: ValueKey(
                                'title-contender-fill-${visible[i].teamId}'),
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 32,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${(visible[i].probability * 100).round()}%',
                      maxLines: 1,
                      style: Body2_b.style,
                    ),
                  ),
                ),
              ],
            ),
            if (i < visible.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

String _contenderCode(TitleContender contender) {
  final team = teamRepository.findById(contender.teamId);
  final letters = (team?.shortCode?.trim().isNotEmpty == true
          ? team!.shortCode!
          : contender.teamName)
      .replaceAll(RegExp(r'[^A-Za-z]'), '')
      .toUpperCase();
  return letters.length >= 3 ? letters.substring(0, 3) : 'TBD';
}

class _EuropeanProgression extends StatelessWidget {
  const _EuropeanProgression({required this.stages, required this.color});

  final List<EuropeanStageProbability> stages;
  final Color color;

  static const _labels = <(String, String)>[
    ('WINNER', 'winner'),
    ('FINAL', 'final'),
    ('SF', 'semifinal'),
    ('QF', 'quarterfinal'),
    ('R16', 'round16'),
    ('PO', 'playoff'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final widestPercentage = TextPainter(
      text: TextSpan(
        text: '100%',
        style: DefaultTextStyle.of(context).style.merge(Body2_b.style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final percentageWidth = widestPercentage.maxIntrinsicWidth.ceilToDouble();
    widestPercentage.dispose();
    Widget row(String label, EuropeanStageProbability stage) {
      final confirmed = stage.resolution == ProbabilityResolution.certain;
      return Row(
        key: ValueKey('european-how-far-$label'),
        children: [
          SizedBox(
              width: 61, child: Text(tr(context, label), style: Body2_b.style)),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 10,
                color: colors.subtleBackground,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: stage.probability,
                  heightFactor: 1,
                  child: Opacity(
                    opacity: confirmed ? 0.5 : 1,
                    child: ColoredBox(
                      key: ValueKey('european-how-far-bar-$label'),
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: percentageWidth,
            child: confirmed
                ? const Align(
                    alignment: Alignment.centerRight,
                    child:
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                  )
                : Text(
                    '${(stage.probability * 100).round()}%',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    style: Body2_b.style,
                  ),
          ),
        ],
      );
    }

    return Column(
      key: const ValueKey('european-how-far'),
      children: [
        for (final label in _labels)
          if (stages.where((stage) => stage.stageKey == label.$2).firstOrNull
              case final EuropeanStageProbability stage) ...[
            row(label.$1, stage),
            if (label != _labels.last) const SizedBox(height: 16),
          ],
      ],
    );
  }
}

class _EuropeanUnavailableCard extends StatelessWidget {
  const _EuropeanUnavailableCard();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.of(context).cardBackground,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          tr(context, 'Not ready yet'),
          textAlign: TextAlign.center,
          style: Body1.style,
        ),
      );
}

class _EuropeanStageHistoryCard extends StatefulWidget {
  const _EuropeanStageHistoryCard({required this.history, required this.color});

  final List<EuropeanStageHistoryPoint> history;
  final Color color;

  @override
  State<_EuropeanStageHistoryCard> createState() =>
      _EuropeanStageHistoryCardState();
}

class _EuropeanStageHistoryCardState extends State<_EuropeanStageHistoryCard> {
  static const _stages = ['League', 'PO', 'R16', 'QF', 'SF', 'Final'];
  static const _stageKeys = [
    'league',
    'playoff',
    'round16',
    'quarterfinal',
    'semifinal',
    'final',
  ];
  int _selectedStage = 0;
  double? _dragStartX;
  int? _dragStartStage;

  @override
  void initState() {
    super.initState();
    _selectedStage = _latestStageIndex();
  }

  @override
  void didUpdateWidget(covariant _EuropeanStageHistoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.history != widget.history) {
      _selectedStage = _latestStageIndex();
    }
  }

  int _latestStageIndex() {
    for (var index = _stageKeys.length - 1; index >= 0; index--) {
      if (widget.history.any((point) => point.stageKey == _stageKeys[index])) {
        return index;
      }
    }
    return 0;
  }

  void _moveHandle(
      double globalX, List<double> stageXs, List<int> availableStages) {
    if (_dragStartX == null ||
        _dragStartStage == null ||
        availableStages.isEmpty) {
      return;
    }
    final targetX = stageXs[_dragStartStage!] + globalX - _dragStartX!;
    // 확률 이력이 있는 단계 중에서만 가장 가까운 축 위치를 선택해요.
    var index = availableStages.first;
    for (final stage in availableStages.skip(1)) {
      if ((stageXs[stage] - targetX).abs() < (stageXs[index] - targetX).abs()) {
        index = stage;
      }
    }
    if (index != _selectedStage) setState(() => _selectedStage = index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final foreground = Theme.of(context).colorScheme.onSurface;
    final points = <({int index, double probability})>[
      for (var index = 0; index < _stageKeys.length; index++)
        if (widget.history
                .where((point) => point.stageKey == _stageKeys[index])
                .firstOrNull
            case final EuropeanStageHistoryPoint point)
          (index: index, probability: point.probability),
    ];
    final availableStages = [for (final point in points) point.index];
    final maxY = (points
                    .map((point) => point.probability * 100)
                    .fold<double>(0, math.max) /
                20)
            .ceil()
            .clamp(1, 5) *
        20;
    final selectedPoint =
        points.where((point) => point.index == _selectedStage).firstOrNull;
    final gridColor = foreground.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.32 : 0.18,
    );
    return Container(
      key: const ValueKey('european-stage-history-card'),
      height: RoundChartVisuals.cardHeight,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(RoundChartVisuals.cardRadius),
        boxShadow: appCardShadows(context),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final stageLabelStyle =
              Eyebrow.style.copyWith(fontWeight: FontWeight.w700);
          final stageWidths = <double>[];
          for (final stage in _stages) {
            final painter = TextPainter(
              text: TextSpan(text: stage, style: stageLabelStyle),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 1,
            )..layout();
            stageWidths.add(painter.width.ceilToDouble());
            painter.dispose();
          }
          final totalLabelWidth = stageWidths.reduce((a, b) => a + b);
          // 작은 화면에서도 라벨 사이에 간격을 남기고 축 전체만 축소해요.
          final axisWidth = math.max(
            width,
            totalLabelWidth + (_stages.length - 1) * 8,
          );
          final axisScale = width / axisWidth;
          final gap = (axisWidth - totalLabelWidth) / (_stages.length - 1);
          final stageXs = <double>[];
          var stageLeft = 0.0;
          for (final stageWidth in stageWidths) {
            stageXs.add((stageLeft + stageWidth / 2) * axisScale);
            stageLeft += stageWidth + gap;
          }
          final selectedX = stageXs[_selectedStage];
          final plotHeight =
              constraints.maxHeight - 8 - 24 - RoundChartSelectionHandle.height;
          final topLabel = '$maxY%';
          final middleLabel = '${maxY ~/ 2}%';
          const labelPadding = 4.0;
          final axisLabelStyle = Body2_b.style;
          double labelHeight(String label) {
            final painter = TextPainter(
              text: TextSpan(text: label, style: axisLabelStyle),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 1,
            )..layout();
            final height = painter.width + labelPadding * 2;
            painter.dispose();
            return height;
          }

          final topLabelHeight = labelHeight(topLabel);
          final middleLabelHeight = labelHeight(middleLabel);
          final insetLineIndices = <int>{
            for (var index = 0;
                index < RoundChartVisuals.horizontalLineCount;
                index++)
              if (plotHeight *
                          index /
                          (RoundChartVisuals.horizontalLineCount - 1) <
                      topLabelHeight ||
                  (plotHeight *
                                  index /
                                  (RoundChartVisuals.horizontalLineCount - 1) -
                              plotHeight / 2)
                          .abs() <
                      middleLabelHeight / 2)
                index,
          };
          Widget axisLabel(String label, Key key) => ColoredBox(
                color: colors.cardBackground,
                child: Padding(
                  padding: const EdgeInsets.all(labelPadding),
                  child: RotatedBox(
                    key: key,
                    quarterTurns: 1,
                    child: Text(label, style: axisLabelStyle),
                  ),
                ),
              );
          final selectedValue = selectedPoint == null
              ? null
              : '${(selectedPoint.probability * 100).round()}%';
          final selectedPointY = selectedPoint == null
              ? null
              : plotHeight * (1 - selectedPoint.probability * 100 / maxY);
          final tooltipStyle =
              Eyebrow.style.copyWith(fontWeight: FontWeight.w700);
          final labelPainter = TextPainter(
            text: TextSpan(text: _stages[_selectedStage], style: tooltipStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final valuePainter = TextPainter(
            text: TextSpan(text: selectedValue ?? '', style: tooltipStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final tooltipWidth = math.min(
            width,
            labelPainter.width + valuePainter.width + 8 + 16 + 4,
          );
          final tooltipHeight =
              math.max(labelPainter.height, valuePainter.height) + 16 + 2;
          labelPainter.dispose();
          valuePainter.dispose();
          final tooltipLeft = (selectedX + 8 + tooltipWidth <= width
                  ? selectedX + 8
                  : selectedX - 8 - tooltipWidth)
              .clamp(0.0, width - tooltipWidth);
          final tooltipTop = selectedPointY == null
              ? 0.0
              : (selectedPointY - tooltipHeight / 2)
                  .clamp(0.0, plotHeight - tooltipHeight);
          return Column(
            children: [
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      bottom: RoundChartSelectionHandle.height,
                      child: CustomPaint(
                        key: const ValueKey('european-stage-grid'),
                        painter: RoundChartGridPainter(
                          color: gridColor,
                          insetLineCount: 0,
                          insetLineIndices: insetLineIndices,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      bottom: RoundChartSelectionHandle.height,
                      child: CustomPaint(
                        key: const ValueKey('european-stage-history-line'),
                        painter: _EuropeanStageLinePainter(
                          points: points,
                          stageXs: stageXs,
                          maxY: maxY.toDouble(),
                          color: widget.color,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      bottom: RoundChartSelectionHandle.height,
                      child: CustomPaint(
                        key: const ValueKey('european-stage-selector-line'),
                        painter: _EuropeanStageGuidePainter(
                          x: selectedX,
                          color: RoundChartVisuals.selectionGuideColor(context),
                          pointY: selectedPointY,
                          pointColor: widget.color,
                        ),
                      ),
                    ),
                    RoundChartSelectionHandle(
                      x: selectedX,
                      color: foreground,
                      onDragDown: (globalX) {
                        _dragStartX = globalX;
                        _dragStartStage = _selectedStage;
                      },
                      onDrag: (globalX) =>
                          _moveHandle(globalX, stageXs, availableStages),
                    ),
                    if (selectedPoint != null)
                      Positioned(
                        left: tooltipLeft,
                        top: tooltipTop,
                        width: tooltipWidth,
                        height: tooltipHeight,
                        child: _ProbabilityChartTooltip(
                          key: const ValueKey('european-stage-tooltip'),
                          label: _stages[_selectedStage],
                          value: selectedValue!,
                        ),
                      ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: IgnorePointer(
                        child: axisLabel(
                          topLabel,
                          const ValueKey('european-stage-top-label'),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      bottom: RoundChartSelectionHandle.height,
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: axisLabel(
                            middleLabel,
                            const ValueKey('european-stage-middle-label'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 24,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: axisWidth,
                    height: 24,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var index = 0; index < _stages.length; index++)
                          GestureDetector(
                            key: ValueKey('european-stage-${_stages[index]}'),
                            behavior: HitTestBehavior.opaque,
                            onTap: availableStages.contains(index)
                                ? () => setState(() => _selectedStage = index)
                                : null,
                            child: SizedBox(
                              width: stageWidths[index],
                              height: 24,
                              child: Center(
                                child: Text(
                                  _stages[index],
                                  maxLines: 1,
                                  softWrap: false,
                                  style: stageLabelStyle,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EuropeanStageLinePainter extends CustomPainter {
  const _EuropeanStageLinePainter({
    required this.points,
    required this.stageXs,
    required this.maxY,
    required this.color,
  });

  final List<({int index, double probability})> points;
  final List<double> stageXs;
  final double maxY;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    Offset offset(({int index, double probability}) point) => Offset(
          stageXs[point.index],
          size.height * (1 - point.probability * 100 / maxY),
        );
    final path = Path()
      ..moveTo(offset(points.first).dx, offset(points.first).dy);
    for (final point in points.skip(1)) {
      final position = offset(point);
      path.lineTo(position.dx, position.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_EuropeanStageLinePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.stageXs != stageXs ||
      oldDelegate.maxY != maxY ||
      oldDelegate.color != color;
}

class _EuropeanStageGuidePainter extends CustomPainter {
  const _EuropeanStageGuidePainter({
    required this.x,
    required this.color,
    required this.pointY,
    required this.pointColor,
  });

  final double x;
  final Color color;
  final double? pointY;
  final Color pointColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 15) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, (y + 8).clamp(0.0, size.height)),
        paint,
      );
    }
    // 점선과 겹쳐도 선택한 확률 포인트가 앞에 보이도록 마지막에 그려요.
    if (pointY != null) {
      canvas.drawCircle(Offset(x, pointY!), 5, Paint()..color = pointColor);
    }
  }

  @override
  bool shouldRepaint(_EuropeanStageGuidePainter oldDelegate) =>
      oldDelegate.x != x ||
      oldDelegate.color != color ||
      oldDelegate.pointY != pointY ||
      oldDelegate.pointColor != pointColor;
}

class _ProbabilityHistorySelectionPainter extends CustomPainter {
  const _ProbabilityHistorySelectionPainter({
    required this.round,
    required this.roundWindow,
    required this.probability,
    required this.minimumProbability,
    required this.maximumProbability,
    required this.color,
    required this.guideColor,
  });

  final int round;
  final RoundChartWindow roundWindow;
  final double probability;
  final double minimumProbability;
  final double maximumProbability;
  final Color color;
  final Color guideColor;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * roundWindow.fractionOf(round);
    final guidePaint = Paint()
      ..color = guideColor
      ..strokeWidth = 1;
    const dashHeight = 8.0;
    const dashGap = 7.0;
    final guideBottom = size.height;
    for (var y = 0.0; y < guideBottom; y += dashHeight + dashGap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, (y + dashHeight).clamp(0.0, guideBottom)),
        guidePaint,
      );
    }
    final pointY = size.height *
        (1 -
            (probability - minimumProbability) /
                (maximumProbability - minimumProbability));
    canvas.drawCircle(Offset(x, pointY), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ProbabilityHistorySelectionPainter oldDelegate) =>
      oldDelegate.round != round ||
      oldDelegate.roundWindow.firstRound != roundWindow.firstRound ||
      oldDelegate.probability != probability ||
      oldDelegate.minimumProbability != minimumProbability ||
      oldDelegate.maximumProbability != maximumProbability ||
      oldDelegate.guideColor != guideColor ||
      oldDelegate.color != color;
}

class _ProjectedPositions extends StatelessWidget {
  const _ProjectedPositions({
    required this.positions,
    required this.color,
    this.showLast = false,
  });

  final List<TeamPositionProbability> positions;
  final Color color;
  final bool showLast;

  @override
  Widget build(BuildContext context) {
    if (positions.isEmpty) return const _UnavailableCard();
    final ordered = [...positions]
      ..sort((a, b) => a.position.compareTo(b.position));
    final displayed = showLast
        ? ordered.skip(ordered.length > 5 ? ordered.length - 5 : 0)
        : ordered.take(5);
    return Column(
      key: const ValueKey('projected-final-position'),
      children: [
        for (final item in displayed) ...[
          Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  _ordinal(item.position),
                  key: ValueKey('projected-position-${item.position}'),
                  style: Body2_b.style,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.probability,
                    minHeight: 10,
                    color: color,
                    backgroundColor: AppColors.of(context).cardBackground,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 40,
                child: Text(
                  '${(item.probability * 100).round()}%',
                  key: ValueKey(
                    'projected-position-percentage-${item.position}',
                  ),
                  textAlign: TextAlign.right,
                  style: Body1_b.style,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ],
          ),
          if (item != displayed.last) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _ProjectedPointsCard extends StatelessWidget {
  const _ProjectedPointsCard({
    required this.projectedPoints,
    required this.maximumPoints,
    required this.color,
  });

  final TeamProjectedPoints projectedPoints;
  final int maximumPoints;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // 시즌 최대 승점으로 평균과 예상 구간을 0~1 좌표로 바꾸고 막대 밖은 잘라요.
    // 분모가 0인 입력에도 차트 계산을 계속할 수 있도록 1을 사용해요.
    final maxPoints = maximumPoints <= 0 ? 1 : maximumPoints;
    final mean = (projectedPoints.mean / maxPoints).clamp(0.0, 1.0);
    final lower =
        (projectedPoints.likelyRange.lower / maxPoints).clamp(0.0, 1.0);
    final upper =
        (projectedPoints.likelyRange.upper / maxPoints).clamp(0.0, 1.0);
    final delta = projectedPoints.changePoints;
    final rangeParts =
        tr(context, 'Likely range of {range} pts').split('{range}');

    return Container(
      key: const ValueKey('projected-points-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.of(context).cardBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  projectedPoints.mean.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    height: 0.9,
                  ),
                ),
                const SizedBox(width: 4),
                Text('pts', style: Heading4.style),
              ],
            ),
          ),
          if (delta != null && delta != 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  key: const ValueKey('projected-points-delta-icon'),
                  delta > 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: color,
                ),
                Text(
                  '${formatDisplayNumber(delta.abs(), trimTrailingZeros: true)}%',
                  style: Heading5.style,
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                height: 20,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.of(context).subtleBackground,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Positioned(
                      left: constraints.maxWidth * lower,
                      width: constraints.maxWidth * (upper - lower),
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: mean,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (constraints.maxWidth * mean - 2).clamp(
                        0,
                        constraints.maxWidth - 4,
                      ),
                      child: Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0', style: Body2.style),
              Text('$maximumPoints', style: Body2.style),
            ],
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: rangeParts[0],
                  style: Body1.style,
                ),
                TextSpan(
                  text:
                      '${projectedPoints.likelyRange.lower}–${projectedPoints.likelyRange.upper}',
                  style: Body1_b.style,
                ),
                TextSpan(text: rangeParts[1], style: Body1.style),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: Body2_b.style);
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.of(context).cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text('아직 준비중이에요ㅠㅠ', textAlign: TextAlign.center),
    );
  }
}

TeamProbabilityCard? _findCard(
  List<TeamProbabilityCard> cards,
  String event,
) {
  for (final card in cards) {
    if (card.event == event) return card;
  }
  return null;
}

IconData _eventIcon(String event) {
  return switch (event) {
    'league_winner' ||
    'ucl_winner' ||
    'uel_winner' ||
    'uecl_winner' =>
      Icons.emoji_events_outlined,
    'top_4' || 'top_6' => Icons.leaderboard_outlined,
    'direct_relegation' || 'relegation_playoff' => Icons.trending_down,
    _ => Icons.query_stats,
  };
}

String _ordinal(int value) {
  final suffix = switch (value % 100) {
    11 || 12 || 13 => 'TH',
    _ => switch (value % 10) {
        1 => 'ST',
        2 => 'ND',
        3 => 'RD',
        _ => 'TH',
      },
  };
  return '$value$suffix';
}

// ignore_for_file: file_names
