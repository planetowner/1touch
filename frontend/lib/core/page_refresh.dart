import 'package:flutter/material.dart';

class PageRefreshIndicator extends StatelessWidget {
  const PageRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.builder,
    this.notificationDepth = 0,
  });

  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, ScrollPhysics physics) builder;
  // NestedScrollView 안의 TabBarView 본문은 depth 2로 알림을 보내요.
  final int notificationDepth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final behavior = ScrollConfiguration.of(context);
          final physics = _PageRefreshPhysics(
            viewportExtent: () => context.size!.height,
            parent: behavior.getScrollPhysics(context),
          );
          return ScrollConfiguration(
            behavior: behavior.copyWith(physics: physics),
            child: RefreshIndicator(
              onRefresh: onRefresh,
              notificationPredicate: (notification) =>
                  notification.metrics is _PageRefreshMetrics,
              child: Builder(
                builder: (context) =>
                    NotificationListener<OverscrollIndicatorNotification>(
                  onNotification: (notification) {
                    // Android의 늘어남 효과가 새로고침 동작에 겹치지 않게 해요.
                    if (notification.leading &&
                        notification.depth == notificationDepth) {
                      notification.disallowIndicator();
                    }
                    return false;
                  },
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      // 바깥 헤더와 안쪽 본문 알림을 섞으면 표시가 먼저 멈춰요.
                      if (notification.depth == notificationDepth &&
                          notification.metrics.axis == Axis.vertical) {
                        _refreshNotification(
                                notification, constraints.maxHeight)
                            ?.dispatch(context);
                      }
                      return false;
                    },
                    child: builder(context, physics),
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _PageRefreshPhysics extends ScrollPhysics {
  const _PageRefreshPhysics({required this.viewportExtent, super.parent});

  final double Function() viewportExtent;

  @override
  _PageRefreshPhysics applyTo(ScrollPhysics? ancestor) => _PageRefreshPhysics(
        viewportExtent: viewportExtent,
        parent: buildParent(ancestor),
      );

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) =>
      position.axis == Axis.vertical || super.shouldAcceptUserOffset(position);

  // NestedScrollView는 iOS의 추가 시작 보정을 적용하지 않아 첫 이동량을 맞춰요.
  @override
  double? get dragStartDistanceMotionThreshold => null;

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // 탭 헤더 높이와 관계없이 홈과 같은 화면 높이로 당기는 저항을 계산해요.
    final metrics = position.axis == Axis.vertical &&
            position.pixels < position.minScrollExtent
        ? position.copyWith(viewportDimension: viewportExtent())
        : position;
    return super.applyPhysicsToUserOffset(metrics, offset);
  }
}

// RefreshIndicator도 본문 높이가 아닌 같은 화면 높이로 당긴 거리를 판단해요.
class _PageRefreshMetrics extends FixedScrollMetrics {
  _PageRefreshMetrics(ScrollMetrics metrics, double viewportExtent)
      : super(
          minScrollExtent: metrics.minScrollExtent,
          maxScrollExtent: metrics.maxScrollExtent,
          pixels: metrics.pixels,
          viewportDimension: viewportExtent,
          axisDirection: metrics.axisDirection,
          devicePixelRatio: metrics.devicePixelRatio,
        );
}

ScrollNotification? _refreshNotification(
    ScrollNotification notification, double viewportExtent) {
  final context = notification.context!;
  // 본문이 맨 위여도 헤더가 접혀 있으면 먼저 페이지 맨 위로 돌아가야 해요.
  if (notification is ScrollStartNotification) {
    final nested = context.findAncestorStateOfType<NestedScrollViewState>();
    if (nested != null && nested.outerController.position.extentBefore > 0) {
      return null;
    }
  }
  final metrics = _PageRefreshMetrics(notification.metrics, viewportExtent);
  return switch (notification) {
    ScrollStartNotification() => ScrollStartNotification(
        metrics: metrics,
        context: context,
        dragDetails: notification.dragDetails,
      ),
    ScrollUpdateNotification() => ScrollUpdateNotification(
        metrics: metrics,
        context: context,
        dragDetails: notification.dragDetails,
        scrollDelta: notification.scrollDelta,
      ),
    OverscrollNotification() => OverscrollNotification(
        metrics: metrics,
        context: context,
        dragDetails: notification.dragDetails,
        overscroll: notification.overscroll,
        velocity: notification.velocity,
      ),
    ScrollEndNotification() => ScrollEndNotification(
        metrics: metrics,
        context: context,
        dragDetails: notification.dragDetails,
      ),
    _ => null,
  };
}

class PageRefreshController {
  final _callbacks = <Future<void> Function()>{};

  Future<void> refresh() async {
    // 현재 탭의 모든 요청이 끝날 때까지 표시를 유지해요.
    await Future.wait(_callbacks.toList().map((refresh) => refresh()));
  }
}

class PageRefreshPlaceholder extends StatelessWidget {
  const PageRefreshPlaceholder({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        ),
      );
}

class PageRefreshScope extends InheritedWidget {
  const PageRefreshScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final PageRefreshController controller;

  @override
  bool updateShouldNotify(PageRefreshScope oldWidget) =>
      controller != oldWidget.controller;
}

// 화면을 다시 만들지 않고 데이터를 갱신해 시즌과 정렬 선택을 유지해요.
mixin PageRefreshParticipant<T extends StatefulWidget> on State<T> {
  PageRefreshController? _refreshController;

  Future<void> refreshPage();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context
        .dependOnInheritedWidgetOfExactType<PageRefreshScope>()
        ?.controller;
    if (controller == _refreshController) return;
    _refreshController?._callbacks.remove(refreshPage);
    _refreshController = controller;
    controller?._callbacks.add(refreshPage);
  }

  @override
  void dispose() {
    _refreshController?._callbacks.remove(refreshPage);
    super.dispose();
  }
}
