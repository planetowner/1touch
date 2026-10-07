import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/number_display.dart';
import 'package:onetouch/core/round_chart_window.dart';
import 'package:onetouch/core/round_chart_visuals.dart';
import 'package:onetouch/core/probability_display.dart';
import 'package:onetouch/features/team/probability/probability_number.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/team_probability/team_probability_repository.dart';
import 'package:onetouch/data/team_probability/team_probability_repository_provider.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/fixture_labels.dart';
import 'package:onetouch/models/team_probability.dart';
import 'package:onetouch/screens/team_probability_what_if_screen.dart';

const _fallbackProbabilityColor = Color(0xFFD82457);

class TeamProbabilityScreen extends StatefulWidget {
  const TeamProbabilityScreen({
    super.key,
    required this.teamId,
    required this.event,
    this.initialSnapshot,
    this.repository,
    this.teamPrimaryColor,
  });

  final int teamId;
  final String event;
  final TeamProbabilitySnapshot? initialSnapshot;
  final TeamProbabilityRepository? repository;
  final Color? teamPrimaryColor;

  @override
  State<TeamProbabilityScreen> createState() => _TeamProbabilityScreenState();
}

class _TeamProbabilityScreenState extends State<TeamProbabilityScreen> {
  TeamProbabilitySnapshot? _snapshot;
  Object? _error;

  TeamProbabilityRepository get _repository =>
      widget.repository ?? teamProbabilityRepository;

  @override
  void initState() {
    super.initState();
    _snapshot =
        widget.initialSnapshot ?? _repository.cachedForTeam(widget.teamId);
    if (_snapshot == null) _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final snapshot = await _repository.loadForTeam(widget.teamId);
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      key: const ValueKey('team-probability-detail-screen'),
      backgroundColor: mainPageBackground(context),
      body: _buildBody(context),
      bottomNavigationBar: snapshot == null
          ? null
          : _buildPersistentWhatIfButton(
              context,
              snapshot,
              _teamPrimaryColor(),
            ),
    );
  }

  Color _teamPrimaryColor() {
    final repositoryTeam = teamRepository.findById(widget.teamId);
    return widget.teamPrimaryColor ??
        (repositoryTeam == null
            ? _fallbackProbabilityColor
            : Color(repositoryTeam.primaryColor));
  }

  Widget _buildPersistentWhatIfButton(
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

  void _openWhatIf(
    BuildContext context,
    TeamProbabilitySnapshot snapshot,
    Color teamPrimaryColor,
  ) {
    final whatIf = snapshot.whatIf;
    if (whatIf == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(context, 'What-if data is unavailable.')),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TeamProbabilityWhatIfScreen(
          snapshot: snapshot,
          event: widget.event,
          teamPrimaryColor: teamPrimaryColor,
          homeTeam: teamRepository.findById(whatIf.fixture.homeTeamId),
          awayTeam: teamRepository.findById(whatIf.fixture.awayTeamId),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final snapshot = _snapshot;
    if (snapshot == null && _error == null) {
      return const Center(child: FootballLoadingIndicator());
    }
    if (snapshot == null) {
      return Center(
        child: TextButton(
          key: const ValueKey('team-probability-detail-retry'),
          onPressed: _load,
          child: const Text('Retry probability'),
        ),
      );
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
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(tr(context, 'PROBABILITY HISTORY')),
              const SizedBox(height: 16),
              _ProbabilityHistoryCard(
                history: snapshot.history,
                event: widget.event,
                maximumRound: (snapshot.maximumPoints / 3).round(),
                color: teamPrimaryColor,
              ),
              const SizedBox(height: 48),
              _SectionTitle(tr(context, 'PROJECTED FINAL POSITION')),
              const SizedBox(height: 16),
              _ProjectedPositions(
                positions: snapshot.positions,
                color: teamPrimaryColor,
                showLast: widget.event == 'direct_relegation' ||
                    widget.event == 'relegation_playoff',
              ),
              const SizedBox(height: 48),
              _SectionTitle(tr(context, 'PROJECTED POINTS')),
              const SizedBox(height: 16),
              _ProjectedPointsCard(
                projectedPoints: snapshot.projectedPoints,
                maximumPoints: snapshot.maximumPoints,
                color: teamPrimaryColor,
              ),
            ],
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? AppPalette.white : AppPalette.black;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        key: const ValueKey('probability-history-tooltip'),
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
              style: textStyle.copyWith(
                color: foreground.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(width: contentGap),
            Flexible(
              child: Text(
                valueLabel,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: textStyle.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProbabilityHistorySelectionPainter extends CustomPainter {
  const _ProbabilityHistorySelectionPainter({
    required this.round,
    required this.roundWindow,
    required this.probability,
    required this.minimumProbability,
    required this.maximumProbability,
    required this.color,
  });

  final int round;
  final RoundChartWindow roundWindow;
  final double probability;
  final double minimumProbability;
  final double maximumProbability;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * roundWindow.fractionOf(round);
    final guidePaint = Paint()
      ..color = color.withValues(alpha: 0.9)
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
