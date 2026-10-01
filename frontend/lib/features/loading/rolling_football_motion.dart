import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Three turns in 2.083s, followed by a 0.833s hold, repeated.
class RollingFootballMotion extends StatefulWidget {
  const RollingFootballMotion(
      {super.key, required this.child, this.transformKey});

  final Widget child;
  final Key? transformKey;

  @override
  State<RollingFootballMotion> createState() => _RollingFootballMotionState();
}

class _RollingFootballMotionState extends State<RollingFootballMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2916),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _roll.stop();
      _roll.value = 0;
    } else if (!_roll.isAnimating) {
      _roll.repeat();
    }
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _roll,
        child: widget.child,
        builder: (context, ball) {
          final progress = const Interval(
            0,
            2083 / 2916,
            curve: Cubic(0.5, 0, 0, 1),
          ).transform(_roll.value);
          return Transform.rotate(
            key: widget.transformKey,
            angle: 6 * math.pi * progress,
            child: ball,
          );
        },
      );
}
