import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/team_probability/team_probability_repository.dart';
import 'package:onetouch/data/team_probability/team_probability_repository_provider.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/l10n/app_localizations.dart';
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
            child: Text(tr(context, 'WHAT IF?'), style: Body2_b.style),
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
      return const Center(child: CircularProgressIndicator());
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
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
              const SizedBox(height: 24),
              _ProjectedPositions(
                positions: snapshot.positions,
                color: teamPrimaryColor,
                showLast: widget.event == 'direct_relegation' ||
                    widget.event == 'relegation_playoff',
              ),
              const SizedBox(height: 48),
              _SectionTitle(tr(context, 'PROJECTED POINTS')),
              const SizedBox(height: 24),
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
                    Text(
                      '${(card.probability * 100).round()}',
                      key: const ValueKey('probability-detail-value'),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        height: 0.9,
                      ),
                    ),
                    Text('%', style: Heading4.style),
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
                      Text('${_compact(delta.abs())}%', style: Heading5.style),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 138,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(_eventIcon(card.event), size: 56),
                const SizedBox(height: 4),
                SizedBox(
                  width: 138,
                  height: 39,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      tr(context, _eventTitle(card.event)),
                      key: const ValueKey('probability-event-title'),
                      maxLines:
                          Localizations.localeOf(context).languageCode == 'ko'
                              ? 1
                              : 2,
                      softWrap:
                          Localizations.localeOf(context).languageCode != 'ko',
                      overflow: TextOverflow.ellipsis,
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

    final colors = AppColors.of(context);
    final spots = [
      for (final point in points)
        FlSpot(point.played.toDouble(), point.probability * 100),
    ];
    final lastRound = widget.maximumRound <= 0
        ? points.map((point) => point.played).reduce((a, b) => a > b ? a : b)
        : widget.maximumRound;
    final highestProbability =
        spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    final maxY = ((highestProbability / 20).ceil() * 20).clamp(40, 100);
    final gridColor = Theme.of(context).colorScheme.onSurface.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.32 : 0.18,
        );
    final selectedPoint = _selectedRound == null
        ? null
        : points.where((point) => point.played == _selectedRound).firstOrNull;

    return Container(
      key: const ValueKey('probability-history-card'),
      height: 345,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: appCardShadows(context),
      ),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chartSize = constraints.biggest;
                return GestureDetector(
                  key: const ValueKey('probability-history-chart'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => _selectRound(
                    details.localPosition.dx,
                    chartSize.width,
                    lastRound,
                    points,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          key: const ValueKey('probability-history-grid'),
                          painter: _ProbabilityHistoryGridPainter(
                            color: gridColor,
                          ),
                        ),
                      ),
                      Positioned(
                        left: _ProbabilityHistoryGridPainter.labelInset,
                        top: 0,
                        right: 0,
                        bottom: 0,
                        child: LineChart(
                          key: const ValueKey('probability-history-line-chart'),
                          LineChartData(
                            minX: 0,
                            maxX: lastRound.toDouble(),
                            minY: 0,
                            maxY: maxY.toDouble(),
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
                            lineTouchData: const LineTouchData(enabled: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                color: widget.color,
                                barWidth: 3,
                                isCurved: false,
                                isStepLineChart: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(show: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (selectedPoint != null)
                        Positioned(
                          left: _ProbabilityHistoryGridPainter.labelInset,
                          top: 0,
                          right: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: CustomPaint(
                              key: const ValueKey(
                                'probability-history-selector-line',
                              ),
                              painter: _ProbabilityHistorySelectionPainter(
                                round: selectedPoint.played,
                                maximumRound: lastRound,
                                probability: selectedPoint.probability * 100,
                                maximumProbability: maxY.toDouble(),
                                color: widget.color,
                              ),
                            ),
                          ),
                        ),
                      Align(
                        alignment: Alignment.topLeft,
                        child: RotatedBox(
                          quarterTurns: 1,
                          child: Text('$maxY%', style: Body2_b.style),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: RotatedBox(
                          quarterTurns: 1,
                          child: Text('${maxY ~/ 2}%', style: Body2_b.style),
                        ),
                      ),
                      if (selectedPoint != null)
                        _probabilityTooltip(
                          context: context,
                          chartSize: chartSize,
                          point: selectedPoint,
                          maximumRound: lastRound,
                          maximumProbability: maxY.toDouble(),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text('RO$lastRound', style: Body2_b.style),
          ),
        ],
      ),
    );
  }

  void _selectRound(
    double localX,
    double chartWidth,
    int maximumRound,
    List<({int played, double probability})> points,
  ) {
    final plotWidth = chartWidth - _ProbabilityHistoryGridPainter.labelInset;
    if (plotWidth <= 0 || points.isEmpty) return;
    final plotX = (localX - _ProbabilityHistoryGridPainter.labelInset)
        .clamp(0.0, plotWidth);
    final targetRound = plotX / plotWidth * maximumRound;
    var nearest = points.first;
    for (final point in points.skip(1)) {
      if ((point.played - targetRound).abs() <
          (nearest.played - targetRound).abs()) {
        nearest = point;
      }
    }
    if (_selectedRound == nearest.played) return;
    setState(() => _selectedRound = nearest.played);
  }

  Widget _probabilityTooltip({
    required BuildContext context,
    required Size chartSize,
    required ({int played, double probability}) point,
    required int maximumRound,
    required double maximumProbability,
  }) {
    const width = 132.0;
    const height = 36.0;
    const pointGap = 8.0;
    final plotWidth =
        chartSize.width - _ProbabilityHistoryGridPainter.labelInset;
    final anchorX = _ProbabilityHistoryGridPainter.labelInset +
        plotWidth * point.played / maximumRound;
    final anchorY =
        chartSize.height * (1 - point.probability * 100 / maximumProbability);
    final fitsRight = anchorX + pointGap + width <= chartSize.width;
    final left = fitsRight
        ? anchorX + pointGap
        : (anchorX - pointGap - width).clamp(0.0, chartSize.width - width);
    final top = (anchorY - height / 2).clamp(0.0, chartSize.height - height);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? AppPalette.white : AppPalette.black;
    final textStyle = Eyebrow.style.copyWith(fontWeight: FontWeight.w700);

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        key: const ValueKey('probability-history-tooltip'),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? AppPalette.black : AppPalette.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: isDark ? null : lightModeCardShadows,
        ),
        child: Row(
          children: [
            Flexible(
              child: Text(
                tr(context, 'Round {round}', {'round': point.played}),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: textStyle.copyWith(
                  color: foreground.withValues(alpha: 0.55),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(point.probability * 100).round()}%',
              style: textStyle.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProbabilityHistoryGridPainter extends CustomPainter {
  const _ProbabilityHistoryGridPainter({required this.color});

  final Color color;

  static const int lineCount = 12;
  static const double labelInset = 32;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const divisionCount = lineCount - 1;
    for (var index = 0; index <= divisionCount; index++) {
      final y = size.height * index / divisionCount;
      const middleUpper = divisionCount ~/ 2;
      final hasPercentageLabel =
          index <= 1 || index == middleUpper || index == middleUpper + 1;
      canvas.drawLine(
        Offset(hasPercentageLabel ? labelInset : 0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProbabilityHistoryGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ProbabilityHistorySelectionPainter extends CustomPainter {
  const _ProbabilityHistorySelectionPainter({
    required this.round,
    required this.maximumRound,
    required this.probability,
    required this.maximumProbability,
    required this.color,
  });

  final int round;
  final int maximumRound;
  final double probability;
  final double maximumProbability;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * round / maximumRound;
    final guidePaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 1;
    const dashHeight = 8.0;
    const dashGap = 7.0;
    for (var y = 0.0; y < size.height; y += dashHeight + dashGap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, (y + dashHeight).clamp(0.0, size.height)),
        guidePaint,
      );
    }
    final pointY = size.height * (1 - probability / maximumProbability);
    canvas.drawCircle(Offset(x, pointY), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ProbabilityHistorySelectionPainter oldDelegate) =>
      oldDelegate.round != round ||
      oldDelegate.maximumRound != maximumRound ||
      oldDelegate.probability != probability ||
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
          Row(
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
          if (delta != null && delta != 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  key: const ValueKey('projected-points-delta-icon'),
                  delta > 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: color,
                ),
                Text('${_compact(delta.abs())}%', style: Heading5.style),
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
                  text: '${tr(context, 'Likely range of')} ',
                  style: Body1.style,
                ),
                TextSpan(
                  text:
                      '${projectedPoints.likelyRange.lower}–${projectedPoints.likelyRange.upper} pts',
                  style: Body1_b.style,
                ),
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

String _eventTitle(String event) {
  return switch (event) {
    'league_winner' => 'Chances to Win\nLeague Trophy',
    'ucl_winner' => 'Chances to Win\nUCL Trophy',
    'uel_winner' => 'Chances to Win\nUEL Trophy',
    'uecl_winner' => 'Chances to Win\nUECL Trophy',
    'top_4' => 'Chances to Finish\nTop 4',
    'top_6' => 'Chances to Finish\nTop 6',
    'direct_relegation' => 'Chances of\nRelegation',
    'relegation_playoff' => 'Chances of Relegation\nPlayoff',
    _ => event
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' '),
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

String _compact(double value) {
  var fixed = value.toStringAsFixed(2);
  while (fixed.endsWith('0')) {
    fixed = fixed.substring(0, fixed.length - 1);
  }
  return fixed.endsWith('.') ? fixed.substring(0, fixed.length - 1) : fixed;
}
// ignore_for_file: file_names
