import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/core/full_screen_back_gesture.dart';

/// iOS 기본 페이지에도 손가락을 따라가는 뒤로가기를 적용해요.
class InteractiveBackPageTransitionsBuilder extends PageTransitionsBuilder {
  const InteractiveBackPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      InteractiveBackTransition(
        route: route,
        child: CupertinoPageTransition(
          primaryRouteAnimation: animation,
          secondaryRouteAnimation: secondaryAnimation,
          linearTransition: route.popGestureInProgress,
          child: child,
        ),
      );
}

/// 별도 전환을 쓰는 페이지도 같은 포인터 추적을 사용할 수 있어요.
class InteractiveBackTransition extends StatefulWidget {
  const InteractiveBackTransition({
    required this.route,
    required this.child,
    super.key,
  });

  final PageRoute<dynamic> route;
  final Widget child;

  @override
  State<InteractiveBackTransition> createState() =>
      _InteractiveBackTransitionState();
}

class InteractiveBackDragScope extends InheritedNotifier<ValueNotifier<bool>> {
  const InteractiveBackDragScope({
    required super.notifier,
    required super.child,
    super.key,
  });

  static bool isDragging(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<InteractiveBackDragScope>()
          ?.notifier
          ?.value ??
      false;
}

class _InteractiveBackTransitionState extends State<InteractiveBackTransition> {
  static const _settleDuration = Duration(milliseconds: 250);
  static const _dragSlop = 8.0;
  final ValueNotifier<bool> _dragActive = ValueNotifier(false);
  int? _pointer;
  Offset? _pointerStart;
  bool _rejected = false;
  bool _dragging = false;
  bool _settling = false;

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null ||
        _dragging ||
        _settling ||
        !widget.route.isCurrent ||
        !widget.route.popGestureEnabled) {
      return;
    }
    _pointer = event.pointer;
    _pointerStart = event.position;
    _rejected = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointer != event.pointer || _rejected) return;
    final start = _pointerStart;
    if (start == null) return;
    final distance = event.position - start;
    if (!_dragging) {
      if (distance.dx.abs() < _dragSlop && distance.dy.abs() < _dragSlop) {
        return;
      }
      // 처음 움직인 방향을 고정해 세로 스크롤과 왼쪽 스와이프를 유지해요.
      if (distance.dx <= 0 || distance.dx.abs() <= distance.dy.abs()) {
        _rejected = true;
        return;
      }
      if (!widget.route.popGestureEnabled) {
        _rejected = true;
        return;
      }
      widget.route.navigator!.didStartUserGesture();
      _dragging = true;
      _dragActive.value = true;
      FullScreenBackGesture.setSwipeActive(context, true);
    }
    final width = MediaQuery.sizeOf(context).width;
    if (width <= 0) return;
    // 공통 페이지 전환은 현재 라우트의 애니메이션 값을 직접 따라가야 해요.
    // ignore: invalid_use_of_protected_member
    widget.route.controller!.value = (1 - distance.dx / width).clamp(0.0, 1.0);
  }

  void _onPointerEnd(int pointer, {bool cancelled = false}) {
    if (_pointer != pointer) return;
    _pointer = null;
    _pointerStart = null;
    _rejected = false;
    if (!_dragging) return;
    _dragging = false;
    _settling = true;
    final route = widget.route;
    // ignore: invalid_use_of_protected_member
    final routeController = route.controller!;
    final routeNavigator = route.navigator!;
    if (!cancelled && routeController.value <= 0.5 && route.isCurrent) {
      routeNavigator.pop();
      if (routeController.isAnimating) {
        routeController.animateBack(0, duration: _settleDuration);
      }
    } else {
      routeController.animateTo(1, duration: _settleDuration);
    }

    void finish() {
      _settling = false;
      if (mounted) {
        _dragActive.value = false;
        FullScreenBackGesture.setSwipeActive(context, false);
      }
      routeNavigator.didStopUserGesture();
    }

    if (routeController.isAnimating) {
      late AnimationStatusListener listener;
      listener = (_) {
        routeController.removeStatusListener(listener);
        finish();
      };
      routeController.addStatusListener(listener);
    } else {
      finish();
    }
  }

  @override
  void dispose() {
    _dragActive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: (event) => _onPointerEnd(event.pointer),
        onPointerCancel: (event) =>
            _onPointerEnd(event.pointer, cancelled: true),
        child: InteractiveBackDragScope(
          notifier: _dragActive,
          child: widget.child,
        ),
      );
}

/// 온보딩에서 이미 사용하는 페이지 전환도 공통 동작을 공유해요.
class InteractiveBackPage<T> extends Page<T> {
  const InteractiveBackPage({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => _InteractiveBackRoute<T>(
        settings: this,
        builder: (_) => child,
      );
}

class _InteractiveBackRoute<T> extends CupertinoPageRoute<T> {
  _InteractiveBackRoute({
    required super.builder,
    required super.settings,
  });

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Theme.of(context).platform != TargetPlatform.iOS) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return InteractiveBackTransition(
      route: this,
      child: CupertinoPageTransition(
        primaryRouteAnimation: animation,
        secondaryRouteAnimation: secondaryAnimation,
        linearTransition: popGestureInProgress,
        child: child,
      ),
    );
  }
}
