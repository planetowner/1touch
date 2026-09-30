import 'dart:convert';

import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/notifications/notification_inbox.dart';
import 'package:onetouch/data/notifications/notification_inbox_repository.dart';

class ApiNotificationInboxRepository implements NotificationInboxRepository {
  ApiNotificationInboxRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<NotificationInboxPageData> load({
    int? beforeId,
    int limit = 30,
    int? teamId,
  }) async {
    if (beforeId != null && beforeId < 1) {
      throw RangeError.value(beforeId, 'beforeId', 'Must be positive');
    }
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    if (teamId != null && teamId < 1) {
      throw RangeError.value(teamId, 'teamId', 'Must be positive');
    }
    final uri = _api.baseUri.resolve('users/me/notifications').replace(
      queryParameters: {
        'limit': '$limit',
        if (beforeId != null) 'before_id': '$beforeId',
        if (teamId != null) 'team_id': '$teamId',
      },
    );
    final response = await _api.get(uri);
    return _decodePage(_api.decodeJson<Map<String, dynamic>>(response));
  }

  @override
  Future<void> markReadThrough(int notificationId) async {
    if (notificationId < 1) {
      throw RangeError.value(
        notificationId,
        'notificationId',
        'Must be positive',
      );
    }
    final response = await _api.post(
      _api.baseUri.resolve('users/me/notifications/read'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'through_id': notificationId}),
    );
    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    if (decoded['ok'] != true) {
      throw const FormatException('Expected notification read ok=true.');
    }
  }

  NotificationInboxPageData _decodePage(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final unreadCount = json['unread_count'];
    final nextBeforeId = json['next_before_id'];
    if (rawItems is! List || unreadCount is! int || unreadCount < 0) {
      throw const FormatException('Invalid notification inbox response.');
    }
    if (nextBeforeId != null && (nextBeforeId is! int || nextBeforeId < 1)) {
      throw const FormatException('Invalid next_before_id.');
    }
    final items = rawItems
        .map((item) => _decodeItem(_objectMap(item, 'notification item')))
        .toList(growable: false);
    for (var i = 1; i < items.length; i++) {
      if (items[i - 1].notificationId <= items[i].notificationId) {
        throw const FormatException(
          'Expected notifications in descending ID order.',
        );
      }
    }
    return NotificationInboxPageData(
      items: List.unmodifiable(items),
      unreadCount: unreadCount,
      nextBeforeId: nextBeforeId as int?,
    );
  }

  CommunityNotification _decodeItem(Map<String, dynamic> json) {
    final notificationId = _positiveInt(json, 'notification_id');
    final postId = _positiveInt(json, 'post_id');
    final actorId = _positiveInt(json, 'actor_id');
    final teamId = _positiveInt(json, 'team_id');
    final kind = switch (_requiredString(json, 'kind')) {
      'post_reaction' => CommunityNotificationKind.postReaction,
      'post_comment' => CommunityNotificationKind.postComment,
      final value => throw FormatException(
          'Unrecognized community notification kind "$value".',
        ),
    };
    final commentId = json['comment_id'];
    if (commentId != null && (commentId is! int || commentId < 1)) {
      throw const FormatException('Invalid comment_id.');
    }
    if (kind == CommunityNotificationKind.postComment && commentId == null) {
      throw const FormatException(
          'Post comment notification needs comment_id.');
    }
    final createdAt = _dateTime(json, 'created_at');
    final readAt = json['read_at'] == null ? null : _dateTime(json, 'read_at');
    final destination = _requiredString(json, 'destination');
    if (destination != '/notifications/post/$postId') {
      throw const FormatException('Unexpected notification destination.');
    }
    return CommunityNotification(
      notificationId: notificationId,
      kind: kind,
      postId: postId,
      commentId: commentId as int?,
      actorId: actorId,
      teamId: teamId,
      username: _requiredString(json, 'username'),
      commentPreview:
          _requiredString(json, 'comment_preview', allowEmpty: true),
      createdAt: createdAt,
      readAt: readAt,
      destination: destination,
    );
  }

  Map<String, dynamic> _objectMap(Object? value, String field) {
    if (value is! Map) throw FormatException('Expected $field object.');
    return value.cast<String, dynamic>();
  }

  int _positiveInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int || value < 1) {
      throw FormatException('Expected positive integer "$key".');
    }
    return value;
  }

  String _requiredString(
    Map<String, dynamic> json,
    String key, {
    bool allowEmpty = false,
  }) {
    final value = json[key];
    if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
      throw FormatException('Expected string "$key".');
    }
    return value;
  }

  DateTime _dateTime(Map<String, dynamic> json, String key) {
    final value = _requiredString(json, key);
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.isUtc) {
      throw FormatException('Expected UTC ISO 8601 "$key".');
    }
    return parsed;
  }
}
