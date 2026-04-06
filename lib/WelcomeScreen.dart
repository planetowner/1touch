import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart'; // Add this import
import 'package:onetouch/core/stylesheet_dark.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late VideoPlayerController _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Initialize the controller with your MP4 asset
    _controller = VideoPlayerController.asset('assets/Onboarding.mp4')
      ..initialize().then((_) {
        setState(() {}); // Refresh to show video once loaded
        _controller.setLooping(true);
        _controller.play();
      }).catchError((error) {
        setState(() => _hasError = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose(); // Important: cleanup to prevent memory leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
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
                    placeholderBuilder: (_) => Text("1TOUCH", style: Heading4.style),
                  ),
                  Icon(
                    isLight ? Icons.dark_mode : Icons.light_mode,
                    color: Colors.white,
                  ),
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
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('CONTINUE', style: Body2_b.style.copyWith(color: Colors.black)),
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
    if (_hasError) {
      return const Icon(Icons.sports_soccer, size: 100, color: Colors.white24);
    }

    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white24));
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}