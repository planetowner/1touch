import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/posts/api/api_post_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/models/post.dart';

void main() {
  test('loads the server attachment limit', () async {
    final repository = ApiPostRepository(
        api: ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/v1/posts/limits');
        return http.Response('{"max_attachments":3}', 200);
      }),
      baseUri: Uri.parse('https://example.test/v1/'),
      requestHeaders: () => const {},
    ));
    expect(await repository.loadAttachmentLimit(), 3);
  });

  test('updates a post without dropping its category or attachments', () async {
    final repository = ApiPostRepository(
      api: ApiClient(
        client: MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, '/v1/posts/42');
          expect(request.headers['Authorization'], 'Bearer session-token');
          expect(jsonDecode(request.body), {
            'category': 'analysis',
            'title': 'Updated title',
            'body': 'Updated body',
            'attachment_ids': [7, 8],
          });
          return http.Response('{"ok":true}', 200);
        }),
        baseUri: Uri.parse('https://api.1touch.football/v1/'),
        requestHeaders: () => const {'Authorization': 'Bearer session-token'},
      ),
    );

    await repository.updatePost(UpdatePostInput(
      postId: 42,
      category: PostCategory.analysis,
      title: ' Updated title ',
      body: 'Updated body',
      attachmentIds: [7, 8],
    ));
  });

  test('deletes a post through the authenticated endpoint', () async {
    final repository = ApiPostRepository(
      api: ApiClient(
        client: MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/v1/posts/42');
          expect(request.headers['Authorization'], 'Bearer session-token');
          return http.Response('{"ok":true}', 200);
        }),
        baseUri: Uri.parse('https://api.1touch.football/v1/'),
        requestHeaders: () => const {'Authorization': 'Bearer session-token'},
      ),
    );

    await repository.deletePost(postId: 42);
    await expectLater(repository.deletePost(postId: 0), throwsRangeError);
  });

  test('loads one post for a notification destination', () async {
    final repository = ApiPostRepository(
      api: ApiClient(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/v1/posts/42');
          return http.Response(jsonEncode(_postJson()), 200);
        }),
        baseUri: Uri.parse('https://api.1touch.football/v1/'),
        requestHeaders: () => const {},
      ),
    );

    final post = await repository.loadPost(42);

    expect(post.postId, 42);
    expect(post.title, 'Pressing structure');
  });

  test('restores feed and post detail after repository recreation', () async {
    final store = MemoryLocalCacheStore();
    var requests = 0;
    ApiPostRepository repository() => ApiPostRepository(
          api: ApiClient(
            client: MockClient((request) async {
              requests++;
              return http.Response(
                jsonEncode(request.url.path.endsWith('/42')
                    ? _postJson()
                    : _feedJson()),
                200,
              );
            }),
            baseUri: Uri.parse('https://example.test/v1/'),
            requestHeaders: () => const {},
          ),
          cacheStore: store,
        );

    await repository().loadPosts(teamId: 83);
    await repository().loadPost(42);
    final reader = repository();
    final feed = await reader.loadPosts(teamId: 83);
    final post = await reader.loadPost(42);
    expect(feed.single.postId, 42);
    expect(post.postId, 42);
    expect(reader.cachedFeed(teamId: 83), same(feed));
    expect(reader.cachedPost(42), same(post));
    expect(requests, 2);
  });

  test('keeps an expired feed visible during one background refresh', () async {
    final store = _AgedPostStore();
    await store.write(
      LocalCacheKeys.communityFeed(83, null, 'newest', 'all_time', null, 50, 0),
      _feedJson(),
      scope: LocalCacheScopes.communityPosts,
    );
    final response = Completer<http.Response>();
    var requests = 0;
    final repository = ApiPostRepository(
      api: ApiClient(
        client: MockClient((_) {
          requests++;
          return response.future;
        }),
        baseUri: Uri.parse('https://example.test/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    final stale = await repository.loadPosts(teamId: 83);
    final duplicate = await repository.loadPosts(teamId: 83);
    await Future<void>.delayed(Duration.zero);
    expect(stale.single.title, 'Pressing structure');
    expect(duplicate, same(stale));
    expect(requests, 1);

    final updated = Completer<void>();
    repository.cachedFeeds.addListener(() {
      if (repository.cachedFeed(teamId: 83)?.single.title == 'New title' &&
          !updated.isCompleted) {
        updated.complete();
      }
    });
    response.complete(http.Response(
      jsonEncode(_feedJson(items: [
        {..._postJson(), 'title': 'New title'}
      ])),
      200,
    ));
    await updated.future;
    expect(repository.cachedFeed(teamId: 83)?.single.title, 'New title');
  });

  test('keeps cached post detail when its refresh fails', () async {
    final store = _AgedPostStore();
    await store.write(LocalCacheKeys.communityPost(42), _postJson(),
        scope: LocalCacheScopes.communityPosts);
    var requests = 0;
    final repository = ApiPostRepository(
      api: ApiClient(
        client: MockClient((_) async {
          requests++;
          return http.Response('Offline', 503);
        }),
        baseUri: Uri.parse('https://example.test/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    final stale = await repository.loadPost(42);
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    expect(repository.cachedPost(42), same(stale));
  });

  test('repairs malformed feed cache without deleting another entry', () async {
    final store = MemoryLocalCacheStore();
    final key = LocalCacheKeys.communityFeed(
        83, null, 'newest', 'all_time', null, 50, 0);
    await store.write(key, {'items': 'broken'},
        scope: LocalCacheScopes.communityPosts);
    await store.write(LocalCacheKeys.communityPost(42), _postJson(),
        scope: LocalCacheScopes.communityPosts);
    var requests = 0;
    final repository = ApiPostRepository(
      api: ApiClient(
        client: MockClient((_) async {
          requests++;
          return http.Response(jsonEncode(_feedJson()), 200);
        }),
        baseUri: Uri.parse('https://example.test/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    expect((await repository.loadPosts(teamId: 83)).single.postId, 42);
    expect(requests, 1);
    expect(await store.read(key, scope: LocalCacheScopes.communityPosts),
        isNotNull);
    expect(
        await store.read(LocalCacheKeys.communityPost(42),
            scope: LocalCacheScopes.communityPosts),
        isNotNull);
  });

  test('deduplicates simultaneous cold feed requests', () async {
    final response = Completer<http.Response>();
    var requests = 0;
    final repository = ApiPostRepository(
      api: ApiClient(
        client: MockClient((_) {
          requests++;
          return response.future;
        }),
        baseUri: Uri.parse('https://example.test/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: MemoryLocalCacheStore(),
    );

    final first = repository.loadPosts(teamId: 83);
    final second = repository.loadPosts(teamId: 83);
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    response.complete(http.Response(jsonEncode(_feedJson()), 200));
    expect(await first, same(await second));
  });

  test('like mutation clears only community cache scope', () async {
    final store = MemoryLocalCacheStore();
    await store.write('unrelated', {'value': true});
    final repository = ApiPostRepository(
      api: ApiClient(
        client: MockClient((request) async => request.method == 'PUT'
            ? http.Response('{"ok":true}', 200)
            : http.Response(jsonEncode(_feedJson()), 200)),
        baseUri: Uri.parse('https://example.test/v1/'),
        requestHeaders: () => const {},
      ),
      cacheStore: store,
    );

    await repository.loadPosts(teamId: 83);
    final key = LocalCacheKeys.communityFeed(
        83, null, 'newest', 'all_time', null, 50, 0);
    expect(await store.read(key, scope: LocalCacheScopes.communityPosts),
        isNotNull);
    await repository.setPostLiked(postId: 42, liked: true);
    expect(repository.cachedFeed(teamId: 83), isNull);
    expect(
        await store.read(key, scope: LocalCacheScopes.communityPosts), isNull);
    expect(await store.read('unrelated'), isNotNull);
  });

  test('fan-art feed and creation use the same API category', () async {
    final repository = ApiPostRepository(
      api: ApiClient(
        client: MockClient((request) async {
          if (request.method == 'GET') {
            expect(request.url.queryParameters['category'], 'fanart');
            return http.Response(
                jsonEncode(_feedJson(items: [
                  {..._postJson(), 'category': 'fanart'},
                ])),
                200);
          }
          expect(request.method, 'POST');
          expect(jsonDecode(request.body)['category'], 'fanart');
          return http.Response('{"post_id": 101}', 201);
        }),
        baseUri: Uri.parse('https://api.1touch.football/v1/'),
        requestHeaders: () => const {},
      ),
    );
    final posts = await repository.loadPosts(
      teamId: 83,
      category: PostCategory.fanart,
    );
    expect(posts.single.category, PostCategory.fanart);
    expect(
        await repository.createPost(CreatePostInput(
          teamId: 83,
          category: posts.single.category,
          title: 'Fan art',
          body: 'My drawing',
        )),
        101);
  });

  test('requests and maps a team post feed with Bearer headers', () async {
    final repository = ApiPostRepository(
      api: ApiClient(
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
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () =>
              const {'Authorization': 'Bearer session-token'}),
    );

    final posts = await repository.loadPosts(teamId: 83);
    final post = posts.single;

    expect(post.postId, 42);
    expect(post.teamId, 83);
    expect(post.userId, 1001);
    expect(post.username, 'planetowner');
    expect(post.displayName, 'Planet Owner');
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
      api: ApiClient(
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
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {}),
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
        'display_name': null,
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
      api: ApiClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode(_feedJson(items: [deletedPost])),
              200,
            ),
          ),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
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
      api: ApiClient(
          client: MockClient((_) async {
            requests++;
            return http.Response('{}', 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
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
    final negativeEngagement = _postJson()..['like_count'] = -1;
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
      http.Response(
        jsonEncode(_feedJson(items: [negativeEngagement])),
        200,
      ),
      http.Response(jsonEncode(_feedJson(items: [invalidAttachment])), 200),
    ];
    var index = 0;
    final repository = ApiPostRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[index++]),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
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
      api: ApiClient(
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
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () =>
              const {'Authorization': 'Bearer session-token'}),
    );

    await expectLater(
      repository.reportPost(postId: 42, reason: '  Spam  '),
      completes,
    );
  });

  test('rejects invalid report values before requesting', () async {
    var requests = 0;
    final repository = ApiPostRepository(
      api: ApiClient(
          client: MockClient((_) async {
            requests++;
            return http.Response('{}', 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
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
      api: ApiClient(
          client: MockClient((_) async => responses[responseIndex++]),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
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

  test('creates a text post with Bearer authentication', () async {
    final repository = ApiPostRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/v1/posts');
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Content-Type'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            expect(jsonDecode(request.body), {
              'team_id': 83,
              'category': 'analysis',
              'title': 'Title',
              'body': 'Body',
              'attachment_ids': [7, 8],
            });
            return http.Response(jsonEncode({'post_id': 101}), 201);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () =>
              const {'Authorization': 'Bearer session-token'}),
    );

    expect(
      await repository.createPost(
        CreatePostInput(
          teamId: 83,
          category: PostCategory.analysis,
          title: '  Title  ',
          body: 'Body',
          attachmentIds: const [7, 8],
        ),
      ),
      101,
    );
  });

  test('rejects invalid creation values before requesting', () async {
    var requests = 0;
    final repository = ApiPostRepository(
      api: ApiClient(
          client: MockClient((_) async {
            requests++;
            return http.Response('{}', 201);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    final invalidInputs = [
      CreatePostInput(
        teamId: 0,
        category: PostCategory.general,
        title: 'Title',
        body: 'Body',
      ),
      CreatePostInput(
        teamId: 83,
        category: PostCategory.general,
        title: '   ',
        body: 'Body',
      ),
      CreatePostInput(
        teamId: 83,
        category: PostCategory.general,
        title: ''.padRight(201, 'x'),
        body: 'Body',
      ),
      CreatePostInput(
        teamId: 83,
        category: PostCategory.general,
        title: 'Title',
        body: ''.padRight(10001, 'x'),
      ),
      CreatePostInput(
        teamId: 83,
        category: PostCategory.general,
        title: 'Title',
        body: 'Body',
        attachmentIds: const [1, 1],
      ),
      CreatePostInput(
        teamId: 83,
        category: PostCategory.general,
        title: 'Title',
        body: 'Body',
        attachmentIds: const [0],
      ),
    ];

    for (final input in invalidInputs) {
      await expectLater(
        repository.createPost(input),
        throwsA(anyOf(isA<ArgumentError>(), isA<RangeError>())),
      );
    }
    expect(requests, 0);
  });

  test('rejects failed and malformed creation responses', () async {
    final responses = [
      http.Response('Bad request', 400),
      http.Response(jsonEncode({'post_id': 42}), 200),
      http.Response(jsonEncode([]), 201),
      http.Response(jsonEncode({}), 201),
      http.Response(jsonEncode({'post_id': '42'}), 201),
      http.Response(jsonEncode({'post_id': 0}), 201),
    ];
    var responseIndex = 0;
    final repository = ApiPostRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[responseIndex++]),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );
    final input = CreatePostInput(
      teamId: 83,
      category: PostCategory.general,
      title: 'Title',
      body: 'Body',
    );

    for (var index = 0; index < 2; index++) {
      await expectLater(
        repository.createPost(input),
        throwsA(isA<http.ClientException>()),
      );
    }
    for (var index = 2; index < responses.length; index++) {
      await expectLater(
        repository.createPost(input),
        throwsFormatException,
      );
    }
  });

  test('uses idempotent PUT and DELETE post-like endpoints', () async {
    var requestIndex = 0;
    final repository = ApiPostRepository(
      api: ApiClient(
          client: MockClient((request) async {
            requestIndex++;
            expect(request.url.path, '/v1/posts/42/like');
            expect(request.url.queryParameters, isEmpty);
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            expect(request.method, requestIndex == 1 ? 'PUT' : 'DELETE');
            return http.Response(jsonEncode({'ok': true}), 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () =>
              const {'Authorization': 'Bearer session-token'}),
    );

    await repository.setPostLiked(postId: 42, liked: true);
    await repository.setPostLiked(postId: 42, liked: false);
    expect(requestIndex, 2);
  });

  test('rejects an invalid post-like ID before requesting', () async {
    var requests = 0;
    final repository = ApiPostRepository(
      api: ApiClient(
          client: MockClient((_) async {
            requests++;
            return http.Response('{}', 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.setPostLiked(postId: 0, liked: true),
      throwsRangeError,
    );
    expect(requests, 0);
  });

  test('rejects failed and malformed post-like responses', () async {
    final responses = [
      http.Response('Not found', 404),
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode({}), 200),
      http.Response(jsonEncode({'ok': false}), 200),
    ];
    var responseIndex = 0;
    final repository = ApiPostRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[responseIndex++]),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.setPostLiked(postId: 42, liked: true),
      throwsA(isA<http.ClientException>()),
    );
    for (var index = 1; index < responses.length; index++) {
      await expectLater(
        repository.setPostLiked(postId: 42, liked: true),
        throwsFormatException,
      );
    }
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
      'display_name': 'Planet Owner',
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

class _AgedPostStore implements LocalCacheStore {
  final MemoryLocalCacheStore _delegate = MemoryLocalCacheStore();

  @override
  Future<LocalCacheRecord?> read(String key,
      {String scope = LocalCacheScopes.global, int schemaVersion = 1}) async {
    final record =
        await _delegate.read(key, scope: scope, schemaVersion: schemaVersion);
    if (record == null) return null;
    return LocalCacheRecord(
      payload: record.payload,
      savedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
      schemaVersion: record.schemaVersion,
    );
  }

  @override
  Future<void> write(String key, Object payload,
          {String scope = LocalCacheScopes.global, int schemaVersion = 1}) =>
      _delegate.write(key, payload, scope: scope, schemaVersion: schemaVersion);

  @override
  Future<void> delete(String key, {String scope = LocalCacheScopes.global}) =>
      _delegate.delete(key, scope: scope);

  @override
  Future<void> clearScope(String scope) => _delegate.clearScope(scope);
}
