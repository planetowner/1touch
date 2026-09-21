import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Five separated, flat-ended arcs showing an existing qualitative rating.
class RatingLevelRing extends StatelessWidget {
  const RatingLevelRing(
      {super.key, required this.rating, this.size = 18, this.levelOverride});

  final String rating;
  final double size;
  // 폼과 가성비는 최고 등급 이름이 달라 서버가 정한 단계를 그대로 표시해요.
  final int? levelOverride;

  int get level =>
      levelOverride ??
      switch (rating.trim().toLowerCase()) {
        'poor' => 1,
        'fair' || 'average' => 2,
        'good' => 3,
        'very good' => 4,
        'excellent' => 5,
        _ => 0,
      };

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
