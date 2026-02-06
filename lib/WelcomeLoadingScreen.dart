// import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'core/stylesheet_dark.dart';

class WelcomeLoadingScreen extends StatefulWidget {
  const WelcomeLoadingScreen({super.key});

  @override
  State<WelcomeLoadingScreen> createState() => _WelcomeLoadingScreenState();
}

class _WelcomeLoadingScreenState extends State<WelcomeLoadingScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize the video
    _controller = VideoPlayerController.asset('assets/flag_video.mp4')
      ..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized
        setState(() {
          _isInitialized = true;
        });
        _controller.setLooping(true); // Loop the video
        _controller.play(); // Auto play
        _controller.setVolume(0.0); // Mute sound if any
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background
      body: Stack(
        children: [
          // --- LAYER 1: THE VIDEO ---
          if (_isInitialized)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.65,
              // Takes up top 65%
              child: FittedBox(
                fit: BoxFit.cover,
                // Ensures video fills the width without stretching
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),

          // --- LAYER 2: GRADIENT OVERLAY (Fade to Black) ---
          // This makes the text readable and blends the video into the black bottom
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.8),
                    Colors.black,
                  ],
                  // Adjust these stops to control where the fade happens
                  stops: const [0.0, 0.4, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // --- LAYER 3: CONTENT ---
          SafeArea(
            child: Column(
              children: [
                // Header (Logo + Switch)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo
                      SvgPicture.asset(
                        'assets/app_logo.svg',
                        height: 23,
                        width: 100,
                        placeholderBuilder: (_) => const Text("1TOUCH",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20)),
                      ),

                      // Switch (Visual only)
                      Row(
                        children: [
                          const Icon(Icons.wb_sunny_outlined,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Switch(
                            value: false,
                            onChanged: (v) {},
                            activeColor: Colors.white,
                            inactiveTrackColor: Colors.grey,
                          ),
                        ],
                      )
                    ],
                  ),
                ),

                const Spacer(), // Pushes text to bottom

                // Welcome Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const Text(
                        "Welcome to 1Touch!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28, // Large Size
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Arial', // Replace with your font
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Your setup is complete. Let’s see what\nyour favorites are up to.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                          height: 1.4, // Line height for readability
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Continue Button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to Home or Dashboard
                      context.go('/home');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      // Grey/Brownish tone from image
                      foregroundColor: Colors.black,
                      // Text color
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      "CONTINUE",
                      style: Body2_b.style.copyWith(color: Colors.black)
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
