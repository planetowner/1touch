import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class AppRuleNotice extends StatelessWidget {
  const AppRuleNotice(
      {super.key,
      required this.message,
      required this.onClose,
      this.contentPadding,
      this.alignCloseIconWithText = false});

  final String message;
  final VoidCallback onClose;
  final EdgeInsets? contentPadding;
  final bool alignCloseIconWithText;

  static Color backgroundColorOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppPalette.white
          : AppPalette.black;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? const Color(0xFF090A0A) : AppPalette.white;
    final textStyle = Eyebrow.style.copyWith(color: foreground, height: 1.30);
    // 최소 높이 때문에 늘어난 글자 박스 대신 실제 한 줄 높이에 X 그림을 맞춰요.
    final iconOffset = alignCloseIconWithText
        ? (contentPadding?.top ?? 12.4) +
            textStyle.fontSize! * textStyle.height! / 2 -
            20
        : 0.0;
    return ColoredBox(
      color: backgroundColorOf(context),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          // 한 줄 안내도 닫기 버튼의 40×40 터치 영역보다 작아지지 않게 해요.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: contentPadding ??
                  const EdgeInsets.fromLTRB(24, 12.4, 54, 12.4),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  message,
                  style: textStyle,
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
                  child: Transform.translate(
                    offset: Offset(0, iconOffset),
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: foreground,
                    ),
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
