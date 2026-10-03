part of '../analysis.dart';

class _CurrentFormSelectionPainter extends CustomPainter {
  const _CurrentFormSelectionPainter({
    required this.round,
    required this.roundWindow,
    required this.minPoints,
    required this.maxPoints,
    required this.currentPoints,
    required this.comparisonPoints,
    required this.currentColor,
    required this.comparisonColor,
  });

  final int round;
  final RoundChartWindow roundWindow;
  final double minPoints;
  final double maxPoints;
  final double? currentPoints;
  final double? comparisonPoints;
  final Color currentColor;
  final Color comparisonColor;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * roundWindow.fractionOf(round);
    final guidePaint = Paint()
      ..color = comparisonColor.withValues(alpha: 0.9)
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
    final y =
        size.height * (1 - (points - minPoints) / (maxPoints - minPoints));
    canvas.drawCircle(Offset(x, y), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CurrentFormSelectionPainter oldDelegate) =>
      oldDelegate.round != round ||
      oldDelegate.roundWindow.firstRound != roundWindow.firstRound ||
      oldDelegate.minPoints != minPoints ||
      oldDelegate.maxPoints != maxPoints ||
      oldDelegate.currentPoints != currentPoints ||
      oldDelegate.comparisonPoints != comparisonPoints ||
      oldDelegate.currentColor != currentColor ||
      oldDelegate.comparisonColor != comparisonColor;
}
