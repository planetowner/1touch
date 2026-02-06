import "package:flutter/material.dart";
// import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'PreferenceDetails.dart';

class PreferencePage extends StatefulWidget {
  const PreferencePage({super.key});

  @override
  State<PreferencePage> createState() => _PreferencePageState();
}

class _PreferencePageState extends State<PreferencePage> {
  // 1. State variables to hold current selections
  String _timeZone = "New York (GMT - 5:00)";
  String _language = "English";
  String _unit = "Metric (cm)";
  String _currency = "USD (\$)";

  // 2. Mock Data Options
  final List<String> _timeZoneOptions = [
    "New York (GMT - 5:00)",
    "London (GMT + 0:00)",
    "Paris (GMT + 1:00)",
    "Tokyo (GMT + 9:00)",
    "Sydney (GMT + 11:00)"
  ];
  final List<String> _languageOptions = ["English", "Spanish", "French", "German", "Korean", "Japanese"];
  final List<String> _unitOptions = ["Metric (cm)", "Imperial (ft/in)"];
  final List<String> _currencyOptions = ["USD (\$)", "EUR (€)", "GBP (£)", "KRW (₩)", "JPY (¥)"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.black, // Background Black
        body: Stack(
            children: [
              // Gradient Removed

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
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                          ),
                          const Text("Preferences", style: Body1.style),
                          IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
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
                              "TIME ZONE",
                              _timeZone,
                              onTap: () => _navigateAndSelect("Time Zone", _timeZoneOptions, _timeZone, (val) => _timeZone = val)
                          ),
                          const SizedBox(height: 12,),
                          _buildDivider(),

                          const SizedBox(height: 12,),
                          _buildPreferenceSection(
                              "LANGUAGE",
                              _language,
                              onTap: () => _navigateAndSelect("Language", _languageOptions, _language, (val) => _language = val)
                          ),
                          _buildDivider(),
                          const SizedBox(height: 12,),

                          const SizedBox(height: 12,),
                          _buildPreferenceSection(
                              "UNIT",
                              _unit,
                              onTap: () => _navigateAndSelect("Unit", _unitOptions, _unit, (val) => _unit = val)
                          ),
                          _buildDivider(),
                          const SizedBox(height: 12,),

                          _buildPreferenceSection(
                              "CURRENCY",
                              _currency,
                              onTap: () => _navigateAndSelect("Currency", _currencyOptions, _currency, (val) => _currency = val)
                          ),
                          const SizedBox(height: 144,),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text("UPDATE PREFERENCES", style: Body2_b.style.copyWith(color: Colors.black)),
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

  // Helper method to handle navigation and state update
  Future<void> _navigateAndSelect(
      String title,
      List<String> options,
      String currentVal,
      Function(String) onUpdate
      ) async {
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
            color: Colors.transparent, // Ensures the whole area is clickable
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: Body1.style),
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