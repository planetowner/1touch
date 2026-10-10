import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
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

class _InteractiveBackTransitionState extends State<InteractiveBackTransition> {
  static const _returnDuration = Duration(milliseconds: 190);
  static const _closeDuration = Duration(milliseconds: 170);
  static const _dragSlop = 8.0;
  static const _flingVelocity = 700.0;
  final ValueNotifier<bool> _dragActive = ValueNotifier(false);
  final Set<ScrollHoldController> _scrollHolds = {};
  int? _pointer;
  Offset? _pointerStart;
  Offset? _pointerLast;
  VelocityTracker? _velocityTracker;
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
    _pointerLast = event.position;
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
    _rejected = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointer != event.pointer || _rejected) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    final start = _pointerStart;
    final last = _pointerLast;
    if (start == null || last == null) return;
    final distance = event.position - start;
    if (!_dragging &&
        distance.dx.abs() < _dragSlop &&
        distance.dy.abs() < _dragSlop) {
      return;
    }
    if (!_dragging) {
      // 시작 방향만 판단하고, 뒤로가기가 시작되면 가로축을 유지해요.
      if (distance.dx <= 0 ||
          distance.dx <= distance.dy.abs() ||
          !widget.route.popGestureEnabled) {
        _rejected = true;
        return;
      }
      _lockScrolling();
      widget.route.navigator!.didStartUserGesture();
      _dragging = true;
      _dragActive.value = true;
      FullScreenBackGesture.setSwipeActive(context, true);
    }
    final width = MediaQuery.sizeOf(context).width;
    if (width <= 0) return;
    // 공통 페이지 전환은 현재 라우트의 애니메이션 값을 직접 따라가야 해요.
    // ignore: invalid_use_of_protected_member
    final controller = widget.route.controller!;
    controller.value =
        (controller.value - (event.position.dx - last.dx) / width)
            .clamp(0.0, 1.0);
    _pointerLast = event.position;
  }

  void _lockScrolling() {
    void lock(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final position = (element.state as ScrollableState).position;
        // 중첩 스크롤은 jumpTo가 다른 영역도 이동시켜 hold로 위치를 보존해요.
        late final ScrollHoldController hold;
        hold = position.hold(() => _scrollHolds.remove(hold));
        _scrollHolds.add(hold);
      }
      element.visitChildElements(lock);
    }

    context.visitChildElements(lock);
  }

  void _unlockScrolling() {
    for (final hold in _scrollHolds.toList()) {
      hold.cancel();
    }
    _scrollHolds.clear();
  }

  void _onPointerEnd(int pointer, {bool cancelled = false}) {
    if (_pointer != pointer) return;
    final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0;
    _pointer = null;
    _pointerStart = null;
    _pointerLast = null;
    _velocityTracker = null;
    _rejected = false;
    if (!_dragging) return;
    _dragging = false;
    _settling = true;
    final route = widget.route;
    // ignore: invalid_use_of_protected_member
    final routeController = route.controller!;
    final routeNavigator = route.navigator!;
    if (!cancelled &&
        (velocity > _flingVelocity || routeController.value <= 0.5) &&
        route.isCurrent) {
      routeNavigator.pop();
      if (routeController.isAnimating) {
        routeController.animateBack(0,
            duration: _closeDuration, curve: Curves.easeOutCubic);
      }
    } else {
      routeController.animateTo(1,
          duration: _returnDuration, curve: Curves.easeOutCubic);
    }

    void finish() {
      _unlockScrolling();
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
    _unlockScrolling();
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
        child: ValueListenableBuilder<bool>(
          valueListenable: _dragActive,
          child: widget.child,
          builder: (context, locked, child) {
            final behavior = ScrollConfiguration.of(context);
            return ScrollConfiguration(
              behavior: locked
                  ? behavior.copyWith(
                      physics: const NeverScrollableScrollPhysics(),
                      // AlwaysScrollableScrollPhysics를 쓰는 목록도 잠가요.
                      dragDevices: const <PointerDeviceKind>{},
                    )
                  : behavior,
              child: child!,
            );
          },
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
