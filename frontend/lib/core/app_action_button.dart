import 'package:flutter/material.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/stylesheet.dart';

/// 인증·커뮤니티의 가로 채움 버튼은 모양과 처리 중 상태를 함께 관리해요.
class AppActionButton extends StatelessWidget {
  const AppActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.progressKey,
    this.buttonKey,
    this.textStyle,
    this.backgroundColor,
    this.foregroundColor,
    this.height,
    this.padding = const EdgeInsets.all(16),
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Key? progressKey;
  final Key? buttonKey;
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = foregroundColor ?? colors.surface;
    final style = textStyle ??
        Body2_b.style.copyWith(
          height: appLocaleController.value.languageCode == 'ko' ? 1.6 : 1.3,
        );
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        key: buttonKey,
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor ?? colors.onSurface,
          foregroundColor: foreground,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: padding,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        // 처리 중에도 글자가 차지하던 높이를 유지해 버튼이 움직이지 않아요.
        child: Stack(alignment: Alignment.center, children: [
          Visibility(
            visible: !loading,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Text(label,
                textAlign: TextAlign.center,
                style: style.copyWith(color: foreground)),
          ),
          if (loading)
            Positioned.fill(
                child: Center(
                    child: SizedBox.square(
              key: progressKey,
              dimension: 22,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: foreground),
            ))),
        ]),
      ),
    );
  }
}
