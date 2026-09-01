import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  Brightness? _brightness;
  bool _isInitializing = false;
  bool _hasNavigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null || _isInitializing) return;

    _brightness = Theme.of(context).brightness;
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _isInitializing = true;
    final asset = _brightness == Brightness.dark
        ? 'assets/animations/onetouch_logo_dark.mp4'
        : 'assets/animations/onetouch_logo_light.mp4';
    final controller = VideoPlayerController.asset(asset)
      ..addListener(_handleVideoUpdate);
    _controller = controller;

    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);
      if (!mounted) return;
      setState(() {});
      await controller.play();
    } on Object {
      _goToOnboarding();
    }
  }

  void _handleVideoUpdate() {
    if (_controller?.value.isCompleted == true) {
      _goToOnboarding();
    }
  }

  void _goToOnboarding() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    context.go('/onboarding');
  }

  @override
  void dispose() {
    _controller
      ?..removeListener(_handleVideoUpdate)
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
    final controller = _controller;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SizedBox(
          width: logoWidth,
          child: AspectRatio(
            aspectRatio: 480 / 68,
            child: controller?.value.isInitialized == true
                ? VideoPlayer(
                    controller!,
                    key: const ValueKey('splash-logo-video'),
                  )
                : ColoredBox(color: backgroundColor),
          ),
        ),
      ),
    );
  }
}
