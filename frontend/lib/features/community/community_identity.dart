import 'package:flutter/widgets.dart';
import 'package:onetouch/l10n/app_localizations.dart';

/// Canonical public identity used for posts, comments, replies, and reactions.
String communityUsernameLabel({
  required String? username,
  required bool authorDeleted,
  Locale locale = const Locale('en'),
}) {
  if (authorDeleted) return translateMessage(locale, 'Deleted user');

  final normalizedUsername = username?.trim();
  if (normalizedUsername == null || normalizedUsername.isEmpty) {
    return translateMessage(locale, 'Unknown user');
  }
  return '@$normalizedUsername';
}
