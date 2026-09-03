import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Brightness? _brightness;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener(_handleAnimationStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _brightness ??= Theme.of(context).brightness;
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _goToOnboarding();
    }
  }

  void _startAnimation(LottieComposition composition) {
    if (_controller.isAnimating || _controller.isCompleted) return;
    _controller
      ..duration = composition.duration
      ..forward();
  }

  Widget _buildAnimationError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _goToOnboarding());
    return const SizedBox.expand();
  }

  void _goToOnboarding() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    context.go('/onboarding');
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
