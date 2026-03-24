import 'package:flutter/material.dart';
import 'package:onetouch/data/playerdata.dart'; // assuming Player model lives here
import 'package:onetouch/core/stylesheet_dark.dart';
import 'dart:math' show cos, sin, sqrt;

class AnalysisTab extends StatefulWidget {
  final Player player;

  const AnalysisTab({super.key, required this.player});

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab> {
  String _selectedSeason = "22/23";

  final List<String> _seasons = ["22/23", "21/22", "20/21", "19/20"];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
          _buildPerformanceChartPlaceholder(),
          const SizedBox(height: 144),
        ],
      ),
    );
  }

  Widget _buildSeasonDropdown() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF3D3D3D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSeason,
          isExpanded: true,
          dropdownColor: const Color(0xFF3D3D3D),
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 24),
          style: Body2_b.style,
          onChanged: (value) {
            if (value != null) setState(() => _selectedSeason = value);
          },
          items: _seasons.map((season) {
            return DropdownMenuItem(
              value: season,
              child: Text(
                "${season} SEASON",
                style: Body2_b.style,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTopStatsBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("TOP STATS", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF3D3D3D),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _StatBox(value: "3", label: "Goals", rank: "#1")),
              const SizedBox(width: 8),
              Expanded(child: _StatBox(value: "5", label: "Assists", rank: "#3")),
              const SizedBox(width: 8),
              Expanded(child: _StatBox(value: "72%", label: "Shot Accuracy", rank: "#7")),
            ],
          ),
        ),
      ],
    );
  }

  Widget _StatBox({
    required String value,
    required String label,
    required String rank,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Number box — full width, more vertical padding
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF272828),
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
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(rank, style: Body1.style),
          ),
        ),
      ],
    );
  }

  Widget _buildInfluenceBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("INFLUENCE", style: Body2_b.style),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1,
          children: [
            _influenceCard("Starting Rate", "92", "%"),
            _influenceCard("Win Rate with\nHeungmin", "80", "%"),
            _influenceCard("Minutes Played\nPer Game", "80", "Min."),
            _influenceCard("Contribution to\nGoals", "18", "%"),
          ],
        ),
      ],
    );
  }

  Widget _influenceCard(String label, String value, String suffix) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF272828),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(label, style: Body1.style),
          const Spacer(),
          Row(
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
        ],
      ),
    );
  }

  Widget _buildAttributesBlockPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("ATTRIBUTES", style: Body2_b.style),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            height: 260,
            child: CustomPaint(
              painter: RadarChartPainter(
                values: [0.85, 0.75, 0.90, 0.70, 0.80], // 0.0 to 1.0
                labels: ["Dominance", "Dominance", "Dominance", "Dominance", "Dominance"],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceChartPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("PERFORMANCE", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 345,
            child: CustomPaint(
              painter: PerformanceChartPainter(
                dataPoints: [
                  0.1, 0.15, 0.2, 0.2, 0.3, 0.35, 0.4, 0.45,
                  0.6, 0.62, 0.75, 0.8, 0.85, 0.95
                ],
                selectedIndex: 7, // Round 8
                selectedLabel: "Round 8",
                selectedValue: "Rating 4.5",
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class RadarChartPainter extends CustomPainter {
  final List<double> values; // 0.0 to 1.0
  final List<String> labels;

  RadarChartPainter({required this.values, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width < size.height
        ? size.width / 2 - 32
        : size.height / 2 - 32;
    final int count = values.length;
    final double angleStep = (2 * 3.141592653589793) / count;
    // Start from top (- pi/2)
    const double startAngle = -3.141592653589793 / 2;

    // --- Grid rings ---
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
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
      ..color = Colors.white.withOpacity(0.1)
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
          style: const TextStyle(
            color: Colors.white54,
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
      oldDelegate.values != values;
}

class PerformanceChartPainter extends CustomPainter {
  final List<double> dataPoints; // 0.0 to 1.0
  final int selectedIndex;
  final String selectedLabel;
  final String selectedValue;

  PerformanceChartPainter({
    required this.dataPoints,
    required this.selectedIndex,
    required this.selectedLabel,
    required this.selectedValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPad = 32; // space for rotated "PERFORMANCE" label
    const double bottomPad = 24; // space for "ROUND" label
    const double topPad = 16;

    final chartLeft = leftPad;
    final chartRight = size.width;
    final chartTop = topPad;
    final chartBottom = size.height - bottomPad;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;

    // --- Horizontal grid lines ---
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;

    const double lineGap = 25;
    final int gridLines = (chartHeight / lineGap).floor();

    for (int i = 0; i <= gridLines; i++) {
      final y = chartTop + lineGap * i;
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
    }

    // --- Compute point positions ---
    List<Offset> points = [];
    for (int i = 0; i < dataPoints.length; i++) {
      final x = chartLeft + chartWidth * i / (dataPoints.length - 1);
      final y = chartBottom - chartHeight * dataPoints[i];
      points.add(Offset(x, y));
    }

    // --- Dashed vertical line at selected index ---
    final dashedPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1;

    final selectedX = points[selectedIndex].dx;
    _drawDashedLine(
      canvas,
      Offset(selectedX, chartTop),
      Offset(selectedX, chartBottom),
      dashedPaint,
      dashLength: 4,
      gapLength: 4,
    );

    // --- Pin at bottom of dashed line ---
    final pinPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(selectedX, chartBottom + 6), 4, pinPaint);

    // --- Blue line ---
    final linePaint = Paint()
      ..color = const Color(0xFF5C92FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path();
    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        linePath.moveTo(points[i].dx, points[i].dy);
      } else {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
    }
    canvas.drawPath(linePath, linePaint);

    // --- Dot at selected point ---
    canvas.drawCircle(
      points[selectedIndex],
      4,
      Paint()..color = const Color(0xFF5C92FF),
    );
    canvas.drawCircle(
      points[selectedIndex],
      2,
      Paint()..color = Colors.white,
    );

    // --- Tooltip ---
    final tooltipText = "$selectedLabel   $selectedValue";
    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: "$selectedLabel   ",
            style: Eyebrow.style.copyWith(color: Colors.white.withOpacity(0.5),)
          ),
          TextSpan(
            text: selectedValue,
            style: Eyebrow.style.copyWith(fontWeight: FontWeight.w700)
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final tooltipPadding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    final tooltipWidth = tp.width + tooltipPadding.horizontal;
    final tooltipHeight = tp.height + tooltipPadding.vertical;

    // Position tooltip to the right of the dashed line, slightly above center
    double tooltipX = selectedX + 8;
    double tooltipY = points[selectedIndex].dy - tooltipHeight / 2;

    // Clamp so it doesn't go off screen
    if (tooltipX + tooltipWidth > size.width) {
      tooltipX = selectedX - tooltipWidth - 8;
    }

    final tooltipRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tooltipX, tooltipY, tooltipWidth, tooltipHeight),
      const Radius.circular(6),
    );

    canvas.drawRRect(
      tooltipRect,
      Paint()..color = const Color(0xFF090A0A),
    );

    tp.paint(
      canvas,
      Offset(tooltipX + tooltipPadding.left, tooltipY + tooltipPadding.top),
    );

    // --- Rotated "PERFORMANCE" Y-axis label ---
    final perfPainter = TextPainter(
      text: const TextSpan(
        text: "PERFORMANCE",
        style: Body2_b.style
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(10, chartTop + chartHeight / 2 + perfPainter.width / 2);
    canvas.rotate(-3.141592653589793 / 2);
    perfPainter.paint(canvas, Offset.zero);
    canvas.restore();

    // --- "ROUND" X-axis label ---
    final roundPainter = TextPainter(
      text: const TextSpan(
        text: "ROUND",
        style: Body2_b.style
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    roundPainter.paint(
      canvas,
      Offset(
        chartRight - roundPainter.width,
        size.height - roundPainter.height,
      ),
    );
  }

  void _drawDashedLine(
      Canvas canvas,
      Offset start,
      Offset end,
      Paint paint, {
        double dashLength = 5,
        double gapLength = 4,
      }) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final totalLength = sqrt(dx * dx + dy * dy);
    final normX = dx / totalLength;
    final normY = dy / totalLength;

    double drawn = 0;
    bool drawing = true;

    while (drawn < totalLength) {
      final segLength =
      drawing ? dashLength : gapLength;
      final next = (drawn + segLength).clamp(0, totalLength).toDouble();

      if (drawing) {
        canvas.drawLine(
          Offset(start.dx + normX * drawn, start.dy + normY * drawn),
          Offset(start.dx + normX * next, start.dy + normY * next),
          paint,
        );
      }

      drawn = next;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(PerformanceChartPainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex ||
          oldDelegate.dataPoints != dataPoints;
}