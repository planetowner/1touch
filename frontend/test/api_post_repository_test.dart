import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/posts/api/api_post_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/models/post.dart';

void main() {
  test('requests and maps a team post feed with Bearer headers', () async {
    final repository = ApiPostRepository(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/posts');
        expect(request.url.queryParameters, {
          'team_id': '83',
          'sort': 'newest',
          'period': 'all_time',
          'limit': '50',
          'offset': '0',
        });
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Authorization'], 'Bearer session-token');
        return http.Response(jsonEncode(_feedJson()), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {'Authorization': 'Bearer session-token'},
    );

    final posts = await repository.loadPosts(teamId: 83);
    final post = posts.single;

    expect(post.postId, 42);
    expect(post.teamId, 83);
    expect(post.userId, 1001);
    expect(post.username, 'planetowner');
    expect(post.avatarUrl, 'https://api.1touch.football/v1/users/1001/avatar');
    expect(post.likeCount, 12);
    expect(post.commentCount, 3);
    expect(post.liked, isTrue);
    expect(post.attachments.single.mediaUrl,
        'https://api.1touch.football/v1/attachments/7/content');
    expect(post.mediaUrl, post.attachments.single.mediaUrl);
    expect(() => posts.clear(), throwsUnsupportedError);
  });

  test('sends category and device timezone for a date period', () async {
    final repository = ApiPostRepository(
      client: MockClient((request) async {
        expect(request.url.queryParameters, {
          'team_id': '83',
          'category': 'analysis',
          'sort': 'popular',
          'period': 'week',
          'limit': '25',
          'offset': '50',
          'timezone': 'America/New_York',
        });
        return http.Response(
          jsonEncode(_feedJson(items: const [], limit: 25, offset: 50)),
          200,
        );
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
      requestHeaders: const {},
    );

    expect(
      await repository.loadPosts(
        teamId: 83,
        category: PostCategory.analysis,
        sort: PostSort.popular,
        period: PostPeriod.week,
        timezone: 'America/New_York',
        limit: 25,
        offset: 50,
      ),
      isEmpty,
    );
  });

  test('preserves a deleted author and a link attachment', () async {
    final deletedPost = _postJson()
      ..addAll({
        'user_id': null,
        'username': null,
        'avatar_url': null,
        'author_deleted': true,
        'liked': false,
        'attachments': [
          {
            'attachment_id': 8,
            'position': 0,
            'link_url': 'https://example.com/story',
            'media_url': null,
            'content_type': null,
            'byte_size': null,
          },
        ],
      });
    final repository = ApiPostRepository(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(_feedJson(items: [deletedPost])),
          200,
        ),
      ),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    final post = (await repository.loadPosts(teamId: 83)).single;

    expect(post.userId, isNull);
    expect(post.authorDeleted, isTrue);
    expect(post.username, isNull);
    expect(post.avatarUrl, isNull);
    expect(post.mediaUrl, isNull);
    expect(post.attachments.single.linkUrl, 'https://example.com/story');
  });

  test('rejects invalid local query values before requesting', () async {
    var requests = 0;
    final repository = ApiPostRepository(
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(repository.loadPosts(teamId: 0), throwsRangeError);
    await expectLater(
      repository.loadPosts(teamId: 83, limit: 101),
      throwsRangeError,
    );
    await expectLater(
      repository.loadPosts(teamId: 83, offset: -1),
      throwsRangeError,
    );
    await expectLater(
      repository.loadPosts(teamId: 83, period: PostPeriod.today),
      throwsArgumentError,
    );
    expect(requests, 0);
  });

  test('rejects HTTP, malformed, mismatched, and invalid attachment responses',
      () async {
    final wrongTeam = _postJson()..['team_id'] = 9;
    final invalidAttachment = _postJson()
      ..['attachments'] = [
        {
          'attachment_id': 7,
          'position': 0,
          'link_url': 'https://example.com',
          'media_url': '/v1/attachments/7/content',
          'content_type': 'image/jpeg',
          'byte_size': 2048,
        },
      ];
    final responses = [
      http.Response('Unauthorized', 401),
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode(_feedJson(limit: 25)), 200),
      http.Response(jsonEncode(_feedJson(items: [wrongTeam])), 200),
      http.Response(jsonEncode(_feedJson(items: [invalidAttachment])), 200),
    ];
    var index = 0;
    final repository = ApiPostRepository(
      client: MockClient((_) async => responses[index++]),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(
      repository.loadPosts(teamId: 83),
      throwsA(isA<http.ClientException>()),
    );
    for (var i = 0; i < responses.length - 1; i++) {
      await expectLater(
        repository.loadPosts(teamId: 83),
        throwsFormatException,
      );
    }
  });

  test('reports a post with Bearer authentication', () async {
    final repository = ApiPostRepository(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/posts/42/report');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Content-Type'], 'application/json');
        expect(request.headers['Authorization'], 'Bearer session-token');
        expect(jsonDecode(request.body), {'reason': 'Spam'});
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {'Authorization': 'Bearer session-token'},
    );

    await expectLater(
      repository.reportPost(postId: 42, reason: '  Spam  '),
      completes,
    );
  });

  test('rejects invalid report values before requesting', () async {
    var requests = 0;
    final repository = ApiPostRepository(
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(
      repository.reportPost(postId: 0, reason: 'Spam'),
      throwsRangeError,
    );
    await expectLater(
      repository.reportPost(postId: 42, reason: '   '),
      throwsArgumentError,
    );
    await expectLater(
      repository.reportPost(
        postId: 42,
        reason: ''.padRight(maxPostReportReasonLength + 1, 'x'),
      ),
      throwsArgumentError,
    );
    expect(requests, 0);
  });

  test('rejects failed and malformed report responses', () async {
    final responses = [
      http.Response('Forbidden', 403),
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode({}), 200),
      http.Response(jsonEncode({'ok': false}), 200),
    ];
    var responseIndex = 0;
    final repository = ApiPostRepository(
      client: MockClient((_) async => responses[responseIndex++]),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(
      repository.reportPost(postId: 42, reason: 'Spam'),
      throwsA(isA<http.ClientException>()),
    );
    for (var index = 1; index < responses.length; index++) {
      await expectLater(
        repository.reportPost(postId: 42, reason: 'Spam'),
        throwsFormatException,
      );
    }
  });

  test('keeps post creation disabled in the API repository', () {
    final repository = ApiPostRepository(
      client: MockClient((_) async => http.Response('{}', 200)),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    expect(
      () => repository.createPost(
        const CreatePostInput(
          teamId: 83,
          category: PostCategory.general,
          title: 'Title',
          body: 'Body',
        ),
      ),
      throwsUnsupportedError,
    );
  });
}

Map<String, dynamic> _feedJson({
  List<Map<String, dynamic>>? items,
  int limit = 50,
  int offset = 0,
}) =>
    {
      'items': items ?? [_postJson()],
      'limit': limit,
      'offset': offset,
    };

Map<String, dynamic> _postJson() => {
      'post_id': 42,
      'team_id': 83,
      'user_id': 1001,
      'category': 'analysis',
      'title': 'Pressing structure',
      'body': 'A tactical breakdown.',
      'created_at': '2026-09-14T10:00:00Z',
      'state': 'active',
      'edited_at': null,
      'username': 'planetowner',
      'avatar_url': '/v1/users/1001/avatar',
      'author_deleted': false,
      'like_count': 12,
      'comment_count': 3,
      'liked': 1,
      'attachments': [
        {
          'attachment_id': 7,
          'position': 0,
          'link_url': null,
          'media_url': '/v1/attachments/7/content',
          'content_type': 'image/jpeg',
          'byte_size': 2048,
        },
      ],
    };
