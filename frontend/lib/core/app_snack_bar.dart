import 'package:flutter/material.dart';
import 'package:onetouch/core/app_rule_notice.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  // SnackBar는 무기한 표시를 지원하지 않으므로 기본 배너에 충분히 긴 시간을 사용해요.
  Duration duration = const Duration(days: 3650),
  bool replaceCurrent = false,
  VoidCallback? onTap,
  EdgeInsets? contentPadding,
  bool alignCloseIconWithText = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  // 같은 오류를 여러 번 눌러도 이전 안내가 대기열에 남아 반복되지 않게 해요.
  if (replaceCurrent) messenger.clearSnackBars();
  final notice = AppRuleNotice(
    message: message,
    contentPadding: contentPadding,
    alignCloseIconWithText: alignCloseIconWithText,
    onClose: () =>
        messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.dismiss),
  );
  messenger.showSnackBar(
    SnackBar(
      // 기본 여백을 없애고 고정 안내와 같은 컴포넌트로 높이와 정렬을 맞춰요.
      padding: EdgeInsets.zero,
      elevation: 0,
      behavior: SnackBarBehavior.fixed,
      dismissDirection: DismissDirection.none,
      shape: const RoundedRectangleBorder(),
      // 기기에서 전달한 하단 안전 여백은 기본 SnackBar가 자동으로 적용해요.
      backgroundColor: AppRuleNotice.backgroundColorOf(context),
      duration: duration,
      content: onTap == null
          ? notice
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                messenger.hideCurrentSnackBar();
                onTap();
              },
              child: notice,
            ),
    ),
  );
}
