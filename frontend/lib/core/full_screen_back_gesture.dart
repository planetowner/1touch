import 'package:flutter/material.dart';

/// Adds a right-swipe back gesture outside children that handle horizontal drags.
class FullScreenBackGesture extends StatefulWidget {
  const FullScreenBackGesture({
    super.key,
    required this.child,
    required this.canGoBack,
    required this.goBack,
  });

  final Widget child;
  final bool Function() canGoBack;
  final Future<bool> Function() goBack;

  @override
  State<FullScreenBackGesture> createState() => _FullScreenBackGestureState();
}

class _FullScreenBackGestureState extends State<FullScreenBackGesture> {
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.iOS) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _dragDistance = 0,
      onHorizontalDragUpdate: (details) => _dragDistance += details.delta.dx,
      onHorizontalDragEnd: (_) {
        if (_dragDistance >= 72 && widget.canGoBack()) widget.goBack();
        _dragDistance = 0;
      },
      onHorizontalDragCancel: () => _dragDistance = 0,
      child: widget.child,
    );
  }
}
