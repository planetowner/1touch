part of 'player_comparison_screen.dart';

class RadarChart extends StatelessWidget {
  final List<double> values1, values2;
  final List<String> labels;
  final Color color1, color2;
  final Color gridColor, labelColor;

  const RadarChart({
    super.key,
    required this.values1,
    required this.values2,
    required this.labels,
    required this.color1,
    required this.color2,
    this.gridColor = const Color(0x4DFFFFFF),
    this.labelColor = Colors.white,
  })  : assert(values1.length == _RadarPainter.axisCount),
        assert(values2.length == _RadarPainter.axisCount),
        assert(labels.length == _RadarPainter.axisCount);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RadarPainter(
        values1: values1,
        values2: values2,
        labels: labels,
        color1: color1,
        color2: color2,
        gridColor: gridColor,
        labelColor: labelColor,
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<double> values1, values2;
  final List<String> labels;
  final Color color1, color2;
  final Color gridColor, labelColor;

  static const int axisCount = 5;

  // Coordinates are normalized from the supplied 345 x 238 reference.
  static const Offset _center = Offset(172.86 / 345, 117 / 238);
  static const List<Offset> _outerVertices = [
    Offset(172.762 / 345, 24.4663 / 238),
    Offset(270.588 / 345, 95.2007 / 238),
    Offset(233.223 / 345, 209.65 / 238),
    Offset(112.301 / 345, 209.65 / 238),
    Offset(74.9346 / 345, 95.2007 / 238),
  ];
  static const List<Offset> _labelAnchors = [
    Offset(172.5 / 345, 7.5 / 238),
    Offset(310 / 345, 95 / 238),
    Offset(263 / 345, 227.5 / 238),
    Offset(85 / 345, 227.5 / 238),
    Offset(35.5 / 345, 95 / 238),
  ];

  _RadarPainter({
    required this.values1,
    required this.values2,
    required this.labels,
    required this.color1,
    required this.color2,
    required this.gridColor,
    required this.labelColor,
  });

  Offset _scaledPoint(Offset point, Size size) {
    return Offset(point.dx * size.width, point.dy * size.height);
  }

  Path _shape(Offset center, List<Offset> vertices, double scale) {
    final path = Path();
    for (int index = 0; index < axisCount; index++) {
      final point = Offset.lerp(center, vertices[index], scale)!;
      index == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  Path _valueShape(
    Offset center,
    List<Offset> vertices,
    List<double> values,
  ) {
    final path = Path();
    for (int index = 0; index < axisCount; index++) {
      final point = Offset.lerp(
        center,
        vertices[index],
        values[index].clamp(0.0, 1.0),
      )!;
      index == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = _scaledPoint(_center, size);
    final vertices = _outerVertices
        .map((point) => _scaledPoint(point, size))
        .toList(growable: false);

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int level = 1; level <= 5; level++) {
      canvas.drawPath(_shape(center, vertices, level / 5), gridPaint);
    }
    for (final vertex in vertices) {
      canvas.drawLine(center, vertex, gridPaint);
    }

    _drawValues(canvas, center, vertices, values1, color1);
    _drawValues(canvas, center, vertices, values2, color2);
    _drawLabels(canvas, size);
  }

  void _drawValues(
    Canvas canvas,
    Offset center,
    List<Offset> vertices,
    List<double> values,
    Color color,
  ) {
    final shape = _valueShape(center, vertices, values);
    canvas.drawPath(
      shape,
      Paint()
        ..color = color.withValues(alpha: 0.50)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      shape,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2,
    );
  }

  void _drawLabels(Canvas canvas, Size size) {
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    for (int index = 0; index < axisCount; index++) {
      final anchor = _scaledPoint(_labelAnchors[index], size);
      painter.text = TextSpan(
        text: labels[index],
        style: TextStyle(
          color: labelColor,
          fontFamily: 'Archivo',
          fontSize: 11,
          fontWeight: FontWeight.w400,
          height: 1,
        ),
      );
      painter.layout();
      painter.paint(
        canvas,
        anchor - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.values1 != values1 ||
      old.values2 != values2 ||
      old.labels != labels ||
      old.color1 != color1 ||
      old.color2 != color2 ||
      old.gridColor != gridColor ||
      old.labelColor != labelColor;
}
