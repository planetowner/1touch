import "package:flutter/material.dart";
// import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/display_preferences.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'preference_details.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class PreferencePage extends StatefulWidget {
  const PreferencePage({super.key, this.bottomNavigationBarBuilder});

  final WidgetBuilder? bottomNavigationBarBuilder;

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
  late MeasurementUnit _unit;
  late DisplayCurrency _currency;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _unit = appDisplayPreferences.value.unit;
    _currency = appDisplayPreferences.value.currency;
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
    setState(() => _saving = true);
    try {
      await appDisplayPreferences.save(
        DisplayPreferences(unit: _unit, currency: _currency),
      );
      await appLocaleController.setLocale(_languageOptions[_language]!);
      if (mounted) Navigator.pop(context);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(tr(context, 'Unable to save preferences. Please try again.')),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                        trUpper(context, "Language"),
                        _language,
                        onTap: () => _navigateAndSelect(
                          tr(context, "Language"),
                          _languageOptions.keys.toList(growable: false),
                          _language,
                          (language) => language,
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
                      _buildPreferenceSection(
                          trUpper(context, "Unit"), _unit.label,
                          onTap: () => _navigateAndSelect(
                              tr(context, "Unit"),
                              MeasurementUnit.values,
                              _unit,
                              (unit) => unit.label,
                              (unit) => _unit = unit)),
                      _buildDivider(),
                      const SizedBox(
                        height: 12,
                      ),
                      _buildPreferenceSection(
                          trUpper(context, "Currency"), _currency.label,
                          onTap: () => _navigateAndSelect(
                              tr(context, "Currency"),
                              DisplayCurrency.values,
                              _currency,
                              (currency) => currency.label,
                              (currency) => _currency = currency)),
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
                      onPressed: _saving ? null : _savePreferences,
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
                        tr(context, _saving ? 'Saving…' : "UPDATE PREFERENCES"),
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

  // 선택 화면은 표시 문구만 다루고, 실제 설정값은 이곳에서 함께 변환해요.
  Future<void> _navigateAndSelect<T>(
      String title,
      List<T> options,
      T currentVal,
      String Function(T) labelFor,
      ValueChanged<T> onUpdate) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) {
          final detail = PreferenceDetailScreen(
            title: title,
            options: options.map(labelFor).toList(growable: false),
            selectedOption: labelFor(currentVal),
          );
          final bottomNavigationBar =
              widget.bottomNavigationBarBuilder?.call(context);
          return bottomNavigationBar == null
              ? detail
              : Scaffold(
                  body: detail,
                  bottomNavigationBar: bottomNavigationBar,
                );
        },
      ),
    );

    if (mounted && result != null) {
      setState(() {
        onUpdate(options.firstWhere((option) => labelFor(option) == result));
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
