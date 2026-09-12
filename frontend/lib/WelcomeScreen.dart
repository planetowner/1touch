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
  late final VideoPlayerController _darkController;
  late final VideoPlayerController _lightController;
  bool _videosReady = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _darkController = VideoPlayerController.asset('assets/onboarding_dark.mp4');
    _lightController =
        VideoPlayerController.asset('assets/onboarding_light.mp4');
    _initializeVideos();
  }

  Future<void> _initializeVideos() async {
    try {
      await Future.wait([
        _darkController.initialize(),
        _lightController.initialize(),
      ]);
      await Future.wait([
        _darkController.setLooping(true),
        _lightController.setLooping(true),
        _darkController.setVolume(0),
        _lightController.setVolume(0),
      ]);
      await Future.wait([
        _darkController.play(),
        _lightController.play(),
      ]);

      if (!mounted) return;
      setState(() => _videosReady = true);
    } on Object {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _darkController.dispose();
    _lightController.dispose();
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

    if (!_videosReady) {
      return const SizedBox.expand();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IndexedStack(
      alignment: Alignment.center,
      index: isDark ? 0 : 1,
      children: [
        AspectRatio(
          aspectRatio: _darkController.value.aspectRatio,
          child: VideoPlayer(_darkController),
        ),
        AspectRatio(
          aspectRatio: _lightController.value.aspectRatio,
          child: VideoPlayer(_lightController),
        ),
      ],
    );
  }
}
