import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

void showGroundRulesModal(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text("📌 Community Ground Rules", style: Heading5.style),
              const SizedBox(height: 16),
              ..._rules.asMap().entries.map((entry) {
                final i = entry.key;
                final rule = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: RichText(
                    text: TextSpan(
                      style: Body2.style,
                      children: [
                        TextSpan(text: "${i + 1}. ", style: Body1_b.style),
                        TextSpan(text: rule['title'], style: Body1_b.style),
                        const TextSpan(text: "\n"),
                        TextSpan(text: rule['subtitle'], style: Body1.style),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 48),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text("I UNDERSTAND!",
                      style: Body2_b.style.copyWith(color: Colors.black)),
                ),
              )
            ],
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