import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/posts/api/api_post_mapper.dart';
import 'package:onetouch/data/posts/api/api_post_response.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/models/post.dart';

/// HTTP implementation of the connected Community post operations.
///
/// Feed loading, text-post creation, and post reporting are connected. Media
/// uploads remain outside this repository and require attachment IDs first.
class ApiPostRepository implements CachedPostRepository {
  ApiPostRepository({required ApiClient api, LocalCacheStore? cacheStore})
      : _api = api,
        _cacheStore = cacheStore;

  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  final ValueNotifier<Map<PostFeedQuery, List<Post>>> _cachedFeeds =
      ValueNotifier(const {});
  final ValueNotifier<Map<int, Post>> _cachedPostDetails =
      ValueNotifier(const {});
  final Map<PostFeedQuery, DateTime> _feedSavedAt = {};
  final Map<int, DateTime> _postSavedAt = {};
  final Map<PostFeedQuery, Future<List<Post>>> _feedLoads = {};
  final Map<PostFeedQuery, Future<List<Post>>> _feedFetches = {};
  final Map<int, Future<Post>> _postLoads = {};
  final Map<int, Future<Post>> _postFetches = {};
  final Set<Future<void>> _pendingWrites = {};
  int _cacheGeneration = 0;

  @override
  ValueListenable<Map<PostFeedQuery, List<Post>>> get cachedFeeds =>
      _cachedFeeds;

  @override
  ValueListenable<Map<int, Post>> get cachedPostDetails => _cachedPostDetails;

  @override
  Post? cachedPost(int postId) => _cachedPostDetails.value[postId];

  @override
  List<Post>? cachedFeed({
    required int teamId,
    PostCategory? category,
    PostSort sort = PostSort.newest,
    PostPeriod period = PostPeriod.allTime,
    String? timezone,
    int limit = 50,
    int offset = 0,
  }) =>
      _cachedFeeds.value[
          _query(teamId, category, sort, period, timezone, limit, offset)];

  /// Promotes a local feed page to memory without starting an API request.
  Future<List<Post>?> restoreCachedFeed({
    required int teamId,
    PostCategory? category,
    PostSort sort = PostSort.newest,
    PostPeriod period = PostPeriod.allTime,
    String? timezone,
    int limit = 50,
    int offset = 0,
  }) async {
    final query =
        _query(teamId, category, sort, period, timezone, limit, offset);
    return _cachedFeeds.value[query] ?? await _restoreFeed(query);
  }

  @override
  Future<void> invalidatePostCaches() async {
    _cacheGeneration++;
    _feedLoads.clear();
    _feedFetches.clear();
    _postLoads.clear();
    _postFetches.clear();
    _feedSavedAt.clear();
    _postSavedAt.clear();
    _cachedFeeds.value = const {};
    _cachedPostDetails.value = const {};
    try {
      await Future.wait(_pendingWrites.toList());
    } on Object {
      // A failed write must not prevent clearing any other cached entries.
    }
    try {
      await _cacheStore?.clearScope(LocalCacheScopes.communityPosts);
    } on Object {
      // Mutations must remain successful even if local storage is unavailable.
    }
  }

  @override
  Future<int> loadAttachmentLimit() async {
    final response = await _api.get(_api.baseUri.resolve('posts/limits'));
    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    return decoded['max_attachments'] as int;
  }

  @override
  Future<Post> loadPost(int postId) async {
    if (postId < 1) {
      throw RangeError.value(postId, 'postId', 'Must be positive');
    }
    final cached = cachedPost(postId);
    if (cached != null) {
      _refreshPostIfStale(postId);
      return cached;
    }
    final inFlight = _postLoads[postId];
    if (inFlight != null) return await inFlight;
    late final Future<Post> load;
    load = _restoreOrFetchPost(postId).whenComplete(() {
      if (identical(_postLoads[postId], load)) _postLoads.remove(postId);
    });
    _postLoads[postId] = load;
    return await load;
  }

  @override
  Future<Post> refreshPost(int postId) async {
    if (postId < 1) {
      throw RangeError.value(postId, 'postId', 'Must be positive');
    }
    return _fetchPost(postId);
  }

  Future<Post> _restoreOrFetchPost(int postId) async {
    final generation = _cacheGeneration;
    final store = _cacheStore;
    if (store != null) {
      final key = LocalCacheKeys.communityPost(postId);
      try {
        final record = await store.read(
          key,
          scope: LocalCacheScopes.communityPosts,
        );
        if (record != null && generation == _cacheGeneration) {
          try {
            final decoded = Map<String, dynamic>.from(record.payload as Map);
            final post = _mapPost(decoded, postId);
            _publishPost(postId, post, record.savedAt);
            _refreshPostIfStale(postId);
            return post;
          } on Object {
            await store.delete(key, scope: LocalCacheScopes.communityPosts);
          }
        }
      } on Object {
        // A storage failure falls back to the API.
      }
    }
    return _fetchPost(postId);
  }

