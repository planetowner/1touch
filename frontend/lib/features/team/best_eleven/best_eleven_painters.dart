part of 'team_best_eleven_section.dart';

class _HalfCirclePainter extends CustomPainter {
  const _HalfCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final centre = Offset(size.width / 2, 0);
    final radius = size.width * 0.28;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      0,
      3.14159,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_HalfCirclePainter old) => old.color != color;
}
