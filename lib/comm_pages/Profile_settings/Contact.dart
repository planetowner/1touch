import "package:flutter/material.dart";
import 'package:onetouch/core/stylesheet_dark.dart';
// import 'package:go_router/go_router.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black, // Background is black
      body: Stack(
        children: [
          // Gradient Removed

          // Content
          SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        "Contact",
                        style: Body1.style),
                      Icon(Icons.search, color: Colors.white),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      const SizedBox(height: 16),
                      _buildLabel("EMAIL"),
                      const SizedBox(height: 16),
                      _buildValueRow("contact@1touch.com", onTap: () {}),
                      const SizedBox(height: 12),
                      _buildDivider(),

                      const SizedBox(height: 24),
                      _buildLabel("INSTAGRAM"),
                      const SizedBox(height: 16),
                      _buildValueRow("1touch_app", onTap: () {}),
                      const SizedBox(height: 12),
                      _buildDivider(),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: Body2_b.style,
    );
  }

  Widget _buildValueRow(String value, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value, style: Body1.style),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      color: Color(0xFF3A3A3A),
      thickness: 1,
      height: 1,
    );
  }
}