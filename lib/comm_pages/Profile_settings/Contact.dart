import "package:flutter/material.dart";
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
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
                      Text("Contact", style: Body1.style),
                      Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
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
            Expanded(
              child: Text(
                value,
                style: Body1.style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: AppColors.of(context).divider,
      thickness: 1,
      height: 1,
    );
  }
}
