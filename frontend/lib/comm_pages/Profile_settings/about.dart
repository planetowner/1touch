import "package:flutter/material.dart";
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/services/mobile_ads_service.dart';
// import 'package:go_router/go_router.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  bool _showingPrivacyOptions = false;

  Future<void> _showPrivacyOptions() async {
    setState(() => _showingPrivacyOptions = true);
    final success = await MobileAdsService.showPrivacyOptions();
    if (!mounted) return;
    setState(() => _showingPrivacyOptions = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(context,
            'Unable to open ad privacy choices. Please try again.')),
      ));
    }
  }

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
                        tr(context, "About"),
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
                    _buildListItem(context, tr(context, "Legal"), () {
                      // TODO: Navigate or show dialog
                    }),
                    _buildDivider(),
                    _buildListItem(context, tr(context, "Terms of Service"),
                        () {
                      // TODO: Navigate or show dialog
                    }),
                    _buildDivider(),
                    _buildListItem(context, tr(context, "Privacy Policy"), () {
                      // TODO: Navigate or show dialog
                    }),
                    _buildDivider(),
                    ValueListenableBuilder<bool>(
                      valueListenable: MobileAdsService.privacyOptionsRequired,
                      builder: (context, required, _) => required
                          ? Column(children: [
                              _buildListItem(
                                  context,
                                  tr(context, 'Ad privacy choices'),
                                  _showingPrivacyOptions
                                      ? null
                                      : _showPrivacyOptions),
                              _buildDivider(),
                            ])
                          : const SizedBox.shrink(),
                    ),
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
      BuildContext context, String title, VoidCallback? onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(tr(context, title), style: Body1.style),
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
