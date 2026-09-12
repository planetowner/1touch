import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_detail.dart';
import 'package:onetouch/features/MatchInfoFeatures.dart';

class AnalysisTab extends StatefulWidget {
  final Fixture fixture;
  final FixtureDetail? detail;

  const AnalysisTab({
    super.key,
    required this.fixture,
    this.detail,
  });

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab> {
  bool showFCB = true; // default view
  bool get isLive => false;

  //   Mock data — replace with real API models
  final List<Map<String, dynamic>> _goalEvents = const [
    {'player': 'Lewandowski', 'minute': "23'", 'team': 'home'},
    {'player': 'Lewandowski', 'minute': "67'", 'team': 'home'},
    {'player': 'Yamal', 'minute': "45'", 'team': 'home'},
    {'player': 'Yamal', 'minute': "45'+7'", 'team': 'home'},
    {'player': 'Yamal', 'minute': "90'+9'", 'team': 'home'},
    {'player': 'Dovbyk', 'minute': "45'", 'team': 'away'},
    {'player': 'Gutiérrez', 'minute': "78'", 'team': 'away', 'type': 'redCard'},
  ];

  //   Shot map: normalized (0..1) origin of each shot. y=0 is the halfway
  // line edge of the diagram, y=1 is the goal line — matches FCB's 10
  // shots / GIR's 6 shots already shown in the stat rows below.
  static const List<Offset> _shotsFcb = [
    Offset(0.50, 0.06),
    Offset(0.36, 0.18),
    Offset(0.64, 0.16),
    Offset(0.28, 0.34),
    Offset(0.72, 0.32),
    Offset(0.46, 0.38),
    Offset(0.58, 0.42),
    Offset(0.40, 0.55),
    Offset(0.60, 0.52),
    Offset(0.50, 0.62),
  ];
  static const List<Offset> _shotsGir = [
    Offset(0.46, 0.14),
    Offset(0.32, 0.30),
    Offset(0.66, 0.26),
    Offset(0.52, 0.42),
    Offset(0.40, 0.56),
    Offset(0.58, 0.50),
  ];

  //   Progression: % of progressive actions through each lane (top/middle/
  // bottom thirds of the pitch, attacking left → right).
  static const List<double> _progressionFcb = [22, 33, 45];
  static const List<double> _progressionGir = [40, 35, 25];

  //   Pressure: normalized (0..1) location of each pressure/duel event.
  // FCB presses high up the pitch (small x = near GIR's goal); GIR sits in
  // a deeper block (large x = near their own goal) — same two vertical
  // press-trigger bands for both, just where the action actually happens.
  static const List<double> _pressureBands = [0.32, 0.68];
  static const List<Offset> _pressureFcb = [
    Offset(0.30, 0.20),
    Offset(0.68, 0.24),
    Offset(0.50, 0.32),
    Offset(0.22, 0.45),
    Offset(0.78, 0.48),
    Offset(0.50, 0.55),
  ];
  static const List<Offset> _pressureGir = [
    Offset(0.32, 0.78),
    Offset(0.70, 0.74),
    Offset(0.50, 0.68),
    Offset(0.24, 0.55),
    Offset(0.76, 0.52),
    Offset(0.50, 0.45),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          _buildScoreHeader(),
          MatchEventsSection(events: _goalEvents),
          if (widget.detail?.expectedGoals case final expectedGoals?)
            _buildXGSection(expectedGoals),
          const SizedBox(height: 48),
          const MomentumChart(),
          const SizedBox(height: 48),
          _buildAttackBlock(),
          const SizedBox(height: 48),
          _buildPossessionBlock(),
          const SizedBox(height: 48),
          _buildProgressionBlock(),
          const SizedBox(height: 48),
          _buildPressureBlock(),
          const SizedBox(height: 48),
          _buildDefenseBlock(),
          const SizedBox(height: 140),
        ],
      ),
    );
  }

  Widget _buildScoreHeader() {
    final home = teamRepository.findByIdOrUnknown(widget.fixture.homeTeamId);
    final away = teamRepository.findByIdOrUnknown(widget.fixture.awayTeamId);

    return MatchScoreHeader(
      homeLogoAsset: home.imagePath ?? '',
      awayLogoAsset: away.imagePath ?? '',
      homeTeamId: home.teamId,
      awayTeamId: away.teamId,
      homeTeamName: home.name,
      awayTeamName: away.name,
      homeScore: widget.fixture.homeScore?.toString() ?? '#',
      awayScore: widget.fixture.awayScore?.toString() ?? '#',
      statusLabel: isLive ? '42:02' : 'Final',
      roundLabel: widget.fixture.roundName,
    );
  }

  Widget _buildXGSection(FixtureExpectedGoals expectedGoals) {
    return SizedBox(
      key: const ValueKey('match-analysis-xg'),
      width: double.infinity,
      child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                color: const Color(0xFFFF5B5B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    expectedGoals.homeXg.toStringAsFixed(2),
                    style: Body2_b.style.copyWith(color: AppPalette.white),
                  ),
                ],
              ),
            ),
            Text('XG', textAlign: TextAlign.center, style: Body2_b.style),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(expectedGoals.awayXg.toStringAsFixed(2),
                      style: Body2_b.style.copyWith(color: Colors.black)),
                ],
              ),
            ),
          ]),
    );
  }

  static const Color _fcbColor = Color(0xFFD82457);

  Widget _buildAttackBlock() {
    final selectedTeam = showFCB ? 'FCB' : 'GIR';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("ATTACK", style: Body2_b.style),
          const SizedBox(height: 16),
          Container(
            key: const ValueKey('match-analysis-attack-card'),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? AppPalette.darkGrey : AppPalette.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Toggle button styled like your IN/OUT toggle
                _buildTeamToggle(),
                const SizedBox(height: 24),
                // Shot map
                ShotMapDiagram(
                  shots: showFCB ? _shotsFcb : _shotsGir,
                  color: showFCB ? _fcbColor : foreground,
                  lineColor: foreground.withValues(alpha: 0.30),
                ),

                const SizedBox(height: 24),

                // Stats (stats don't change — only color)
                _buildStatRow("Shots", "10", "6", selectedTeam),
                _buildStatRow("Shots on Target", "6", "2", selectedTeam),
                _buildStatRow("Key Passes", "7", "3", selectedTeam),
                _buildStatRow(
                    "Passes into Penalty Area", "25", "11", selectedTeam),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPossessionBlock() {
    final selectedTeam = showFCB ? 'FCB' : 'GIR';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("POSSESSION", style: Body2_b.style),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppPalette.darkGrey : AppPalette.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildTeamToggle(), // Reuse the same toggle widget
                const SizedBox(height: 24),
                _buildStatRow("Ball Possession", "63%", "37%", selectedTeam),
                _buildStatRow("Pass Accuracy", "89%", "83%", selectedTeam),
                _buildStatRow("Touches", "690", "503", selectedTeam),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressionBlock() {
    final selectedTeam = showFCB ? 'FCB' : 'GIR';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("PROGRESSION", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkGrey : AppPalette.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildTeamToggle(),
              const SizedBox(height: 24),
              ProgressionDiagram(
                lanePercents: showFCB ? _progressionFcb : _progressionGir,
                color: showFCB ? _fcbColor : foreground,
                lineColor: foreground.withValues(alpha: 0.30),
                labelColor: foreground,
              ),
              const SizedBox(height: 24),
              _buildStatRow("Progressive Passes", "51", "27", selectedTeam),
              _buildStatRow(
                  "Carries into Final Third", "13", "5", selectedTeam),
              _buildStatRow("Crosses", "22", "9", selectedTeam),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPressureBlock() {
    final selectedTeam = showFCB ? 'FCB' : 'GIR';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("PRESSURE", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkGrey : AppPalette.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildTeamToggle(),
              const SizedBox(height: 24),
              PressureDiagram(
                events: showFCB ? _pressureFcb : _pressureGir,
                bands: _pressureBands,
                lineColor: foreground.withValues(alpha: 0.30),
                dotColor: foreground,
              ),
              const SizedBox(height: 24),
              _buildStatRow("Pressures", "123", "98", selectedTeam),
              _buildStatRow("Successful Pressures", "75", "56", selectedTeam),
              _buildStatRow("Blocks", "21", "17", selectedTeam),
              _buildStatRow("Clearances", "15", "19", selectedTeam),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeamToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final selectedSurface = isDark ? AppPalette.lightGrey : AppPalette.black;
    final unselectedSurface = isDark ? Colors.black : AppPalette.white;
    const selectedForeground = AppPalette.white;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => showFCB = true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: showFCB ? selectedSurface : unselectedSurface,
                border: Border.all(
                  color: isDark
                      ? AppPalette.lightGrey
                      : AppColors.of(context).divider,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                "FCB",
                style: Body2_b.style.copyWith(
                  color: showFCB ? selectedForeground : foreground,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => showFCB = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: !showFCB ? selectedSurface : unselectedSurface,
                border: Border.all(
                  color: isDark
                      ? AppPalette.lightGrey
                      : AppColors.of(context).divider,
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                "GIR",
                style: Body2_b.style.copyWith(
                  color: !showFCB ? selectedForeground : foreground,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(
      String label, String fcb, String grn, String selectedTeam) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    final mutedForeground = AppColors.of(context).mutedForeground;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              fcb,
              style: Heading5.style.copyWith(
                color: selectedTeam == 'FCB' ? foreground : mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: Body1.style,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              grn,
              style: Heading5.style.copyWith(
                color: selectedTeam == 'GIR' ? foreground : mutedForeground,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefenseBlock() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedForeground = AppColors.of(context).mutedForeground;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("DEFENSE", style: Body2_b.style),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppPalette.darkGrey : AppPalette.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // GA Row
                _statBoxRow(leftValue: "2", label: "GA", rightValue: "1"),
                const SizedBox(height: 16),
                // xGA Row
                _statBoxRow(leftValue: "0.8", label: "xGA", rightValue: "2.5"),
                const SizedBox(height: 24),

                // Stat rows
                ...[
                  ["10", "6", "Tackles (Success Rate)"],
                  ["6", "2", "Interceptions"],
                  ["7", "3", "Blocks"],
                  ["7", "3", "Duels (Win Rate)"],
                  ["7", "3", "Error"],
                ].map((row) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(row[0], style: Heading5.style),
                          ),
                          Expanded(
                            child: Text(
                              row[2],
                              style: Body1.style,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: Text(
                              row[1],
                              style: Heading5.style
                                  .copyWith(color: mutedForeground),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBoxRow({
    required String leftValue,
    required String label,
    required String rightValue,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left stat box (e.g. 2)
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF5B5B),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            leftValue,
            style: Heading4.style.copyWith(color: Colors.white),
          ),
        ),

        // Center label (e.g. GA)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Text(
            label,
            style: Body2_b.style,
          ),
        ),

        // Right stat box (e.g. 1)
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          alignment: Alignment.topRight,
          decoration: BoxDecoration(
            color: isDark ? Colors.white : AppPalette.lightGreyBox,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            rightValue,
            style: Heading4.style.copyWith(color: Colors.black),
          ),
        ),
      ],
    );
  }
}

//   Tactical diagram painters
// All three draw onto a normalized 0..1 coordinate space mapped to the
// painter's actual size, so they scale cleanly with whatever box they're
// given (an AspectRatio at the call site).

Paint _pitchLinePaint(Color color) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1;

void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
  const dashWidth = 4.0;
  const dashSpace = 4.0;
  final totalLength = (end - start).distance;
  if (totalLength == 0) return;
  final dx = (end.dx - start.dx) / totalLength;
  final dy = (end.dy - start.dy) / totalLength;
  var distance = 0.0;
  while (distance < totalLength) {
    final segEnd = (distance + dashWidth).clamp(0, totalLength);
    canvas.drawLine(
      Offset(start.dx + dx * distance, start.dy + dy * distance),
      Offset(start.dx + dx * segEnd, start.dy + dy * segEnd),
      paint,
    );
    distance += dashWidth + dashSpace;
  }
}

// Half-pitch shot map: goal along the bottom edge, shots fan in via dotted
// lines converging on the goal mouth.
class ShotMapDiagram extends StatelessWidget {
  final List<Offset> shots;
  final Color color;
  final Color lineColor;
  const ShotMapDiagram({
    super.key,
    required this.shots,
    required this.color,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.2,
      child: CustomPaint(painter: _ShotMapPainter(shots, color, lineColor)),
    );
  }
}

class _ShotMapPainter extends CustomPainter {
  final List<Offset> shots;
  final Color color;
  final Color lineColor;
  const _ShotMapPainter(this.shots, this.color, this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    final line = _pitchLinePaint(lineColor);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), line);

    // Penalty box + 6-yard box, open at the goal line (bottom edge).
    final boxW = size.width * 0.62;
    final boxH = size.height * 0.40;
    canvas.drawRect(
      Rect.fromLTWH((size.width - boxW) / 2, size.height - boxH, boxW, boxH),
      line,
    );
    final smallW = size.width * 0.30;
    final smallH = size.height * 0.16;
    canvas.drawRect(
      Rect.fromLTWH(
          (size.width - smallW) / 2, size.height - smallH, smallW, smallH),
      line,
    );
    // Penalty arc ("the D") — circle centered on the penalty spot, drawing
    // only the slice that pokes above the box edge so its ends sit exactly
    // on the box line (real-pitch proportions: spot 11m/16.5m deep, r 9.15m).
    final spot = Offset(size.width / 2, size.height - boxH * 2 / 3);
    final dRadius = boxH * 0.555;
    canvas.drawArc(
      Rect.fromCircle(center: spot, radius: dRadius),
      math.pi + 0.6435,
      math.pi - 1.287,
      false,
      line,
    );
    // Center-circle arc poking in from the halfway line at the top.
    canvas.drawArc(
      Rect.fromCircle(
          center: Offset(size.width / 2, 0), radius: size.width * 0.3),
      0,
      math.pi,
      false,
      line,
    );

    final goalMouth = Offset(size.width / 2, size.height);
    final dashPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final dotPaint = Paint()..color = color;

    for (final shot in shots) {
      final p = Offset(shot.dx * size.width, shot.dy * size.height);
      _drawDashedLine(canvas, p, goalMouth, dashPaint);
      canvas.drawCircle(p, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ShotMapPainter oldDelegate) =>
      oldDelegate.shots != shots ||
      oldDelegate.color != color ||
      oldDelegate.lineColor != lineColor;
}

// Full-pitch progression diagram: 3 horizontal lanes, each an arrow sized
// and labeled by how much of that lane's play moved the ball forward.
class ProgressionDiagram extends StatelessWidget {
  final List<double> lanePercents; // [top, middle, bottom], 0..100
  final Color color;
  final Color lineColor;
  final Color labelColor;
  const ProgressionDiagram({
    super.key,
    required this.lanePercents,
    required this.color,
    required this.lineColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.6,
      child: CustomPaint(
        painter: _ProgressionPainter(
          lanePercents,
          color,
          lineColor,
          labelColor,
        ),
      ),
    );
  }
}

class _ProgressionPainter extends CustomPainter {
  final List<double> lanePercents;
  final Color color;
  final Color lineColor;
  final Color labelColor;
  const _ProgressionPainter(
    this.lanePercents,
    this.color,
    this.lineColor,
    this.labelColor,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final line = _pitchLinePaint(lineColor);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), line);
    canvas.drawLine(
        Offset(size.width / 3, 0), Offset(size.width / 3, size.height), line);
    canvas.drawLine(Offset(size.width * 2 / 3, 0),
        Offset(size.width * 2 / 3, size.height), line);
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.height * 0.22, line);

    final goalW = size.width * 0.04;
    final goalH = size.height * 0.36;
    canvas.drawRect(
        Rect.fromLTWH(0, (size.height - goalH) / 2, goalW, goalH), line);
    canvas.drawRect(
        Rect.fromLTWH(
            size.width - goalW, (size.height - goalH) / 2, goalW, goalH),
        line);

    final laneHeight = size.height / 3;
    for (var i = 0; i < 3 && i < lanePercents.length; i++) {
      final midY = laneHeight * i + laneHeight / 2;
      final pct = (lanePercents[i] / 100).clamp(0.0, 1.0);
      final arrowLen = size.width * 0.18 + size.width * 0.6 * pct;
      _drawArrow(
        canvas,
        start: Offset(size.width * 0.08, midY),
        length: arrowLen,
        thickness: 10 + 14 * pct,
        color: color.withValues(alpha: 0.35 + 0.5 * pct),
      );
      _drawLabel(
        canvas,
        '${lanePercents[i].round()}%',
        Offset(size.width * 0.08 + arrowLen / 2, midY),
      );
    }
  }

  void _drawArrow(Canvas canvas,
      {required Offset start,
      required double length,
      required double thickness,
      required Color color}) {
    final paint = Paint()..color = color;
    final shaftEnd = start.dx + length * 0.78;
    final tipEnd = start.dx + length;
    final path = Path()
      ..moveTo(start.dx, start.dy - thickness / 2)
      ..lineTo(shaftEnd, start.dy - thickness / 2)
      ..lineTo(shaftEnd, start.dy - thickness)
      ..lineTo(tipEnd, start.dy)
      ..lineTo(shaftEnd, start.dy + thickness)
      ..lineTo(shaftEnd, start.dy + thickness / 2)
      ..lineTo(start.dx, start.dy + thickness / 2)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawLabel(Canvas canvas, String text, Offset center) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: labelColor,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
        canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ProgressionPainter oldDelegate) =>
      oldDelegate.lanePercents != lanePercents ||
      oldDelegate.color != color ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.labelColor != labelColor;
}

// Full-pitch pressure diagram: two vertical press-trigger bands plus dots
// for where the team's duels/recoveries actually happened.
class PressureDiagram extends StatelessWidget {
  final List<Offset> events;
  final List<double> bands;
  final Color lineColor;
  final Color dotColor;
  const PressureDiagram({
    super.key,
    required this.events,
    required this.bands,
    required this.lineColor,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.6,
      child: CustomPaint(
        painter: _PressurePainter(events, bands, lineColor, dotColor),
      ),
    );
  }
}

class _PressurePainter extends CustomPainter {
  final List<Offset> events;
  final List<double> bands;
  final Color lineColor;
  final Color dotColor;
  const _PressurePainter(
    this.events,
    this.bands,
    this.lineColor,
    this.dotColor,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final bandPaint = Paint()
      ..color = const Color(0xFFB23A3A).withValues(alpha: 0.45);
    final bandWidth = size.width * 0.1;
    for (final bx in bands) {
      canvas.drawRect(
        Rect.fromLTWH(
            bx * size.width - bandWidth / 2, 0, bandWidth, size.height),
        bandPaint,
      );
    }

    final line = _pitchLinePaint(lineColor);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), line);
    canvas.drawLine(
        Offset(size.width / 2, 0), Offset(size.width / 2, size.height), line);
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.height * 0.22, line);

    final goalW = size.width * 0.04;
    final goalH = size.height * 0.36;
    canvas.drawRect(
        Rect.fromLTWH(0, (size.height - goalH) / 2, goalW, goalH), line);
    canvas.drawRect(
        Rect.fromLTWH(
            size.width - goalW, (size.height - goalH) / 2, goalW, goalH),
        line);

    final dotPaint = Paint()..color = dotColor;
    for (final e in events) {
      canvas.drawCircle(
          Offset(e.dx * size.width, e.dy * size.height), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PressurePainter oldDelegate) =>
      oldDelegate.events != events ||
      oldDelegate.bands != bands ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.dotColor != dotColor;
}
