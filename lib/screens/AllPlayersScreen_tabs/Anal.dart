import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/models/player.dart'; // assuming Player model lives here
import 'package:onetouch/core/stylesheet_dark.dart';
import 'dart:math' show cos, sin;

class AnalysisTab extends StatefulWidget {
  final Player player;

  const AnalysisTab({super.key, required this.player});

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab> {
  String _selectedSeason = "25/26";

  List<String> get _seasons {
    final seasons = <String>{'25/26'};
    for (final period in widget.player.clubHistory) {
      seasons.add(period.toSeason);
      seasons.add(period.fromSeason);
    }
    return seasons.toList();
  }

  List<double> get _performanceRatings {
    final rating = widget.player.seasonStats.rating;
    return [
      rating - 0.5,
      rating - 0.2,
      rating + 0.1,
      rating - 0.3,
      rating + 0.4,
      rating,
      rating + 0.2,
      rating - 0.1,
      rating + 0.5,
      rating + 0.3,
      rating - 0.4,
      rating + 0.1,
      rating + 0.6,
      rating + 0.2,
    ].map((value) => value.clamp(0.0, 10.0)).toList();
  }

  // Round currently highlighted by the marker/tooltip. Defaults to Round 8 and
  // follows the user's finger as they drag across the line.
  int _selectedRoundIndex = 7;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('player-analysis-scroll'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeasonDropdown(),
          const SizedBox(height: 32),
          _buildTopStatsBlock(),
          const SizedBox(height: 32),
          _buildInfluenceBlock(),
          const SizedBox(height: 48),
          _buildAttributesBlockPlaceholder(),
          const SizedBox(height: 48),
          _buildPerformanceChart(),
          const SizedBox(height: 144),
        ],
      ),
    );
  }

  Widget _buildSeasonDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF3D3D3D) : AppPalette.white;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Container(
      key: const ValueKey('player-analysis-season-filter'),
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSeason,
          isExpanded: true,
          dropdownColor: surface,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: foreground,
            size: 24,
          ),
          style: Body2_b.style.copyWith(color: foreground),
          onChanged: (value) {
            if (value != null) setState(() => _selectedSeason = value);
          },
          items: _seasons.map((season) {
            return DropdownMenuItem(
              value: season,
              child: Text(
                "$season SEASON".toUpperCase(),
                style: Body2_b.style.copyWith(color: foreground),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTopStatsBlock() {
    final stats = widget.player.seasonStats;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF3D3D3D) : AppPalette.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("TOP STATS", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('player-top-stats-card'),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _statBox(
                  value: '${stats.goals}',
                  label: "Goals",
                  rank: '#${(100 - widget.player.rankingScore).round() + 1}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox(
                  value: '${stats.assists}',
                  label: "Assists",
                  rank: '#${(105 - widget.player.rankingScore).round() + 1}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox(
                  value: '${(stats.passAccuracy * 100).round()}%',
                  label: "Pass Accuracy",
                  rank: '#${(110 - widget.player.rankingScore).round() + 1}',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statBox({
    required String value,
    required String label,
    required String rank,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appColors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Number box — full width, more vertical padding
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkGrey : appColors.subtleBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: Heading2.style,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        // Label
        SizedBox(
          height: 20,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: Body1.style,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Rank badge — centered
        Align(
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.black,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              rank,
              style: Body1.style.copyWith(color: AppPalette.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfluenceBlock() {
    final stats = widget.player.seasonStats;
    final startingRate =
        stats.appearances == 0 ? 0 : stats.starts / stats.appearances;
    final goalContribution = stats.goals + stats.assists;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("INFLUENCE", style: Body2_b.style),
        const SizedBox(height: 16),
        GridView.count(
          padding: EdgeInsets.zero,
          primary: false,
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1,
          children: [
            _influenceCard(
              "Starting Rate",
              "${(startingRate * 100).round()}",
              "%",
            ),
            _influenceCard(
              "Win Rate with\n${widget.player.shortName}",
              "${(52 + widget.player.rankingScore % 30).round()}",
              "%",
            ),
            _influenceCard("Minutes Played\nPer Game", "84", "Min."),
            _influenceCard(
              "Goal\nContributions",
              "$goalContribution",
              "",
            ),
          ],
        ),
      ],
    );
  }

  Widget _influenceCard(String label, String value, String suffix) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkGrey : AppPalette.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(label, style: Body1.style),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(value, style: Heading1.style),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(suffix, style: Heading4.style),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributesBlockPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appColors = AppColors.of(context);
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("ATTRIBUTES", style: Body2_b.style),
            Icon(Icons.chevron_right, color: foreground),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('player-attributes-card'),
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkGrey : AppPalette.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            height: 260,
            child: CustomPaint(
              painter: RadarChartPainter(
                values: widget.player.radarValues,
                gridColor: appColors.divider,
                labelColor: appColors.mutedForeground,
                labels: const [
                  "Pace",
                  "Shooting",
                  "Passing",
                  "Defending",
                  "Physical",
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceChart() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appColors = AppColors.of(context);
    final spots = [
      for (int i = 0; i < _performanceRatings.length; i++)
        FlSpot((i + 1).toDouble(), _performanceRatings[i]),
    ];

    // Defined up front so it can be referenced by showingTooltipIndicators to
    // keep the tooltip/dot pinned to the selected round without an active touch.
    final lineBarData = LineChartBarData(
      spots: spots,
      color: const Color(0xFF5C92FF),
      barWidth: 2,
      isCurved: false,
      dotData: const FlDotData(show: false),
      showingIndicators: [_selectedRoundIndex],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("PERFORMANCE", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('player-performance-card'),
          width: double.infinity,
          height: 345,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkGrey : AppPalette.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    RotatedBox(
                      quarterTurns: 3,
                      child: Text("PERFORMANCE", style: Body2_b.style),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LineChart(
                        LineChartData(
                          minX: 1,
                          maxX: _performanceRatings.length.toDouble(),
                          minY: 0,
                          maxY: 10,
                          gridData: FlGridData(
                            drawVerticalLine: false,
                            horizontalInterval: 10 / 8,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: appColors.divider,
                              strokeWidth: 1,
                            ),
                          ),
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
                          // Full-height dashed marker at the selected round.
                          extraLinesData: ExtraLinesData(
                            verticalLines: [
                              VerticalLine(
                                x: (_selectedRoundIndex + 1).toDouble(),
                                color: appColors.mutedForeground,
                                strokeWidth: 1,
                                dashArray: const [4, 4],
                              ),
                            ],
                          ),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) => const Color(0xFF090A0A),
                              tooltipRoundedRadius: 6,
                              fitInsideHorizontally: true,
                              fitInsideVertically: true,
                              getTooltipItems: (touched) => touched
                                  .map(
                                    (spot) => LineTooltipItem(
                                      "Round ${spot.x.toInt()}   ",
                                      Eyebrow.style.copyWith(
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                      ),
                                      children: [
                                        TextSpan(
                                          text:
                                              "Rating ${spot.y.toStringAsFixed(1)}",
                                          style: Eyebrow.style.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                            getTouchedSpotIndicator: (bar, indexes) => indexes
                                .map(
                                  // The vertical guide is drawn via extraLines,
                                  // so hide the built-in indicator line and keep
                                  // only the dot on the point.
                                  (_) => TouchedSpotIndicatorData(
                                    const FlLine(color: Colors.transparent),
                                    FlDotData(
                                      getDotPainter: (_, __, ___, ____) =>
                                          FlDotCirclePainter(
                                        radius: 4,
                                        color: const Color(0xFF5C92FF),
                                        strokeWidth: 2,
                                        strokeColor: AppPalette.white,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            touchCallback: (event, response) {
                              final spot = response?.lineBarSpots?.first;
                              if (spot == null) return;
                              if (spot.spotIndex == _selectedRoundIndex) return;
                              setState(
                                  () => _selectedRoundIndex = spot.spotIndex);
                            },
                          ),
                          showingTooltipIndicators: [
                            ShowingTooltipIndicators([
                              LineBarSpot(
                                lineBarData,
                                0,
                                lineBarData.spots[_selectedRoundIndex],
                              ),
                            ]),
                          ],
                          lineBarsData: [lineBarData],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text("ROUND", style: Body2_b.style),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RadarChartPainter extends CustomPainter {
  final List<double> values; // 0.0 to 1.0
  final List<String> labels;
  final Color gridColor;
  final Color labelColor;

  RadarChartPainter({
    required this.values,
    required this.labels,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius =
        size.width < size.height ? size.width / 2 - 32 : size.height / 2 - 32;
    final int count = values.length;
    final double angleStep = (2 * 3.141592653589793) / count;
    // Start from top (- pi/2)
    const double startAngle = -3.141592653589793 / 2;

    // --- Grid rings ---
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const int rings = 4;
    for (int r = 1; r <= rings; r++) {
      final ringRadius = radius * r / rings;
      final path = Path();
      for (int i = 0; i < count; i++) {
        final angle = startAngle + i * angleStep;
        final x = center.dx + ringRadius * cos(angle);
        final y = center.dy + ringRadius * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // --- Axis lines ---
    final axisPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (int i = 0; i < count; i++) {
      final angle = startAngle + i * angleStep;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      canvas.drawLine(center, Offset(x, y), axisPaint);
    }

    // --- Filled polygon ---
    final fillPaint = Paint()
      ..color = const Color(0x405C92FF)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFF5C92FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final dataPath = Path();
    for (int i = 0; i < count; i++) {
      final angle = startAngle + i * angleStep;
      final r = radius * values[i];
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, strokePaint);

    // --- Labels ---
    for (int i = 0; i < count; i++) {
      final angle = startAngle + i * angleStep;
      final labelRadius = radius + 20;
      final x = center.dx + labelRadius * cos(angle);
      final y = center.dy + labelRadius * sin(angle);

      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: labelColor,
            fontSize: 11,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Center the label around the point
      tp.paint(
        canvas,
        Offset(x - tp.width / 2, y - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(RadarChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor;
}
