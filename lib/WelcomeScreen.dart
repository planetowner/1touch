import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart'; // Assuming this exists based on your uploads

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Basic dark theme toggle logic visualization
    final isLight = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B), // Deep dark background from design
      body: SafeArea(
        child: Column(
          children: [
            // --- Header (Logo + Toggle) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo Text (Replace with Image.asset if you have a logo file)
                  SvgPicture.asset(
                    'assets/app_logo.svg',
                    height: 23,
                    width: 100,
                    placeholderBuilder: (_) => Text("1TOUCH",
                        style: Heading4.style),
                  ),
                  Icon(
                    isLight ? Icons.dark_mode :  Icons.light_mode,
                    color: Colors.white,
                  ),
                ],
              ),
            ),

            // --- Spacer pushes content to center/bottom ---
            const Spacer(),

            // --- Center Content (Team Logos + Text) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // 1. Image of the teams (Munich, PSG, City)
                  // You need to export that cluster of logos as a PNG and put it in assets
                  SizedBox(
                    height: 250,
                    width: 250,
                    child: Image.asset(
                      'assets/images/onboarding_teams_cluster.png',
                      // Fallback icon if image is missing so app doesn't crash
                      errorBuilder: (c, e, s) => const Icon(Icons.sports_soccer, size: 100, color: Colors.white24),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 2. Headline Text
                  Text(
                    "Let’s start by choosing\nyour favorite teams!",
                    textAlign: TextAlign.center,
                    style: Heading4.style
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
                  onPressed: () {
                    // Navigate to the team selection page
                    context.go('/onboarding/select-favorites');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'CONTINUE',
                    style: Body2_b.style.copyWith(color: Colors.black),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}