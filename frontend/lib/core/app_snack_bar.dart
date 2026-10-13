import 'package:flutter/material.dart';
import 'package:onetouch/core/app_rule_notice.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 4),
  bool replaceCurrent = false,
  EdgeInsets? contentPadding,
  bool alignCloseIconWithText = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  if (replaceCurrent) messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      // 기본 여백을 없애고 고정 안내와 같은 컴포넌트로 높이와 정렬을 맞춰요.
      padding: EdgeInsets.zero,
      elevation: 0,
      behavior: SnackBarBehavior.fixed,
      shape: const RoundedRectangleBorder(),
      // 기기에서 전달한 하단 안전 여백은 기본 SnackBar가 자동으로 적용해요.
      backgroundColor: AppRuleNotice.backgroundColorOf(context),
      duration: duration,
      content: AppRuleNotice(
        message: message,
        contentPadding: contentPadding,
        alignCloseIconWithText: alignCloseIconWithText,
        onClose: () =>
            messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.dismiss),
      ),
    ),
  );
}
