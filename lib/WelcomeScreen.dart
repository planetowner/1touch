import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/theme_controller.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  VideoPlayerController? _controller;
  Brightness? _videoBrightness;
  int _videoLoadId = 0;
  bool _hasError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_videoBrightness == brightness) return;

    _videoBrightness = brightness;
    _loadVideo(brightness);
  }

  Future<void> _loadVideo(Brightness brightness) async {
    final loadId = ++_videoLoadId;
    final previousController = _controller;
    _controller = null;
    _hasError = false;
    await previousController?.dispose();

    if (!mounted || loadId != _videoLoadId) return;

    final asset = brightness == Brightness.dark
        ? 'assets/Onboarding.mp4'
        : 'assets/animations/onboarding_light.mp4';
    final controller = VideoPlayerController.asset(asset);

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);

      if (!mounted || loadId != _videoLoadId) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      setState(() {});
      await controller.play();
    } on Object {
      await controller.dispose();
      if (!mounted || loadId != _videoLoadId) return;
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _videoLoadId++;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);

    return Scaffold(
      backgroundColor: appColors.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            // --- Header (Logo + Toggle) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SvgPicture.asset(
                    'assets/app_logo.svg',
                    height: 23,
                    width: 100,
                    colorFilter:
                        ColorFilter.mode(colors.onSurface, BlendMode.srcIn),
                    placeholderBuilder: (_) =>
                        Text("1TOUCH", style: Heading4.style),
                  ),
                  AppThemeToggle(foregroundColor: colors.onSurface),
                ],
              ),
            ),

            const Spacer(),

            // --- Center Content (Video Player Replace) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(
                    height: 250,
                    width: 250,
                    child: _buildVideoContent(),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    "Let’s start by choosing\nyour favorite teams!",
                    textAlign: TextAlign.center,
                    style: Heading4.style,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // --- Bottom Button ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go('/onboarding/select-favorites'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.onSurface,
                    foregroundColor: colors.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('CONTINUE',
                      style: Body2_b.style.copyWith(color: colors.surface)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Helper widget to handle the video states
  Widget _buildVideoContent() {
    final mutedColor = AppColors.of(context).mutedForeground;
    if (_hasError) {
      return Icon(Icons.sports_soccer, size: 100, color: mutedColor);
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.expand();
    }

    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: VideoPlayer(controller),
    );
  }
}
