import 'package:flutter/foundation.dart';

enum CommunityNotificationKind { postReaction, postComment }

@immutable
class CommunityNotification {
  const CommunityNotification({
    required this.notificationId,
    required this.kind,
    required this.postId,
    required this.actorId,
    required this.teamId,
    required this.username,
    this.displayName,
    required this.commentPreview,
    required this.createdAt,
    required this.readAt,
    required this.destination,
    this.commentId,
  });

  final int notificationId;
  final CommunityNotificationKind kind;
  final int postId;
  final int? commentId;
  final int actorId;
  final int teamId;
  final String? username;
  final String? displayName;
  final String commentPreview;
  final DateTime createdAt;
  final DateTime? readAt;
  final String destination;
}

@immutable
class NotificationInboxPageData {
  const NotificationInboxPageData({
    required this.items,
    required this.unreadCount,
    required this.nextBeforeId,
  });

  final List<CommunityNotification> items;
  final int unreadCount;
  final int? nextBeforeId;
}
