import 'package:flutter/foundation.dart';

@immutable
class FixtureChatMessage {
  const FixtureChatMessage({
    required this.messageId,
    required this.fixtureId,
    required this.userId,
    required this.username,
    required this.text,
    required this.createdAt,
    required this.avatarUrl,
    required this.authorDeleted,
  });

  final int messageId;
  final int fixtureId;
  final int? userId;
  final String? username;
  final String text;
  final DateTime createdAt;
  final String? avatarUrl;
  final bool authorDeleted;

  String get displayUsername => authorDeleted ? 'Deleted user' : username!;
}