  void _refreshPostIfStale(int postId) {
    if (AppCachePolicy.shouldRefresh(
      tier: CacheTier.shortLived,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _postSavedAt[postId],
    )) {
      unawaited(_fetchPost(postId).then<void>((_) {}, onError: (Object _) {}));
    }
  }

  Future<Post> _fetchPost(int postId) {
    final existing = _postFetches[postId];
    if (existing != null) return existing;
    late final Future<Post> fetch;
    fetch = _fetchAndCachePost(postId).whenComplete(() {
      if (identical(_postFetches[postId], fetch)) _postFetches.remove(postId);
    });
    _postFetches[postId] = fetch;
    return fetch;
  }

  Future<Post> _fetchAndCachePost(int postId) async {
    final generation = _cacheGeneration;
    final response = await _api.get(_api.baseUri.resolve('posts/$postId'));
    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final post = _mapPost(decoded, postId);
    if (generation == _cacheGeneration) {
      _publishPost(postId, post, DateTime.now().toUtc());
      await _writeCache(LocalCacheKeys.communityPost(postId), decoded);
    }
    return post;
  }

  Post _mapPost(Map<String, dynamic> decoded, int postId) {
    final post = postFromApiResponse(ApiPostResponse.fromJson(decoded),
        apiBaseUri: _api.baseUri);
    if (post.postId != postId) {
      throw FormatException(
        'Expected post_id $postId but received ${post.postId}.',
      );
    }
    return post;
  }

  void _publishPost(int postId, Post post, DateTime savedAt) {
    _postSavedAt[postId] = savedAt;
    _cachedPostDetails.value =
        Map.unmodifiable({..._cachedPostDetails.value, postId: post});
  }

  @override
  Future<List<Post>> loadPosts({
    required int teamId,
    PostCategory? category,
    PostSort sort = PostSort.newest,
    PostPeriod period = PostPeriod.allTime,
    String? timezone,
    int limit = 50,
    int offset = 0,
  }) async {
    final query =
        _query(teamId, category, sort, period, timezone, limit, offset);
    final cached = _cachedFeeds.value[query];
    if (cached != null) {
      _refreshFeedIfStale(query);
      return cached;
    }
    final inFlight = _feedLoads[query];
    if (inFlight != null) return await inFlight;
    late final Future<List<Post>> load;
    load = _restoreOrFetchFeed(query).whenComplete(() {
      if (identical(_feedLoads[query], load)) _feedLoads.remove(query);
    });
    _feedLoads[query] = load;
    return await load;
  }

  @override
  Future<List<Post>> refreshPosts({
    required int teamId,
    PostCategory? category,
    PostSort sort = PostSort.newest,
    PostPeriod period = PostPeriod.allTime,
    String? timezone,
    int limit = 50,
    int offset = 0,
  }) async =>
      _fetchFeed(
          _query(teamId, category, sort, period, timezone, limit, offset));

