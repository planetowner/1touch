import 'package:flutter/material.dart';

/// 목록이 해당 방향으로 더 스크롤될 때만 양 끝을 흐리게 보여줘요.
class AppScrollEdgeFade extends StatefulWidget {
  const AppScrollEdgeFade({
    super.key,
    required this.child,
    required this.topKey,
    required this.bottomKey,
  });

  final Widget child;
  final Key topKey;
  final Key bottomKey;

  @override
  State<AppScrollEdgeFade> createState() => _AppScrollEdgeFadeState();
}

class _AppScrollEdgeFadeState extends State<AppScrollEdgeFade> {
  static const _fadeHeight = 40.0;
  static const _fadeColors = [
    Color(0x00000000),
    Color(0x00000000),
    Color(0x40000000),
    Color(0x80000000),
    Color(0xCC000000),
    Color(0xFF000000),
    Color(0xFF000000),
  ];
  static const _fadeStops = [0.0, 0.20, 0.45, 0.70, 0.82, 0.92, 1.0];
  static const _topGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: _fadeColors,
    stops: _fadeStops,
  );
  static const _bottomGradient = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: _fadeColors,
    stops: _fadeStops,
  );

  bool _fadeTop = false;
  bool _fadeBottom = false;

  void _update(ScrollMetrics metrics) {
    final top = metrics.extentBefore > 0.5;
    final bottom = metrics.extentAfter > 0.5;
    if (top == _fadeTop && bottom == _fadeBottom) return;
    // 레이아웃 알림 안에서 바로 setState를 호출하지 않아요.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || (top == _fadeTop && bottom == _fadeBottom)) return;
      setState(() {
        _fadeTop = top;
        _fadeBottom = bottom;
      });
    });
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          _update(notification.metrics);
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _update(notification.metrics);
            return false;
          },
          child: ShaderMask(
            key: widget.topKey,
            blendMode: _fadeTop ? BlendMode.dstIn : BlendMode.dst,
            shaderCallback: (bounds) {
              final height = bounds.height.clamp(0.0, _fadeHeight);
              return _topGradient.createShader(
                Rect.fromLTWH(0, 0, bounds.width, height),
              );
            },
            child: ShaderMask(
              key: widget.bottomKey,
              blendMode: _fadeBottom ? BlendMode.dstIn : BlendMode.dst,
              shaderCallback: (bounds) {
                final height = bounds.height.clamp(0.0, _fadeHeight);
                return _bottomGradient.createShader(Rect.fromLTWH(
                  0,
                  bounds.height - height,
                  bounds.width,
                  height,
                ));
              },
              child: widget.child,
            ),
          ),
        ),
      );
}
