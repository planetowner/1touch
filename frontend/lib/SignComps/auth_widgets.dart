import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';

/// 최종 온보딩의 글꼴을 인증 화면 안에서만 적용해요.
abstract final class AuthStyles {
  static final body = Body1.style
      .copyWith(fontFamily: 'Pretendard', height: 1.6, letterSpacing: 0);
  static final label = Body2.style
      .copyWith(fontFamily: 'Pretendard', height: 1.6, letterSpacing: 0);
  static final emphasis = Body2_b.style
      .copyWith(fontFamily: 'Pretendard', height: 1.6, letterSpacing: 0);

  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0A0A0A)
          : AppColors.of(context).pageBackground;
}

class AuthInput extends StatelessWidget {
  const AuthInput(
      {super.key,
      required this.label,
      required this.controller,
      this.fieldKey,
      this.enabled = true,
      this.obscureText = false,
      this.keyboardType,
      this.textInputAction,
      this.autofillHints,
      this.onSubmitted});

  final String label;
  final TextEditingController controller;
  final Key? fieldKey;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          height: 22 * MediaQuery.textScalerOf(context).scale(1),
          child: Text(label, style: AuthStyles.label)),
      const SizedBox(height: 8),
      SizedBox(
        height: 40 * MediaQuery.textScalerOf(context).scale(1),
        child: TextField(
          key: fieldKey,
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          autocorrect: false,
          enableSuggestions: !obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onSubmitted: onSubmitted,
          style: AuthStyles.body,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            // 데스크톱 기본 밀도가 입력창을 줄이지 않도록 Figma 높이를 유지해요.
            visualDensity: VisualDensity.standard,
            hintText: label,
            hintStyle: AuthStyles.body
                .copyWith(color: colors.onSurface.withValues(alpha: .6)),
            isDense: true,
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? AppPalette.white.withValues(alpha: .2)
                : AppColors.of(context).subtleBackground,
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            border: border,
            enabledBorder: border,
            focusedBorder: border,
            disabledBorder: border,
          ),
        ),
      ),
    ]);
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.loading = false,
      this.progressKey});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Key? progressKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colors.onSurface,
          foregroundColor: AuthStyles.background(context),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: loading
            ? SizedBox.square(
                key: progressKey,
                dimension: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AuthStyles.background(context)))
            : Text(label,
                style: AuthStyles.emphasis
                    .copyWith(color: AuthStyles.background(context))),
      ),
    );
  }
}
