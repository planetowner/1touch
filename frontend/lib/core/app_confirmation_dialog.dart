import 'package:flutter/material.dart';
import 'package:onetouch/core/app_action_button.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/l10n/app_localizations.dart';

/// 로그아웃과 계정 삭제는 같은 배치에 문구와 확인 버튼 색상만 다르게 써요.
class AppConfirmationDialog extends StatelessWidget {
  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.confirmForegroundColor = AppPalette.black,
    this.cardKey,
    this.confirmButtonKey,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmForegroundColor;
  final Key? cardKey;
  final Key? confirmButtonKey;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? AppPalette.white : AppPalette.black;
    // Archivo 가변 글꼴의 기본 굵기(600) 대신 시안의 굵기를 지정해요.
    const buttonStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      fontVariations: [FontVariation.weight(700)],
      letterSpacing: 0,
      height: 1.30,
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor:
          isDark ? AppPalette.lightGrey : AppPalette.lightModeDarkGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        key: cardKey,
        width: 345,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation.weight(700)],
                  letterSpacing: 0,
                  height: 1.10,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  color: foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  fontVariations: const [FontVariation.weight(400)],
                  letterSpacing: 0,
                  height: 1.30,
                ),
              ),
              const SizedBox(height: 24),
              AppActionButton(
                buttonKey: confirmButtonKey,
                label: confirmLabel,
                onPressed: () => Navigator.of(context).pop(true),
                backgroundColor: AppPalette.white,
                foregroundColor: confirmForegroundColor,
                textStyle: buttonStyle,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: foreground,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  trUpper(context, 'Cancel'),
                  textAlign: TextAlign.center,
                  style: buttonStyle.copyWith(
                    color: foreground,
                    decoration: TextDecoration.underline,
                    decorationColor: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
