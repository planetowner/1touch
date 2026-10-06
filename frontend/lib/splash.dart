import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:onetouch/features/app_error_view.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.nextLocation = '/onboarding',
    this.prepareNextLocation,
    this.onComplete,
  });

  final String nextLocation;
  final Future<String> Function()? prepareNextLocation;
  final VoidCallback? onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Brightness? _brightness;
  bool _hasNavigated = false;
  bool _animationStarted = false;
  bool _logoDrawn = false;
  bool _animationFailed = false;
  late bool _isPrepared;
  String? _preparedLocation;
  Object? _preparationError;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener(_handleAnimationStatus);
    _isPrepared = widget.prepareNextLocation == null;
    if (!_isPrepared) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _prepare();
      });
    }
  }

  Future<void> _prepare() async {
    setState(() => _preparationError = null);
    try {
      final location = await widget.prepareNextLocation!();
      if (!mounted) return;
      _preparedLocation = location;
      _isPrepared = true;
      _finishWhenPrepared();
    } on Object catch (error, stackTrace) {
      debugPrint('App startup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _preparationError = error);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _brightness ??= Theme.of(context).brightness;
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _controller.value == 1) {
      _completeSplash();
    }
  }

  void _startAnimation(LottieComposition composition) {
    if (_animationStarted) return;
    _animationStarted = true;
    _controller.duration = composition.duration;
    // 두 로고 파일은 중간 프레임에서 완성돼요. 준비가 늦으면 사라지기 전에 멈춰요.
    _controller.animateTo(0.5).then((_) {
      if (!mounted) return;
      _logoDrawn = true;
      _finishWhenPrepared();
    });
  }

  void _finishWhenPrepared() {
    if (!_isPrepared || !mounted) return;
    if (_animationFailed) {
      _completeSplash();
    } else if (_logoDrawn) {
      _controller.forward();
    }
  }

  Widget _buildAnimationError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _animationFailed = true;
      _finishWhenPrepared();
    });
    return const SizedBox.expand();
  }

  void _completeSplash() {
    if (_hasNavigated || !_isPrepared || !mounted) return;
    _hasNavigated = true;
    widget.onComplete?.call();
    context.go(_preparedLocation ?? widget.nextLocation);
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_preparationError != null) {
      return AppErrorScreen(statusCode: 500, onRetry: _prepare);
    }
    final brightness = _brightness ?? Theme.of(context).brightness;
    final backgroundColor =
        brightness == Brightness.dark ? Colors.black : Colors.white;
    final logoWidth = (MediaQuery.sizeOf(context).width * 0.34)
        .clamp(128.0, 160.0)
        .toDouble();
    final asset = brightness == Brightness.dark
        ? 'assets/animations/onetouch_logo_dark.json'
        : 'assets/animations/onetouch_logo_light.json';

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SizedBox(
          width: logoWidth,
          child: AspectRatio(
            aspectRatio: 481 / 69,
            child: Lottie.asset(
              asset,
              key: ValueKey(asset),
              controller: _controller,
              repeat: false,
              fit: BoxFit.contain,
              onLoaded: _startAnimation,
              errorBuilder: _buildAnimationError,
            ),
          ),
        ),
      ),
    );
  }
}
