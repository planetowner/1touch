import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Five separated, flat-ended arcs showing an existing qualitative rating.
class RatingLevelRing extends StatelessWidget {
  const RatingLevelRing(
      {super.key, required this.rating, required this.level, this.size = 18});

  final String rating;
  final double size;
  // 등급명으로 단계를 다시 판단하지 않고 서버가 정한 1~5단계를 표시해요.
  final int level;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$rating, $level of 5',
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RatingLevelPainter(
              level,
              Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF090A0A)
                  : const Color(0xFFE0E0E0),
            ),
          ),
        ),
      );
}

class _RatingLevelPainter extends CustomPainter {
  const _RatingLevelPainter(this.level, this.inactiveColor);

  final int level;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.19;
    final bounds = (Offset.zero & size).deflate(stroke / 2);
    const step = 2 * math.pi / 5;
    const gap = 0.14;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    for (var index = 0; index < 5; index++) {
      paint.color = index < level ? const Color(0xFF20B972) : inactiveColor;
      canvas.drawArc(bounds, -math.pi / 2 + index * step + gap / 2, step - gap,
          false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RatingLevelPainter oldDelegate) =>
      oldDelegate.level != level || oldDelegate.inactiveColor != inactiveColor;
}
