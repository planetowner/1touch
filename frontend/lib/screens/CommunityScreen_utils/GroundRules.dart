import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

void showGroundRulesModal(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final colors = Theme.of(context).colorScheme;
      return Dialog(
        key: const ValueKey('community-ground-rules-dialog'),
        backgroundColor: isDark ? AppPalette.darkGrey : AppPalette.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.push_pin_outlined, color: colors.onSurface),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Community Ground Rules",
                        style: Heading5.style.copyWith(color: colors.onSurface),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _rules.asMap().entries.map((entry) {
                        final i = entry.key;
                        final rule = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 32,
                                child: Text(
                                  "${i + 1}.",
                                  key: ValueKey('ground-rule-number-${i + 1}'),
                                  style: Body1_b.style
                                      .copyWith(color: colors.onSurface),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rule['title']!,
                                      key: ValueKey(
                                          'ground-rule-title-${i + 1}'),
                                      style: Body1_b.style
                                          .copyWith(color: colors.onSurface),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      rule['subtitle']!,
                                      key: ValueKey(
                                          'ground-rule-subtitle-${i + 1}'),
                                      style: Body1.style
                                          .copyWith(color: colors.onSurface),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.onSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      "I UNDERSTAND!",
                      style: Body2_b.style.copyWith(color: colors.onPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

final List<Map<String, String>> _rules = [
  {
    "title": "Talk football, not trash.",
    "subtitle": "Disagree? Cool. Disrespect? Not here.",
  },
  {
    "title": "No player hate.",
    "subtitle": "Critique the play, not the person.",
  },
  {
    "title": "Respect every team.",
    "subtitle": "Rivalries are fun — as long as they stay respectful.",
  },
  {
    "title": "Keep it clean.",
    "subtitle": "No spam, slurs, or shady links.",
  },
  {
    "title": "Bring the vibes.",
    "subtitle":
        "Celebrate the game, share hot takes, enjoy the banter — just don’t be a jerk.",
  },
];
