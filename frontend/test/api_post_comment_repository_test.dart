import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/post_comments/api/api_post_comment_repository.dart';
import 'package:onetouch/data/post_comments/post_comment_repository.dart';
import 'package:onetouch/models/post_comment.dart';

void main() {
  test('loads comments in backend cursor order with Bearer headers', () async {
    final repository = ApiPostCommentRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/v1/posts/42/comments');
            expect(request.url.queryParameters, {
              'after_id': '10',
              'limit': '25',
            });
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            return http.Response(
              jsonEncode({
                'items': [
                  _commentJson(commentId: 11),
                  _commentJson(
                    commentId: 12,
                    replyToId: 11,
                    avatarUrl: null,
                    liked: 0,
                  ),
                ],
              }),
              200,
            );
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () =>
              const {'Authorization': 'Bearer session-token'}),
    );

    final comments = await repository.loadForPost(
      postId: 42,
      afterId: 10,
      limit: 25,
    );

    expect(comments.map((comment) => comment.commentId), [11, 12]);
    expect(comments.first.state, PostCommentState.active);
    expect(comments.first.liked, isTrue);
    expect(
      comments.first.avatarUrl,
      'https://api.1touch.football/v1/users/1001/avatar',
    );
    expect(comments.last.replyToId, 11);
    expect(comments.last.avatarUrl, isNull);
    expect(comments.last.liked, isFalse);
    expect(() => comments.clear(), throwsUnsupportedError);
  });

  test('preserves masked comment state and nullable author fields', () async {
    final repository = ApiPostCommentRepository(
      api: ApiClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'items': [
                  _commentJson(
                    commentId: 1,
                    userId: null,
                    username: null,
                    avatarUrl: null,
                    body: '',
                    state: 'blocked',
                    authorDeleted: false,
                    likeCount: 0,
                    liked: false,
                  ),
                ],
              }),
              200,
            ),
          ),
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {}),
    );

    final comment =
        (await repository.loadForPost(postId: 42, afterId: 0)).single;

    expect(comment.state, PostCommentState.blocked);
    expect(comment.userId, isNull);
    expect(comment.username, isNull);
    expect(comment.avatarUrl, isNull);
    expect(comment.authorDeleted, isFalse);
    expect(comment.body, isEmpty);
  });

  test('creates a top-level comment with Bearer authentication', () async {
    final repository = ApiPostCommentRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/v1/posts/42/comments');
            expect(request.url.queryParameters, isEmpty);
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Content-Type'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            expect(jsonDecode(request.body), {
              'body': 'A real comment',
              'reply_to_id': null,
            });
            return http.Response(jsonEncode({'comment_id': 71}), 201);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () =>
              const {'Authorization': 'Bearer session-token'}),
    );

    expect(
      await repository.createComment(
        postId: 42,
        body: '  A real comment  ',
      ),
      71,
    );
  });

  test('rejects invalid comment creation before requesting', () async {
    var requests = 0;
    final repository = ApiPostCommentRepository(
      api: ApiClient(
          client: MockClient((_) async {
            requests++;
            return http.Response('{}', 201);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.createComment(postId: 0, body: 'Comment'),
      throwsRangeError,
    );
    await expectLater(
      repository.createComment(postId: 42, body: '   '),
      throwsArgumentError,
    );
    await expectLater(
      repository.createComment(
        postId: 42,
        body: ''.padRight(maxPostCommentBodyLength + 1, 'x'),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.createComment(
        postId: 42,
        body: 'Reply',
        replyToId: 0,
      ),
      throwsRangeError,
    );
    expect(requests, 0);
  });

  test('rejects failed and malformed comment creation responses', () async {
    final responses = [
      http.Response('Unauthorized', 401),
      http.Response(jsonEncode({'comment_id': '71'}), 201),
      http.Response(jsonEncode({'comment_id': 0}), 201),
    ];
    var index = 0;
    final repository = ApiPostCommentRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[index++]),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.createComment(postId: 42, body: 'Comment'),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(
      repository.createComment(postId: 42, body: 'Comment'),
      throwsFormatException,
    );
    await expectLater(
      repository.createComment(postId: 42, body: 'Comment'),
      throwsFormatException,
    );
  });

  test('rejects invalid local query values before requesting', () async {
    var requests = 0;
    final repository = ApiPostCommentRepository(
      api: ApiClient(
          client: MockClient((_) async {
            requests++;
            return http.Response('{}', 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.loadForPost(postId: 0),
      throwsRangeError,
    );
    await expectLater(
      repository.loadForPost(postId: 42, afterId: -1),
      throwsRangeError,
    );
    await expectLater(
      repository.loadForPost(postId: 42, limit: 101),
      throwsRangeError,
    );
    expect(requests, 0);
  });

  test('rejects HTTP, malformed, mismatched, and unordered responses',
      () async {
    final responses = [
      http.Response('Unauthorized', 401),
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode({'items': 'invalid'}), 200),
      http.Response(
        jsonEncode({
          'items': [_commentJson(commentId: 1, postId: 9)]
        }),
        200,
      ),
      http.Response(
        jsonEncode({
          'items': [
            _commentJson(commentId: 2),
            _commentJson(commentId: 1),
          ],
        }),
        200,
      ),
      http.Response(
        jsonEncode({
          'items': [_commentJson(commentId: 1, state: 'unexpected')],
        }),
        200,
      ),
    ];
    var index = 0;
    final repository = ApiPostCommentRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[index++]),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.loadForPost(postId: 42),
      throwsA(isA<http.ClientException>()),
    );
    for (var i = 1; i < responses.length; i++) {
      await expectLater(
        repository.loadForPost(postId: 42),
        throwsFormatException,
      );
    }
  });
}

Map<String, dynamic> _commentJson({
  required int commentId,
  int postId = 42,
  int? userId = 1001,
  int? replyToId,
  String body = 'A comment',
  String state = 'active',
  String? username = 'planetowner',
  String? avatarUrl = '/v1/users/1001/avatar',
  bool authorDeleted = false,
  int likeCount = 3,
  Object liked = true,
}) {
  return {
    'comment_id': commentId,
    'post_id': postId,
    'user_id': userId,
    'reply_to_id': replyToId,
    'body': body,
    'created_at': '2026-09-15T12:00:00Z',
    'edited_at': null,
    'state': state,
    'username': username,
    'avatar_url': avatarUrl,
    'author_deleted': authorDeleted,
    'like_count': likeCount,
    'liked': liked,
  };
}
