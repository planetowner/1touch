part of 'match_info_features.dart';

class MomentumChart extends StatefulWidget {
  const MomentumChart({
    super.key,
    this.values = _defaultMomentum,
    this.homeColor = const Color(0xFFFF5C5C),
    this.awayColor = Colors.white,
    this.animate = false,
  });

  final List<double> values;
  final Color homeColor;
  final Color awayColor;
  final bool animate;

  // Mock per-5-minute momentum series, -100..100 (negative = away team
  // dominance, positive = home team), 0' through 90' inclusive.
  static const List<double> _defaultMomentum = [
    -40,
    -70,
    -50,
    -55,
    -35,
    10,
    45,
    75,
    90,
    60,
    40,
    55,
    30,
    0,
    -20,
    -5,
    25,
    40,
    30,
  ];

  @override
  State<MomentumChart> createState() => _MomentumChartState();
}

class _MomentumChartState extends State<MomentumChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: matchMotionDurationMs),
    value: widget.animate ? 0 : 1,
  );
  late final Animation<double> _easedReveal =
      _reveal.drive(CurveTween(curve: matchMotionCurve));
  final List<ScrollPosition> _scrollPositions = [];
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startIfVisible());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final position in _scrollPositions) {
      position.removeListener(_startIfVisible);
    }
    _scrollPositions.clear();
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final position = (element.state as ScrollableState).position;
        _scrollPositions.add(position);
        position.addListener(_startIfVisible);
      }
      return true;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _reveal.value = 1;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startIfVisible());
    }
  }

  @override
  void didUpdateWidget(MomentumChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _reveal.value = 1;
    } else if (!oldWidget.animate) {
      _started = false;
      _reveal.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startIfVisible());
    }
  }

  void _startIfVisible() {
    if (!mounted || _started || !widget.animate) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final height = MediaQuery.sizeOf(context).height;
    if (top >= height || top + box.size.height <= 0) return;
    _started = true;
    _reveal.forward();
  }

  @override
  void dispose() {
    for (final position in _scrollPositions) {
      position.removeListener(_startIfVisible);
    }
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, "MOMENTUM"), style: Body2_b.style),
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('match-momentum-card'),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkGrey : AppPalette.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: appCardShadows(context),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 140,
                width: double.infinity,
                child: CustomPaint(
                  painter: _MomentumPainter(
                    widget.values,
                    foreground,
                    homeColor: widget.homeColor,
                    awayColor: widget.awayColor,
                    reveal: _easedReveal,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("0’",
                      style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  Text("45’",
                      style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  Text("90’",
                      style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MomentumPainter extends CustomPainter {
  final List<double> values;
  final Color neutralColor;
  final Color homeColor;
  final Color awayColor;
  final Animation<double> reveal;

  const _MomentumPainter(
    this.values,
    this.neutralColor, {
    this.homeColor = const Color(0xFFFF5C5C),
    this.awayColor = Colors.white,
    required this.reveal,
  }) : super(repaint: reveal);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final maxAbs = values.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);
    final centerY = size.height / 2;
    final scaleY = maxAbs == 0 ? 1.0 : (size.height / 2 - 4) / maxAbs;

    Offset pointAt(int i) {
      final x = size.width * i / (values.length - 1);
      final y = centerY - values[i] * scaleY;
      return Offset(x, y);
    }

    final points = List.generate(values.length, pointAt);

    _drawDashedLine(canvas, Offset(0, centerY), Offset(size.width, centerY),
        neutralColor.withValues(alpha: 0.3));
    final midX = size.width / 2;
    _drawDashedLine(canvas, Offset(midX, 0), Offset(midX, size.height),
        neutralColor.withValues(alpha: 0.3));

    canvas.save();
    canvas
        .clipRect(Rect.fromLTWH(0, 0, size.width * reveal.value, size.height));

    final abovePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          homeColor.withValues(alpha: 0.70),
          homeColor.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTRB(0, 0, size.width, centerY));
    final belowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          awayColor.withValues(alpha: 0),
          awayColor.withValues(alpha: 0.33),
        ],
      ).createShader(Rect.fromLTRB(0, centerY, size.width, size.height));

    for (var i = 0; i < points.length - 1; i++) {
      _fillSegment(
          canvas, points[i], points[i + 1], centerY, abovePaint, belowPaint);
    }

    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    // Keep the white graph line visible on the light-mode card too.
    canvas.drawPath(
      path,
      Paint()
        ..color = neutralColor.withValues(alpha: 0.25)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(path, linePaint);
    canvas.restore();
  }

  // Fills the trapezoid between [a]→[b] and the zero baseline, splitting at
  // the exact zero-crossing when the segment switches sides so the fill
  // boundary tracks the dashed baseline precisely rather than overshooting.
  void _fillSegment(Canvas canvas, Offset a, Offset b, double centerY,
      Paint abovePaint, Paint belowPaint) {
    final aAbove = a.dy <= centerY;
    final bAbove = b.dy <= centerY;

    if (aAbove == bAbove) {
      final path = Path()
        ..moveTo(a.dx, centerY)
        ..lineTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(b.dx, centerY)
        ..close();
      canvas.drawPath(path, aAbove ? abovePaint : belowPaint);
      return;
    }

    final t = (centerY - a.dy) / (b.dy - a.dy);
    final cross = Offset(a.dx + (b.dx - a.dx) * t, centerY);

    canvas.drawPath(
      Path()
        ..moveTo(a.dx, centerY)
        ..lineTo(a.dx, a.dy)
        ..lineTo(cross.dx, cross.dy)
        ..close(),
      aAbove ? abovePaint : belowPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cross.dx, cross.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(b.dx, centerY)
        ..close(),
      bAbove ? abovePaint : belowPaint,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Color color) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final totalLength = (end - start).distance;
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

  @override
  bool shouldRepaint(covariant _MomentumPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.neutralColor != neutralColor ||
      oldDelegate.homeColor != homeColor ||
      oldDelegate.awayColor != awayColor ||
      oldDelegate.reveal != reveal;
}
