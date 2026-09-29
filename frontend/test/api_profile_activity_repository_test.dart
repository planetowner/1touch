import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/profile/api/api_profile_activity_repository.dart';
import 'package:onetouch/models/post_comment.dart';
import 'support/profile_activity_fixture.dart';

void main() {
  test('both activity endpoints use the current Bearer session and pagination',
      () async {
    var token = 'first-session';
    final requests = <http.Request>[];
    final repository = ApiProfileActivityRepository(
        api: ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer $token');
        expect(request.headers['Accept'], 'application/json');
        expect(request.url.queryParameters, {'limit': '20', 'offset': '40'});
        return http.Response(
            jsonEncode(activityPageJson(
              [
                request.url.path.endsWith('/posts')
                    ? activityPostJson()
                    : activityCommentJson()
              ],
              limit: 20,
              offset: 40,
            )),
            200);
      }),
      baseUri: Uri.parse('https://api.1touch.football/v1/'),
      requestHeaders: () => {'Authorization': 'Bearer $token'},
    ));

    final posts = await repository.loadPosts(limit: 20, offset: 40);
    token = 'new-session';
    final comments = await repository.loadComments(limit: 20, offset: 40);
    expect(requests.map((request) => request.url.path),
        ['/v1/users/me/posts', '/v1/users/me/comments']);
    expect(posts.single.title, 'My post 42');
    expect(posts.single.avatarUrl,
        'https://api.1touch.football/v1/users/1/avatar');
    expect(posts.single.liked, isTrue);
    expect(comments.single.post.postId, posts.single.postId);
    expect(comments.single.comment.replyToId, 70);
    expect(comments.single.comment.state, PostCommentState.active);
    expect(comments.single.comment.liked, isFalse);
    expect(() => posts.clear(), throwsUnsupportedError);
    expect(() => comments.clear(), throwsUnsupportedError);
  });

  test('comments retain deleted parent authors and reuse attachment mapping',
      () async {
    final item = activityCommentJson();
    (item['post'] as Map<String, dynamic>).addAll({
      'user_id': null,
      'username': null,
      'avatar_url': null,
      'author_deleted': true,
      'attachments': [
        {
          'attachment_id': 7,
          'position': 0,
          'link_url': null,
          'media_url': '/v1/attachments/7/content',
          'content_type': 'image/png',
          'byte_size': 10,
        }
      ],
    });
    final repository = _repository(
        (_) async => http.Response(jsonEncode(activityPageJson([item])), 200));
    final activity = (await repository.loadComments()).single;
    expect(activity.post.authorDeleted, isTrue);
    expect(activity.post.mediaUrl,
        'https://api.1touch.football/v1/attachments/7/content');
    expect(activity.comment.userId, 1);
  });

  for (final kind in ['posts', 'comments']) {
    test('$kind propagates request errors instead of showing an empty activity',
        () async {
      for (final status in [401, 403, 500]) {
        final repository =
            _repository((_) async => http.Response('{}', status));
        await expectLater(
            kind == 'posts'
                ? repository.loadPosts()
                : repository.loadComments(),
            throwsA(isA<http.ClientException>()));
      }
    });

    test('$kind validates pagination and response shape', () async {
      var calls = 0;
      var body = activityPageJson([]);
      final repository = _repository((_) async {
        calls++;
        return http.Response(jsonEncode(body), 200);
      });
      Future<List<Object>> load({int limit = 50, int offset = 0}) =>
          kind == 'posts'
              ? repository.loadPosts(limit: limit, offset: offset)
              : repository.loadComments(limit: limit, offset: offset);
      for (final limit in [0, 101]) {
        await expectLater(load(limit: limit), throwsRangeError);
      }
      await expectLater(load(offset: -1), throwsRangeError);
      expect(calls, 0);
      expect(await load(), isEmpty);
      for (final invalid in [
        {...activityPageJson([]), 'offset': 1},
        {...activityPageJson([]), 'limit': 1},
        {...activityPageJson([]), 'items': null},
        {
          ...activityPageJson([]),
          'items': [1]
        },
      ]) {
        body = invalid;
        await expectLater(load(), throwsFormatException);
      }
    });
  }

  test('a comment cannot open a different post from the response', () async {
    final item = activityCommentJson();
    (item['comment'] as Map<String, dynamic>)['post_id'] = 99;
    final repository = _repository(
        (_) async => http.Response(jsonEncode(activityPageJson([item])), 200));
    await expectLater(repository.loadComments(), throwsFormatException);
  });
}

ApiProfileActivityRepository _repository(MockClientHandler handler) =>
    ApiProfileActivityRepository(
        api: ApiClient(
      client: MockClient(handler),
      baseUri: Uri.parse('https://api.1touch.football/v1/'),
      requestHeaders: () => const {},
    ));
