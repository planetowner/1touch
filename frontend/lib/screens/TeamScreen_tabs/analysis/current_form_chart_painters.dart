part of '../Analysis.dart';

class _CurrentFormGridPainter extends CustomPainter {
  const _CurrentFormGridPainter({
    required this.color,
    required this.topLineInset,
  });

  final Color color;
  final double topLineInset;

  static const int _divisionCount = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (var index = 0; index <= _divisionCount; index++) {
      final y = size.height * index / _divisionCount;
      final startX = index < 3 ? topLineInset : 0.0;
      canvas.drawLine(Offset(startX, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_CurrentFormGridPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.topLineInset != topLineInset;
}

class _CurrentFormSelectionPainter extends CustomPainter {
  const _CurrentFormSelectionPainter({
    required this.round,
    required this.maxRound,
    required this.maxPoints,
    required this.currentPoints,
    required this.comparisonPoints,
    required this.currentColor,
    required this.comparisonColor,
  });

  final int round;
  final int maxRound;
  final double maxPoints;
  final double? currentPoints;
  final double? comparisonPoints;
  final Color currentColor;
  final Color comparisonColor;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * round / maxRound;
    final guidePaint = Paint()
      ..color = comparisonColor.withValues(alpha: 0.9)
      ..strokeWidth = 1;

    const dashHeight = 8.0;
    const dashGap = 7.0;
    for (var y = 0.0; y < size.height; y += dashHeight + dashGap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(y + dashHeight, size.height)),
        guidePaint,
      );
    }

    _drawPoint(canvas, size, x, comparisonPoints, comparisonColor);
    _drawPoint(canvas, size, x, currentPoints, currentColor);
  }

  void _drawPoint(
    Canvas canvas,
    Size size,
    double x,
    double? points,
    Color color,
  ) {
    if (points == null) return;
    final y = size.height * (1 - points / maxPoints);
    canvas.drawCircle(Offset(x, y), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CurrentFormSelectionPainter oldDelegate) =>
      oldDelegate.round != round ||
      oldDelegate.maxRound != maxRound ||
      oldDelegate.maxPoints != maxPoints ||
      oldDelegate.currentPoints != currentPoints ||
      oldDelegate.comparisonPoints != comparisonPoints ||
      oldDelegate.currentColor != currentColor ||
      oldDelegate.comparisonColor != comparisonColor;
}
