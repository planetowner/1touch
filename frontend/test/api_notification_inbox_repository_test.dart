import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/notifications/api/api_notification_inbox_repository.dart';
import 'package:onetouch/data/notifications/notification_inbox.dart';

void main() {
  test('loads and parses a community notification page', () async {
    final repository = _repository((request) async {
      expect(request.method, 'GET');
      expect(request.url.queryParameters, {
        'limit': '20',
        'before_id': '50',
        'team_id': '83',
      });
      expect(request.headers['Authorization'], 'Bearer session');
      return http.Response(jsonEncode(_page()), 200);
    });

    final page = await repository.load(
      beforeId: 50,
      limit: 20,
      teamId: 83,
    );

    expect(page.unreadCount, 2);
    expect(page.nextBeforeId, 6);
    expect(page.items, hasLength(2));
    expect(page.items.first.kind, CommunityNotificationKind.postReaction);
    expect(page.items.last.kind, CommunityNotificationKind.postComment);
    expect(page.items.last.commentId, 40);
    expect(page.items.first.createdAt.isUtc, isTrue);
  });

  test('marks notifications read through the supplied ID', () async {
    final repository = _repository((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/v1/users/me/notifications/read');
      expect(jsonDecode(request.body), {'through_id': 8});
      return http.Response('{"ok":true}', 200);
    });

    await repository.markReadThrough(8);
  });

  test('rejects unsupported notification kinds', () async {
    final page = _page();
    ((page['items'] as List).first as Map<String, dynamic>)['kind'] =
        'team_goal';
    final repository = _repository(
      (_) async => http.Response(jsonEncode(page), 200),
    );

    expect(repository.load(), throwsFormatException);
  });
}

ApiNotificationInboxRepository _repository(
  Future<http.Response> Function(http.Request request) handler,
) =>
    ApiNotificationInboxRepository(
      api: ApiClient(
        client: MockClient(handler),
        baseUri: Uri.parse('https://api.example.com/v1/'),
        requestHeaders: () => const {'Authorization': 'Bearer session'},
      ),
    );

Map<String, dynamic> _page() => {
      'items': [
        {
          'notification_id': 8,
          'kind': 'post_reaction',
          'post_id': 12,
          'comment_id': null,
          'actor_id': 3,
          'created_at': '2026-09-29T15:00:00Z',
          'read_at': null,
          'team_id': 83,
          'username': 'User One',
          'comment_preview': '',
          'destination': '/notifications/post/12',
        },
        {
          'notification_id': 7,
          'kind': 'post_comment',
          'post_id': 12,
          'comment_id': 40,
          'actor_id': 4,
          'created_at': '2026-09-29T14:00:00Z',
          'read_at': '2026-09-29T14:30:00Z',
          'team_id': 83,
          'username': 'User Two',
          'comment_preview': 'Good point',
          'destination': '/notifications/post/12',
        },
      ],
      'unread_count': 2,
      'next_before_id': 6,
    };
