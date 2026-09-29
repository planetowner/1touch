import 'package:flutter/widgets.dart';
import 'package:onetouch/l10n/app_localizations.dart';

/// 글·댓글·답글의 작성자 이름은 같은 규칙으로 표시해요.
String communityAuthorLabel({
  required String? username,
  String? displayName,
  required bool authorDeleted,
  Locale locale = const Locale('en'),
}) {
  if (authorDeleted) return translateMessage(locale, 'Deleted user');

  final normalizedDisplayName = displayName?.trim();
  if (normalizedDisplayName != null && normalizedDisplayName.isNotEmpty) {
    return normalizedDisplayName;
  }

  final normalizedUsername = username?.trim();
  if (normalizedUsername == null || normalizedUsername.isEmpty) {
    return translateMessage(locale, 'Unknown user');
  }
  return '@$normalizedUsername';
}
