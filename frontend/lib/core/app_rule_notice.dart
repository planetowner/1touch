import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class AppRuleNotice extends StatelessWidget {
  const AppRuleNotice(
      {super.key, required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? const Color(0xFF090A0A) : AppPalette.white;
    return ColoredBox(
      color: isDark ? AppPalette.white : AppPalette.black,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 14, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: Eyebrow.style.copyWith(
                  color: foreground,
                  height: 1.30,
                ),
              ),
            ),
            Semantics(
              button: true,
              label: tr(context, 'Close'),
              child: GestureDetector(
                key: const ValueKey('app-rule-notice-close'),
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: SizedBox.square(
                  dimension: 40,
                  child: Icon(
                    Icons.close,
                    size: 20,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
