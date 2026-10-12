import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class AppRuleNotice extends StatelessWidget {
  const AppRuleNotice(
      {super.key, required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  static Color backgroundColorOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppPalette.white
          : AppPalette.black;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? const Color(0xFF090A0A) : AppPalette.white;
    return ColoredBox(
      color: backgroundColorOf(context),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          // 기존 두 줄 높이 56에서 글 높이 31.2를 뺀 여백을 한 줄에도 적용해요.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12.4, 54, 12.4),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                message,
                style: Eyebrow.style.copyWith(
                  color: foreground,
                  height: 1.30,
                ),
              ),
            ),
          ),
          // 40×40 터치 영역이 안내 높이를 늘리지 않도록 중앙에 겹쳐 놓아요.
          Positioned(
            right: 14,
            child: Semantics(
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
          ),
        ],
      ),
    );
  }
}