  PostFeedQuery _query(
    int teamId,
    PostCategory? category,
    PostSort sort,
    PostPeriod period,
    String? timezone,
    int limit,
    int offset,
  ) {
    _validateQuery(
        teamId: teamId,
        period: period,
        timezone: timezone,
        limit: limit,
        offset: offset);
    return (
      teamId: teamId,
      category: category,
      sort: sort,
      period: period,
      timezone: period == PostPeriod.allTime ? null : timezone!.trim(),
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Post>> _restoreOrFetchFeed(PostFeedQuery query) async {
    final restored = await _restoreFeed(query);
    if (restored != null) {
      _refreshFeedIfStale(query);
      return restored;
    }
    return _fetchFeed(query);
  }

  Future<List<Post>?> _restoreFeed(PostFeedQuery query) async {
    final generation = _cacheGeneration;
    final store = _cacheStore;
    final cached = _cachedFeeds.value[query];
    if (cached != null) return cached;
    if (store != null) {
      final key = _feedKey(query);
      try {
        final record = await store.read(
          key,
          scope: LocalCacheScopes.communityPosts,
        );
        if (record != null && generation == _cacheGeneration) {
          try {
            final decoded = Map<String, dynamic>.from(record.payload as Map);
            final posts = _mapFeed(decoded, query);
            _publishFeed(query, posts, record.savedAt);
            return posts;
          } on Object {
            await store.delete(key, scope: LocalCacheScopes.communityPosts);
          }
        }
      } on Object {
        // A storage failure falls back to the API.
      }
    }
    return null;
  }

  void _refreshFeedIfStale(PostFeedQuery query) {
    if (AppCachePolicy.shouldRefresh(
      tier: CacheTier.shortLived,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _feedSavedAt[query],
    )) {
      unawaited(_fetchFeed(query).then<void>((_) {}, onError: (Object _) {}));
    }
  }

  Future<List<Post>> _fetchFeed(PostFeedQuery query) {
    final existing = _feedFetches[query];
    if (existing != null) return existing;
    late final Future<List<Post>> fetch;
    fetch = _fetchAndCacheFeed(query).whenComplete(() {
      if (identical(_feedFetches[query], fetch)) _feedFetches.remove(query);
    });
    _feedFetches[query] = fetch;
    return fetch;
  }

  Future<List<Post>> _fetchAndCacheFeed(PostFeedQuery query) async {
    final generation = _cacheGeneration;
    final queryParameters = <String, String>{
      'team_id': '${query.teamId}',
      if (query.category != null) 'category': query.category!.name,
      'sort': query.sort.name,
      'period': query.period.apiValue,
      'limit': '${query.limit}',
      'offset': '${query.offset}',
      if (query.timezone != null) 'timezone': query.timezone!,
    };
    final uri = _api.baseUri.resolve('posts').replace(
          queryParameters: queryParameters,
        );
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final posts = _mapFeed(decoded, query);
    if (generation == _cacheGeneration) {
      _publishFeed(query, posts, DateTime.now().toUtc());
      await _writeCache(_feedKey(query), decoded);
    }
    return posts;
  }

  List<Post> _mapFeed(Map<String, dynamic> decoded, PostFeedQuery query) {
    final apiResponse = ApiPostListResponse.fromJson(decoded);
    if (apiResponse.limit != query.limit ||
        apiResponse.offset != query.offset) {
      throw FormatException(
        'Expected posts pagination (${query.limit}, ${query.offset}) but received '
        '(${apiResponse.limit}, ${apiResponse.offset}).',
      );
    }

    final posts = apiResponse.items
        .map((item) => postFromApiResponse(item, apiBaseUri: _api.baseUri))
        .toList(growable: false);
    for (final post in posts) {
      if (post.teamId != query.teamId ||
          (query.category != null && post.category != query.category)) {
        throw FormatException(
          'Unexpected post ${post.postId} in requested feed.',
        );
      }
    }
    return List.unmodifiable(posts);
  }

  void _publishFeed(PostFeedQuery query, List<Post> posts, DateTime savedAt) {
    _feedSavedAt[query] = savedAt;
    _cachedFeeds.value =
        Map.unmodifiable({..._cachedFeeds.value, query: posts});
  }

  Future<void> _writeCache(String key, Object payload) async {
    final store = _cacheStore;
    if (store == null) return;
    late final Future<void> write;
    try {
      write = store.write(
        key,
        payload,
        scope: LocalCacheScopes.communityPosts,
      );
    } on Object {
      // A storage failure must not hide a valid response.
      return;
    }
    _pendingWrites.add(write);
    try {
      await write;
    } on Object {
      // A storage failure must not hide a valid response.
    } finally {
      _pendingWrites.remove(write);
    }
  }

  String _feedKey(PostFeedQuery query) => LocalCacheKeys.communityFeed(
        query.teamId,
        query.category?.name,
        query.sort.name,
        query.period.apiValue,
        query.timezone,
        query.limit,
        query.offset,
      );

  @override
  Future<int> createPost(CreatePostInput input) async {
    final title = input.title.trim();
    _validateCreatePostInput(input, title: title);

    final uri = _api.baseUri.resolve('posts');
    final response = await _api.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'team_id': input.teamId,
        'category': input.category.name,
        'title': title,
        'body': input.body,
        'attachment_ids': input.attachmentIds,
      }),
    );

