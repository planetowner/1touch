import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'round_chart_window.dart';

class RoundChartVisuals {
  static const double cardHeight = 346;
  static const double cardRadius = 20;
  static const double axisLineInset = 34;
  static const int horizontalLineCount = 12;
}

double roundChartTooltipLeft({
  required RoundChartWindow roundWindow,
  required int round,
  required double viewportWidth,
  required double tooltipWidth,
  required double gap,
  required bool preferLeft,
}) {
  final visibleLeft = roundWindow.centeredScrollOffset(round, viewportWidth);
  final visibleRight = visibleLeft + viewportWidth;
  final anchorX =
      roundWindow.contentWidth(viewportWidth) * roundWindow.fractionOf(round);
  final left = anchorX - gap - tooltipWidth;
  final right = anchorX + gap;
  final leftFits = left >= visibleLeft;
  final rightFits = right + tooltipWidth <= visibleRight;
  if (preferLeft) {
    if (leftFits) {
      return left;
    }
    if (rightFits) {
      return right;
    }
  } else {
    if (rightFits) {
      return right;
    }
    if (leftFits) {
      return left;
    }
  }
  return (preferLeft ? left : right)
      .clamp(visibleLeft, visibleRight - tooltipWidth);
}

int roundChartInsetLineCount(
  BuildContext context,
  Size plotSize,
  String axisLabel,
  TextStyle axisLabelStyle,
) {
  if (Localizations.localeOf(context).languageCode == 'ko') return 2;
  final painter = TextPainter(
    text: TextSpan(text: axisLabel, style: axisLabelStyle),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final cellHeight =
      plotSize.height / (RoundChartVisuals.horizontalLineCount - 1);
  return (math.max(1, (painter.width / cellHeight).ceil()) + 1)
      .clamp(0, RoundChartVisuals.horizontalLineCount);
}

class RoundChartGridPainter extends CustomPainter {
  const RoundChartGridPainter({
    required this.color,
    required this.insetLineCount,
  });

  final Color color;
  final int insetLineCount;
  int get divisionCount => RoundChartVisuals.horizontalLineCount - 1;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var index = 0; index <= divisionCount; index++) {
      final y = size.height * index / divisionCount;
      canvas.drawLine(
        Offset(index < insetLineCount ? RoundChartVisuals.axisLineInset : 0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(RoundChartGridPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.insetLineCount != insetLineCount;
}
