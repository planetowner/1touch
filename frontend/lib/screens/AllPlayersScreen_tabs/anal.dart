import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:onetouch/core/app_info_button.dart';
import 'package:onetouch/core/overflow_scrolling_text.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/round_chart_window.dart';
import 'package:onetouch/core/round_chart_visuals.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/features/player/player_stat_value.dart';
import 'package:onetouch/models/player.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/fixture_labels.dart';

class AnalysisTab extends StatefulWidget {
  const AnalysisTab({super.key, this.player, this.playerId});

  final Player? player;
  final int? playerId;
  int? get id => playerId ?? player?.externalPlayerId;

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab> {
  int? _seasonId;

  @override
  void didUpdateWidget(covariant AnalysisTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) _seasonId = null;
  }

  @override
  Widget build(BuildContext context) => PlayerDetailView(
        playerId: widget.id,
        seasonId: _seasonId,
        builder: (context, detail) => SingleChildScrollView(
          key: const ValueKey('player-analysis-scroll'),
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlayerSeasonSelector(
                key: ValueKey(
                    'player-analysis-season-${detail.selectedSeason?.id}'),
                detail: detail,
                width: double.infinity,
                onChanged: (id) => setState(() => _seasonId = id),
              ),
              const SizedBox(height: 32),
              if (detail.analysis == null)
                Text(tr(context, 'Select a season with league appearances'))
              else
                ..._content(detail, detail.analysis!),
            ],
          ),
        ),
      );

  List<Widget> _content(PlayerDetail detail, PlayerAnalysis analysis) => [
        _topStats(analysis),
        const SizedBox(height: 32),
        _influenceBlock(analysis),
        const SizedBox(height: 48),
        _attributes(detail),
        const SizedBox(height: 48),
        PlayerSection(
          title: tr(context, 'PERFORMANCE'),
          child: PlayerPerformanceChart(points: analysis.performance),
        ),
      ];

  Widget _topStats(PlayerAnalysis analysis) {
    final showPer90 = analysis.topStats
        .any((stat) => playerSeasonStat(stat).unit == 'per 90');
    return PlayerSection(
      title: tr(context, 'TOP STATS'),
      titleAccessory: const AppInfoButton(
        key: ValueKey('top-stats-help-icon'),
        message:
            'The 3 stats with the highest ranks among players in the same position in the selected league and season.',
      ),
      child: PlayerSurface(
        key: const ValueKey('player-top-stats-card'),
        color: AppColors.of(context).subtleBackground,
        radius: 24,
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final statWidth = math.min(90.0, (constraints.maxWidth - 16) / 3);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < 3; index++)
                  SizedBox(
                    width: statWidth,
                    child: _topStat(
                      index < analysis.topStats.length
                          ? analysis.topStats[index]
                          : null,
                      showPer90: showPer90,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topStat(PlayerSeasonMetric? stat, {required bool showPer90}) {
    final presentation = playerSeasonStat(stat);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: ValueKey('player-top-stat-value-${stat?.metric.label}'),
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF272828)
                : AppColors.of(context).cardBackground,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              presentation.text,
              style: Heading2.latinStyle,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (showPer90) ...[
          SizedBox(
            height: 20,
            child: Center(
              child: stat != null && presentation.unit == 'per 90'
                  ? Text(tr(context, presentation.unit), style: Eyebrow.style)
                  : null,
            ),
          ),
          const SizedBox(height: 4),
        ],
        SizedBox(
          height: 24,
          child: Center(
            key: ValueKey('player-top-stat-label-${stat?.metric.label}'),
            child: OverflowScrollingText(
              text: appStatLabel(context, presentation.label),
              style: Body1.style,
              alignment: Alignment.center,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          child: Container(
            key: ValueKey('player-top-stat-rank-${stat?.metric.label}'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.black,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              stat?.rank == null ? '—' : '#${stat!.rank}',
              style: Eyebrow.style.copyWith(color: AppPalette.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _influenceBlock(PlayerAnalysis analysis) => PlayerSection(
        title: tr(context, 'INFLUENCE'),
        child: GridView.count(
          padding: EdgeInsets.zero,
          primary: false,
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1,
          children: [
            _influence(
                tr(context, 'Starting Rate'), analysis.startingRate, '%'),
            _influence(tr(context, 'Win Rate'), analysis.winRate, '%'),
          ],
        ),
      );

  Widget _influence(String label, double? value, String suffix) =>
      PlayerSurface(
        radius: 24,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF272828)
            : AppColors.of(context).cardBackground,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Body1.style.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.3,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value == null
                        ? '—'
                        : playerNumber(value, decimals: suffix.isEmpty ? 0 : 1),
                    style: Heading1.latinStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 0.9,
                    ),
                  ),
                  if (value != null && suffix.isNotEmpty)
                    Text(
                      tr(context, suffix),
                      style: Heading4.style.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 20,
                        height: 1.2,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _attributes(PlayerDetail detail) {
    return PlayerSection(
      title: tr(context, 'ATTRIBUTES'),
      child: PlayerSurface(
        key: const ValueKey('player-attributes-card'),
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          height: 96,
          child: Center(
            child: Text(
              tr(context, 'Coming soon'),
              style: Heading5.style,
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerPerformanceChart extends StatefulWidget {
  const PlayerPerformanceChart({super.key, required this.points});

  final List<PlayerPerformancePoint> points;

  @override
  State<PlayerPerformanceChart> createState() => _PlayerPerformanceChartState();
}

class _PlayerPerformanceChartState extends State<PlayerPerformanceChart> {
  static const _lineColor = Color(0xFF5C92FF);

  int? _selectedRound;

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final valid = widget.points.where((point) => point.rating != null).toList()
      ..sort((a, b) => a.round.compareTo(b.round));
    final latestRound = valid.isEmpty ? 1 : valid.last.round;
    final roundWindow = RoundChartWindow.centeredThrough(latestRound);
    final visibleRatings = valid.map((point) => point.rating!).toList();
    final lowestRating =
        visibleRatings.isEmpty ? 0.0 : visibleRatings.reduce(math.min);
    final highestRating =
        visibleRatings.isEmpty ? 10.0 : visibleRatings.reduce(math.max);
    final ratingStep = highestRating - lowestRating > 4 ? 1.0 : 0.5;
    final minRating = math.max(
      0.0,
      ((lowestRating - 0.5) / ratingStep).floor() * ratingStep,
    );
    final maxRating = math.min(
      10.0,
      ((highestRating + 0.5) / ratingStep).ceil() * ratingStep,
    );
    final gridColor = colorScheme.onSurface.withValues(
      alpha: isDark ? 0.32 : 0.18,
    );
    final targetRound = latestRound <= 7 ? latestRound : latestRound - 3;
    final initialPoint =
        valid.where((point) => point.round <= targetRound).lastOrNull ??
            valid.firstOrNull;
    final selectedPoint =
        valid.where((point) => point.round == _selectedRound).firstOrNull ??
            initialPoint;

    return Container(
      key: const ValueKey('player-performance-card'),
      height: RoundChartVisuals.cardHeight,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: appColors.cardBackground,
        borderRadius: BorderRadius.circular(RoundChartVisuals.cardRadius),
        boxShadow: appCardShadows(context),
      ),
      child: valid.isEmpty
          ? Center(child: Text(tr(context, 'No ratings available')))
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final viewportSize = constraints.biggest;
                      final chartSize = Size(
                        roundWindow.contentWidth(viewportSize.width),
                        viewportSize.height - RoundChartSelectionHandle.height,
                      );
                      final axisLabel = tr(context, 'PERFORMANCE');
                      final axisLabelStyle = Body2_b.style;
                      final insetLineCount = roundChartInsetLineCount(
                        context,
                        chartSize,
                        axisLabel,
                        axisLabelStyle,
                      );
                      return Stack(
                        children: [
                          Positioned.fill(
                            bottom: RoundChartSelectionHandle.height,
                            child: CustomPaint(
                              key: const ValueKey('player-performance-grid'),
                              painter: RoundChartGridPainter(
                                color: gridColor,
                                insetLineCount: insetLineCount,
                              ),
                            ),
                          ),
                          RoundChartViewport(
                            key: const ValueKey('player-performance-viewport'),
                            roundWindow: roundWindow,
                            viewportSize: viewportSize,
                            selectedRound: selectedPoint?.round,
                            selectableRounds: [
                              for (final point in valid) point.round
                            ],
                            onRoundChanged: (round) =>
                                setState(() => _selectedRound = round),
                            builder: (context, _) => Stack(
                              key: const ValueKey('player-performance-chart'),
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: LineChart(
                                      LineChartData(
                                        minX: roundWindow.firstRound.toDouble(),
                                        maxX: roundWindow.lastRound.toDouble(),
                                        minY: minRating,
                                        maxY: maxRating,
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
                                            spots: [
                                              for (final point
                                                  in widget.points.where(
                                                (point) => roundWindow
                                                    .contains(point.round),
                                              ))
                                                point.rating == null
                                                    ? FlSpot.nullSpot
                                                    : FlSpot(
                                                        point.round.toDouble(),
                                                        point.rating!,
                                                      ),
                                            ],
                                            color: _lineColor,
                                            barWidth: 2,
                                            isCurved: false,
                                            dotData:
                                                const FlDotData(show: false),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (selectedPoint != null)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        key: const ValueKey(
                                            'player-performance-selector-line'),
                                        painter:
                                            _PlayerPerformanceSelectionPainter(
                                          round: selectedPoint.round,
                                          roundWindow: roundWindow,
                                          rating: selectedPoint.rating!,
                                          minRating: minRating,
                                          maxRating: maxRating,
                                          color: _lineColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (selectedPoint != null)
                                  _tooltip(
                                    chartSize,
                                    viewportSize.width,
                                    selectedPoint,
                                    roundWindow,
                                    isDark,
                                    minRating,
                                    maxRating,
                                  ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 0,
                            top: 0,
                            child: RotatedBox(
                              key: const ValueKey(
                                  'player-performance-axis-label'),
                              quarterTurns: 1,
                              child: Text(axisLabel, style: axisLabelStyle),
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
                    key: const ValueKey('player-performance-round-label'),
                    style: Body2_b.style,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _tooltip(
    Size chartSize,
    double viewportWidth,
    PlayerPerformancePoint point,
    RoundChartWindow roundWindow,
    bool isDark,
    double minRating,
    double maxRating,
  ) {
    const pointRadius = 4.0;
    const pointToTooltipGap = 4.0;
    const anchorGap = pointRadius + pointToTooltipGap;
    const contentGap = 8.0;
    const tooltipPadding = 8.0;
    final textStyle = Eyebrow.style.copyWith(fontWeight: FontWeight.w700);
    final roundLabel = formatRoundLabel(
        roundName: '${point.round}', locale: Localizations.localeOf(context))!;
    final ratingLabel = tr(context, 'Rating {rating}', {
      'rating': playerNumber(point.rating),
    });
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final roundPainter = TextPainter(
      text: TextSpan(text: roundLabel, style: textStyle),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final ratingPainter = TextPainter(
      text: TextSpan(text: ratingLabel, style: textStyle),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final tooltipWidth = math.min(
      viewportWidth,
      roundPainter.width +
          ratingPainter.width +
          contentGap +
          tooltipPadding * 2 +
          4,
    );
    final tooltipHeight = math.max(roundPainter.height, ratingPainter.height) +
        tooltipPadding * 2 +
        2;
    final anchorY = chartSize.height *
        (1 - (point.rating! - minRating) / (maxRating - minRating));
    final left = roundChartTooltipLeft(
      roundWindow: roundWindow,
      round: point.round,
      viewportWidth: viewportWidth,
      tooltipWidth: tooltipWidth,
      gap: anchorGap,
      preferLeft: false,
    );
    final top = (anchorY - tooltipHeight / 2)
        .clamp(0.0, math.max(0.0, chartSize.height - tooltipHeight))
        .toDouble();
    final foreground = isDark ? AppPalette.white : AppPalette.black;

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      height: tooltipHeight,
      child: Container(
        key: const ValueKey('player-performance-tooltip'),
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
                ratingLabel,
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

class _PlayerPerformanceSelectionPainter extends CustomPainter {
  const _PlayerPerformanceSelectionPainter({
    required this.round,
    required this.roundWindow,
    required this.rating,
    required this.minRating,
    required this.maxRating,
    required this.color,
  });

  final int round;
  final RoundChartWindow roundWindow;
  final double rating;
  final double minRating;
  final double maxRating;
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
        Offset(x, math.min(y + dashHeight, guideBottom)),
        guidePaint,
      );
    }
    final pointY =
        size.height * (1 - (rating - minRating) / (maxRating - minRating));
    canvas.drawCircle(Offset(x, pointY), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PlayerPerformanceSelectionPainter oldDelegate) =>
      oldDelegate.round != round ||
      oldDelegate.roundWindow.firstRound != roundWindow.firstRound ||
      oldDelegate.rating != rating ||
      oldDelegate.minRating != minRating ||
      oldDelegate.maxRating != maxRating ||
      oldDelegate.color != color;
}