    final decoded =
        _api.decodeJson<Map<String, dynamic>>(response, expectedStatus: 201);
    if (decoded['post_id'] is! int) {
      throw const FormatException(
        'Expected the post-creation response to contain integer "post_id".',
      );
    }
    final postId = decoded['post_id'] as int;
    if (postId < 1) {
      throw const FormatException(
        'Expected the created post ID to be positive.',
      );
    }
    await invalidatePostCaches();
    return postId;
  }

  @override
  Future<void> deletePost({required int postId}) async {
    if (postId < 1) {
      throw RangeError.value(postId, 'postId', 'Must be positive');
    }
    final response = await _api.delete(_api.baseUri.resolve('posts/$postId'));
    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    if (decoded['ok'] != true) {
      throw const FormatException('Expected post deletion to return ok=true.');
    }
    await invalidatePostCaches();
  }

  @override
  Future<void> updatePost(UpdatePostInput input) async {
    if (input.postId < 1) {
      throw RangeError.value(input.postId, 'postId', 'Must be positive');
    }
    final title = input.title.trim();
    if (title.isEmpty || title.length > 200) {
      throw ArgumentError.value(
          input.title, 'title', 'Must be 1–200 characters');
    }
    if (input.body.length > 10000) {
      throw ArgumentError.value(
          input.body, 'body', 'Must be at most 10000 characters');
    }
    if (input.attachmentIds.any((id) => id < 1) ||
        input.attachmentIds.toSet().length != input.attachmentIds.length) {
      throw ArgumentError.value(
          input.attachmentIds, 'attachmentIds', 'Must be unique positive IDs');
    }
    final response = await _api.put(
      _api.baseUri.resolve('posts/${input.postId}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'category': input.category.name,
        'title': title,
        'body': input.body,
        'attachment_ids': input.attachmentIds,
      }),
    );
    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    if (decoded['ok'] != true) {
      throw const FormatException('Expected post update to return ok=true.');
    }
    await invalidatePostCaches();
  }

  @override
  Future<void> reportPost({
    required int postId,
    required String reason,
  }) async {
    if (postId < 1) {
      throw RangeError.value(postId, 'postId', 'Must be positive');
    }
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty ||
        normalizedReason.length > maxPostReportReasonLength) {
      throw ArgumentError.value(
        reason,
        'reason',
        'Must contain between 1 and $maxPostReportReasonLength characters',
      );
    }

    final uri = _api.baseUri.resolve('posts/$postId/report');
    final response = await _api.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'reason': normalizedReason}),
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    if (decoded['ok'] is! bool) {
      throw const FormatException(
        'Expected the post-report response to contain boolean "ok".',
      );
    }
    if (decoded['ok'] != true) {
      throw const FormatException(
        'Expected the post-report response to return ok=true.',
      );
    }
  }

  @override
  Future<void> setPostLiked({
    required int postId,
    required bool liked,
  }) async {
    if (postId < 1) {
      throw RangeError.value(postId, 'postId', 'Must be positive');
    }

    final uri = _api.baseUri.resolve('posts/$postId/like');
    final response = liked ? await _api.put(uri) : await _api.delete(uri);

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    if (decoded['ok'] is! bool) {
      throw const FormatException(
        'Expected the post-like response to contain boolean "ok".',
      );
    }
    if (decoded['ok'] != true) {
      throw const FormatException(
        'Expected the post-like response to return ok=true.',
      );
    }
    await invalidatePostCaches();
  }

  static void _validateQuery({
    required int teamId,
    required PostPeriod period,
    required String? timezone,
    required int limit,
    required int offset,
  }) {
    if (teamId < 1) {
      throw RangeError.value(teamId, 'teamId', 'Must be positive');
    }
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    if (offset < 0) {
      throw RangeError.value(offset, 'offset', 'Must not be negative');
    }
    if (period != PostPeriod.allTime &&
        (timezone == null || timezone.trim().isEmpty)) {
      throw ArgumentError.value(
        timezone,
        'timezone',
        'An IANA device timezone is required for a date period',
      );
    }
  }

  static void _validateCreatePostInput(
    CreatePostInput input, {
    required String title,
  }) {
    if (input.teamId < 1) {
      throw RangeError.value(input.teamId, 'input.teamId', 'Must be positive');
    }
    if (title.isEmpty || title.length > 200) {
      throw ArgumentError.value(
        input.title,
        'input.title',
        'Must contain between 1 and 200 characters',
      );
    }
    if (input.body.length > 10000) {
      throw ArgumentError.value(
        input.body,
        'input.body',
        'Must not exceed 10000 characters',
      );
    }
    if (input.attachmentIds.any((id) => id < 1)) {
      throw ArgumentError.value(
        input.attachmentIds,
        'input.attachmentIds',
        'IDs must be positive',
      );
    }
    if (input.attachmentIds.length != input.attachmentIds.toSet().length) {
      throw ArgumentError.value(
        input.attachmentIds,
        'input.attachmentIds',
        'IDs must not be repeated',
      );
    }
  }
}
