import 'package:flutter/material.dart';

/// 화면 전환 중 스크롤을 잠글 수 있도록 뒤로가기 상태를 공유해요.
class FullScreenBackGesture extends StatefulWidget {
  const FullScreenBackGesture({
    super.key,
    required this.child,
  });

  final Widget child;

  static bool isSwipeActive(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_BackSwipeScope>()
          ?.notifier
          ?.value ??
      false;

  static void setSwipeActive(BuildContext context, bool active) {
    final notifier =
        context.getInheritedWidgetOfExactType<_BackSwipeScope>()?.notifier;
    if (notifier != null && notifier.value != active) notifier.value = active;
  }

  @override
  State<FullScreenBackGesture> createState() => _FullScreenBackGestureState();
}

class _FullScreenBackGestureState extends State<FullScreenBackGesture> {
  final ValueNotifier<bool> _swipeActive = ValueNotifier(false);

  @override
  void dispose() {
    _swipeActive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _BackSwipeScope(notifier: _swipeActive, child: widget.child);
}

class _BackSwipeScope extends InheritedNotifier<ValueNotifier<bool>> {
  const _BackSwipeScope({required super.notifier, required super.child});
}
