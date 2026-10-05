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

  static bool isSwipeActive(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_BackSwipeScope>()
          ?.notifier
          ?.value ??
      false;

  @override
  State<FullScreenBackGesture> createState() => _FullScreenBackGestureState();
}

class _FullScreenBackGestureState extends State<FullScreenBackGesture> {
  double _dragDistance = 0;
  final ValueNotifier<bool> _swipeActive = ValueNotifier(false);

  @override
  void dispose() {
    _swipeActive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.iOS) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) {
        _dragDistance = 0;
        _swipeActive.value = widget.canGoBack();
      },
      onHorizontalDragUpdate: (details) => _dragDistance += details.delta.dx,
      onHorizontalDragEnd: (_) {
        _swipeActive.value = false;
        if (_dragDistance >= 72 && widget.canGoBack()) widget.goBack();
        _dragDistance = 0;
      },
      onHorizontalDragCancel: () {
        _swipeActive.value = false;
        _dragDistance = 0;
      },
      child: _BackSwipeScope(notifier: _swipeActive, child: widget.child),
    );
  }
}

class _BackSwipeScope extends InheritedNotifier<ValueNotifier<bool>> {
  const _BackSwipeScope({required super.notifier, required super.child});
}
