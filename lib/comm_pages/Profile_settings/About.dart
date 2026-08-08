import "package:flutter/material.dart";
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
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
      backgroundColor: AppColors.of(context).pageBackground,
      body: Stack(
        children: [
          // Gradient Removed

          // Content
          SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        "About",
                        style: Body1.style,
                      ),
                      SizedBox(
                        width: 48,
                        child: Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Expanded(
                    child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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
                  ],
                ))
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(
      BuildContext context, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: Body1.style),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: Theme.of(context).colorScheme.onSurface,
        size: 16,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: AppColors.of(context).divider,
      height: 1,
      thickness: 1,
    );
  }
}
