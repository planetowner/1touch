import "package:flutter/material.dart";
import 'package:onetouch/core/stylesheet_dark.dart';
// import 'package:go_router/go_router.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
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
                        "About",
                        style: Body1.style,
                      ),
                      const Icon(Icons.search, color: Colors.white),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Expanded(child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _buildListItem(context, "Legal", () {
                      // TODO: Navigate or show dialog
                    }),
                    _buildDivider(),

                    _buildListItem(context, "Terms of Service", () {
                      // TODO: Navigate or show dialog
                    }),
                    _buildDivider(),

                    _buildListItem(context, "Privacy Policy", () {
                      // TODO: Navigate or show dialog
                    }),
                    _buildDivider(),

                    _buildListItem(context, "Visit Instagram", () {
                      // TODO: Open Instagram link
                    }),
                    _buildDivider(),
                  ],
                ))
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(BuildContext context, String title, VoidCallback onTap) {
    return ListTile(
      title: Text(title, style: Body1.style),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(
      color: Color(0xFF3A3A3A),
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
    );
  }
}