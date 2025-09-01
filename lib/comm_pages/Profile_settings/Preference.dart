import "package:flutter/material.dart";
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

class PreferencePage extends StatefulWidget {
  const PreferencePage({super.key});

  @override
  State<PreferencePage> createState() => _PreferencePageState();
}

class _PreferencePageState extends State<PreferencePage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Gradient Background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 400,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xE5DB0030),
                    Color(0x00B40000),
                  ],
                  stops: [0.0, 0.6],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      ),
                      const Text("Preferences", style: TextStyle(color: Colors.white, fontSize: 18)),
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: () => context.push('/search'),
                      ),
                    ],
                  ),
                ),

                // Body
                const SizedBox(height: 16),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _buildPreferenceSection("TIME ZONE", "New York (GMT + 8:00)", onTap: () {}),
                      const SizedBox(height: 12,),
                      _buildDivider(),

                      const SizedBox(height: 12,),
                      _buildPreferenceSection("LANGUAGE", "English", onTap: () {}),
                      _buildDivider(),
                      const SizedBox(height: 12,),

                      const SizedBox(height: 12,),
                      _buildPreferenceSection("UNIT", "Metric (cm)", onTap: () {}),
                      _buildDivider(),
                      const SizedBox(height: 12,),

                      _buildPreferenceSection("CURRENCY", "USD (\$)", onTap: () {}),
                      const SizedBox(height: 144,),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text("UPDATE PREFERENCES", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
    ]
      )
    );
  }

  Widget _buildPreferenceSection(String label, String value, {required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Body2_b.style),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 15)),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return const Divider(color: Colors.white12, thickness: 1);
  }
}