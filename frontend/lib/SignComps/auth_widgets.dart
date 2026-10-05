import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';

/// 인증 화면에서도 앱의 현재 locale 타이포그래피를 사용해요.
abstract final class AuthStyles {
  static const inputHeight = 40.0;
  static TextStyle get body => Body1.style;
  static TextStyle get label => Body2.style;
  static TextStyle get emphasis => Body2_b.style;

  // 가입 화면의 영문은 Figma의 130% 줄 높이를 쓰고, 한국어 규칙은 유지해요.
  static TextStyle signupTextStyle(TextStyle style) => style.copyWith(
        height:
            appLocaleController.value.languageCode == 'ko' ? style.height : 1.3,
        letterSpacing: style.letterSpacing ?? 0,
        fontFamilyFallback: const ['Pretendard'],
      );

  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0A0A0A)
          : AppColors.of(context).pageBackground;

  static InputDecoration inputDecoration(
    BuildContext context,
    String hint, {
    EdgeInsetsGeometry? contentPadding,
    TextStyle? textStyle,
    Widget? suffixIcon,
  }) {
    final inputStyle = textStyle ?? body;
    final colors = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none);
    // 언어별 줄 높이가 달라도 입력칸은 40으로 맞추고, 오류 문구는 아래에 펼쳐져요.
    // 힌트의 소수점 줄 높이는 올림되어 배치돼요(영문 19.5 → 20).
    final lineHeight =
        (inputStyle.fontSize! * inputStyle.height!).ceilToDouble();
    final verticalPadding = (inputHeight - lineHeight) / 2;
    return InputDecoration(
      visualDensity: VisualDensity.standard,
      hintText: hint,
      hintStyle:
          inputStyle.copyWith(color: colors.onSurface.withValues(alpha: .6)),
      isDense: true,
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? AppPalette.white.withValues(alpha: .2)
          : AppColors.of(context).subtleBackground,
      contentPadding: contentPadding ??
          EdgeInsets.fromLTRB(16, verticalPadding, 8, verticalPadding),
      suffixIcon: suffixIcon,
      // 눈·재시도 아이콘이 기본 최소 크기로 입력칸 높이를 늘리지 않게 해요.
      suffixIconConstraints: const BoxConstraints.tightFor(
          width: inputHeight, height: inputHeight),
      border: border,
      enabledBorder: border,
      focusedBorder: border,
      disabledBorder: border,
    );
  }
}

class AuthInput extends StatelessWidget {
  const AuthInput(
      {super.key,
      required this.label,
      required this.controller,
      this.fieldKey,
      this.fieldHeight = AuthStyles.inputHeight,
      this.enabled = true,
      this.obscureText = false,
      this.keyboardType,
      this.textInputAction,
      this.autofillHints,
      this.suffixIcon,
      this.contentPadding = const EdgeInsets.fromLTRB(16, 8, 8, 8),
      this.onSubmitted});

  final String label;
  final TextEditingController controller;
  final Key? fieldKey;
  final double fieldHeight;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? suffixIcon;
  final EdgeInsetsGeometry contentPadding;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          height: 22 * MediaQuery.textScalerOf(context).scale(1),
          child: Text(label, style: AuthStyles.label)),
      const SizedBox(height: 8),
      SizedBox(
        height: fieldHeight * MediaQuery.textScalerOf(context).scale(1),
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
          decoration: AuthStyles.inputDecoration(
            context,
            label,
            contentPadding: contentPadding,
            suffixIcon: suffixIcon,
          ),
        ),
      ),
    ]);
  }
}

class AuthPasswordVisibilityButton extends StatelessWidget {
  const AuthPasswordVisibilityButton({
    super.key,
    required this.obscureText,
    required this.onPressed,
    this.compact = false,
  });

  final bool obscureText;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return IconButton(
      onPressed: onPressed,
      constraints:
          compact ? const BoxConstraints.tightFor(width: 40, height: 40) : null,
      padding: compact ? const EdgeInsets.all(8) : null,
      icon: obscureText
          ? SvgPicture.asset(
              'assets/auth/visibility_off.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            )
          : Icon(Icons.visibility, color: color, size: 24),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.loading = false,
      this.progressKey,
      this.buttonKey,
      this.textStyle});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Key? progressKey;
  final Key? buttonKey;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        key: buttonKey,
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
                style: (textStyle ?? AuthStyles.emphasis)
                    .copyWith(color: AuthStyles.background(context))),
      ),
    );
  }
}
