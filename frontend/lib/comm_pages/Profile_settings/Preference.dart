import "package:flutter/material.dart";
// import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'PreferenceDetails.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class PreferencePage extends StatefulWidget {
  const PreferencePage({super.key});

  @override
  State<PreferencePage> createState() => _PreferencePageState();
}

class _PreferencePageState extends State<PreferencePage> {
  static const Map<String, Locale> _languageOptions = {
    'English': Locale('en'),
    'Korean': Locale('ko'),
    'Japanese': Locale('ja'),
    'Chinese': Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  };

  late String _language;
  String _unit = "Metric (cm)";
  String _currency = "USD (\$)";

  final List<String> _unitOptions = ["Metric (cm)", "Imperial (ft/in)"];
  final List<String> _currencyOptions = [
    "USD (\$)",
    "EUR (€)",
    "GBP (£)",
    "KRW (₩)",
    "JPY (¥)"
  ];

  @override
  void initState() {
    super.initState();
    _language = _languageOptions.entries
        .firstWhere(
          (entry) =>
              entry.value.languageCode ==
              appLocaleController.value.languageCode,
          orElse: () => _languageOptions.entries.first,
        )
        .key;
  }

  Future<void> _savePreferences() async {
    await appLocaleController.setLocale(_languageOptions[_language]!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: AppColors.of(context).pageBackground,
        body: Stack(children: [
          // Gradient Removed

          // Content
          SafeArea(
            child: Column(
              children: [
                // AppBar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(tr(context, "Preferences"), style: Body1.style),
                      IconButton(
                        icon: Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        onPressed: () {},
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
                      _buildPreferenceSection(
                        tr(context, "LANGUAGE"),
                        _language,
                        onTap: () => _navigateAndSelect(
                          tr(context, "Language"),
                          _languageOptions.keys.toList(growable: false),
                          _language,
                          (value) => _language = value,
                        ),
                      ),
                      _buildDivider(),
                      const SizedBox(
                        height: 12,
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      _buildPreferenceSection(tr(context, "UNIT"), _unit,
                          onTap: () => _navigateAndSelect(tr(context, "Unit"),
                              _unitOptions, _unit, (val) => _unit = val)),
                      _buildDivider(),
                      const SizedBox(
                        height: 12,
                      ),
                      _buildPreferenceSection(
                          tr(context, "CURRENCY"), _currency,
                          onTap: () => _navigateAndSelect(
                              tr(context, "Currency"),
                              _currencyOptions,
                              _currency,
                              (val) => _currency = val)),
                      const SizedBox(
                        height: 144,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _savePreferences,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.onSurface,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        tr(context, "UPDATE PREFERENCES"),
                        style: Body2_b.style.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]));
  }

  // Helper method to handle navigation and state update
  Future<void> _navigateAndSelect(String title, List<String> options,
      String currentVal, Function(String) onUpdate) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreferenceDetailScreen(
          title: title,
          options: options,
          selectedOption: currentVal,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        onUpdate(result);
      });
    }
  }

  Widget _buildPreferenceSection(String label, String value,
      {VoidCallback? onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, label), style: Body2_b.style),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onTap,
          child: Container(
            color: Colors.transparent, // Ensures the whole area is clickable
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tr(context, value),
                    style: Body1.style,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Divider(color: AppColors.of(context).divider, thickness: 1);
  }
}
