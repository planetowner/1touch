import 'package:onetouch/core/app_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';

/// 인증 화면에서도 앱의 현재 locale 타이포그래피를 사용해요.
abstract final class AuthStyles {
  static const inputHeight = 40.0;
  static const signupInputHeight = 56.0;
  static double signupLabelInset(bool password) => password ? 6 : 8;
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
      AppColors.of(context).pageBackground;

  static InputDecoration signupInputDecoration(BuildContext context,
      {bool password = false}) {
    final style = signupTextStyle(body);
    // 힌트 없는 EditableText의 정수 줄 높이에 맞춰 입력칸 높이 56을 유지해요.
    final lineHeight = MediaQuery.textScalerOf(context)
        .scale(style.fontSize! * style.height!)
        .floorToDouble();
    final inset = signupLabelInset(password);
    return inputDecoration(context, null, textStyle: style, gapPadding: 0)
        .copyWith(
      // 라벨은 입력칸 안에 고정하고, 빈 값에는 예시나 비밀번호 점을 넣지 않아요.
      contentPadding: EdgeInsets.fromLTRB(
          12, signupInputHeight - lineHeight - inset, 8, inset),
      counterText: '',
      suffixIconConstraints:
          const BoxConstraints.tightFor(width: 48, height: signupInputHeight),
    );
  }

  static InputDecoration inputDecoration(
    BuildContext context,
    String? hint, {
    EdgeInsetsGeometry? contentPadding,
    TextStyle? textStyle,
    Widget? suffixIcon,
    double gapPadding = 4,
  }) {
    final inputStyle = textStyle ?? body;
    final colors = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
        gapPadding: gapPadding);
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

/// 가입 화면의 라벨은 포커스나 입력값에 따라 움직이지 않아요.
class AuthInsetLabel extends StatelessWidget {
  const AuthInsetLabel({
    super.key,
    required this.label,
    required this.child,
    this.password = false,
  });

  final String label;
  final Widget child;
  final bool password;

  @override
  Widget build(BuildContext context) => _AuthFieldScrollPadding(
          child: Stack(children: [
        Semantics(label: label, child: child),
        Positioned(
          left: 12,
          right: 12,
          top: AuthStyles.signupLabelInset(password),
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Text(label,
                  style: AuthStyles.signupTextStyle(Eyebrow.style).copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: .5),
                  )),
            ),
          ),
        ),
      ]));
}

class _AuthFieldScrollPadding extends SingleChildRenderObjectWidget {
  const _AuthFieldScrollPadding({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderAuthFieldScrollPadding();
}

class _RenderAuthFieldScrollPadding extends RenderProxyBox {
  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    // 커서·선택 핸들 대신 입력칸 전체를 기준으로 키보드 위 여백 24를 확보해요.
    super.showOnScreen(
      descendant: this,
      rect: Rect.fromLTRB(0, 0, size.width, size.height + 24),
      duration: duration,
      curve: curve,
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
    return AppActionButton(
      label: label,
      onPressed: onPressed,
      loading: loading,
      progressKey: progressKey,
      buttonKey: buttonKey,
      textStyle: textStyle ?? AuthStyles.emphasis,
      backgroundColor: Theme.of(context).colorScheme.onSurface,
      foregroundColor: AuthStyles.background(context),
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
