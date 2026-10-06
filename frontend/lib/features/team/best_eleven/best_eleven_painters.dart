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

    // 골키퍼 앞 박스는 345 × 392 기준 규격을 카드 크기에 맞춰 그려요.
    final scaleX = size.width / FormationLayout.designSize.width;
    final scaleY = size.height / FormationLayout.designSize.height;
    final boxPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final (width, depth) in [(200.0, 120.0), (120.0, 40.0)]) {
      final left = (size.width - width * scaleX) / 2;
      final right = size.width - left;
      final top = size.height - depth * scaleY;
      canvas.drawLine(Offset(left, size.height), Offset(left, top), boxPaint);
      canvas.drawLine(Offset(left, top), Offset(right, top), boxPaint);
      canvas.drawLine(Offset(right, top), Offset(right, size.height), boxPaint);
    }
  }

  @override
  bool shouldRepaint(_HalfCirclePainter old) => old.color != color;
}
