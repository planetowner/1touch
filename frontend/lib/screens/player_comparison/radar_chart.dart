part of 'player_comparison_screen.dart';

class _EmptyRadarPainter extends CustomPainter {
  const _EmptyRadarPainter({required this.color, required this.labelColor, required this.locale});
  final Color color, labelColor;
  final Locale locale;
  static const labels = [
    'Pace',
    'Shooting',
    'Passing',
    'Defending',
    'Physical'
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .49);
    final radius = math.min(size.width * .29, size.height * .39);
    final vertices = [
      for (var i = 0; i < 5; i++)
        Offset(
          center.dx + math.cos(-math.pi / 2 + i * math.pi * 2 / 5) * radius,
          center.dy + math.sin(-math.pi / 2 + i * math.pi * 2 / 5) * radius,
        ),
    ];
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    Path shape(double scale) {
      final path = Path();
      for (var i = 0; i < vertices.length; i++) {
        final point = Offset.lerp(center, vertices[i], scale)!;
        i == 0
            ? path.moveTo(point.dx, point.dy)
            : path.lineTo(point.dx, point.dy);
      }
      return path..close();
    }

    for (var level = 1; level <= 5; level++) {
      canvas.drawPath(shape(level / 5), paint);
    }
    for (final vertex in vertices) {
      canvas.drawLine(center, vertex, paint);
    }
    for (var i = 0; i < labels.length; i++) {
      final direction = vertices[i] - center;
      final anchor = center + direction * 1.28;
      final text = TextPainter(
        text: TextSpan(
          text: translateMessage(locale, labels[i]),
          style: TextStyle(color: labelColor, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        anchor - Offset(text.width / 2, text.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_EmptyRadarPainter oldDelegate) =>
      oldDelegate.locale != locale || oldDelegate.color != color || oldDelegate.labelColor != labelColor;
}
