import 'package:flutter/material.dart';

const _liveMotionCurve = Cubic(0.5, 0, 0.5, 1);
const _liveMotionDuration = Duration(seconds: 1);

/// A live indicator that fades out and back in, one second in each direction.
class LivePulseDot extends StatefulWidget {
  const LivePulseDot({super.key, this.size = 6, this.color});

  final double size;
  final Color? color;

  @override
  State<LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _liveMotionDuration,
    reverseDuration: _liveMotionDuration,
    value: 1,
  );
  late final CurvedAnimation _opacity = CurvedAnimation(
    parent: _controller,
    curve: _liveMotionCurve,
    reverseCurve: _liveMotionCurve,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        key: const ValueKey('live-pulse-dot'),
        opacity: _opacity,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color ?? Theme.of(context).colorScheme.onSurface,
            shape: BoxShape.circle,
          ),
        ),
      );
}

/// Draws a short straight line from left to right once when it appears.
class LiveTrimLine extends StatefulWidget {
  const LiveTrimLine({super.key, this.width = 24, this.color});

  final double width;
  final Color? color;

  @override
  State<LiveTrimLine> createState() => _LiveTrimLineState();
}

class _LiveTrimLineState extends State<LiveTrimLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _liveMotionDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (_controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        key: const ValueKey('live-trim-line'),
        width: widget.width,
        height: 1,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _liveMotionCurve.transform(_controller.value),
            child: child,
          ),
          child: ColoredBox(
            color: widget.color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
}
