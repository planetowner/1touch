import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/local/repository_cache.dart';
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
  late final _feeds = RepositoryCache<PostFeedQuery, List<Post>>(
    fetch: _fetchFeed,
    decode: _mapFeed,
    keyOf: _feedKey,
    tier: CacheTier.shortLived,
    store: _cacheStore,
    scope: LocalCacheScopes.communityPosts,
  );
  late final _details = RepositoryCache<int, Post>(
    fetch: _fetchPost,
    decode: _mapPost,
    keyOf: LocalCacheKeys.communityPost,
    tier: CacheTier.shortLived,
    store: _cacheStore,
    scope: LocalCacheScopes.communityPosts,
  );

  @override
  ValueListenable<Map<PostFeedQuery, List<Post>>> get cachedFeeds =>
      _feeds.values;
  @override
  ValueListenable<Map<int, Post>> get cachedPostDetails => _details.values;
  @override
  Post? cachedPost(int postId) => _details.cached(postId);

  @override
  List<Post>? cachedFeed({
    required int teamId,
    required String language,
    PostCategory? category,
    PostSort sort = PostSort.newest,
    PostPeriod period = PostPeriod.allTime,
    String? timezone,
    int limit = 50,
    int offset = 0,
  }) =>
      _feeds.cached(_query(
          teamId, language, category, sort, period, timezone, limit, offset));

  Future<List<Post>?> restoreCachedFeed({
    required int teamId,
    required String language,
    PostCategory? category,
    PostSort sort = PostSort.newest,
    PostPeriod period = PostPeriod.allTime,
    String? timezone,
    int limit = 50,
    int offset = 0,
  }) async =>
      _feeds.restore(_query(
          teamId, language, category, sort, period, timezone, limit, offset));

  @override
  Future<void> invalidatePostCaches() =>
      RepositoryCache.invalidateAll([_feeds, _details]);

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
    return _details.load(postId);
  }

  @override
  Future<Post> refreshPost(int postId) async {
    if (postId < 1) {
      throw RangeError.value(postId, 'postId', 'Must be positive');
    }
    return _details.refresh(postId);
  }

  Future<Map<String, dynamic>> _fetchPost(int postId) async {
    final response = await _api.get(_api.baseUri.resolve('posts/$postId'));
    return _api.decodeJson<Map<String, dynamic>>(response);
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

  @override
  Future<List<Post>> loadPosts({
    required int teamId,
    required String language,
    PostCategory? category,
    PostSort sort = PostSort.newest,
    PostPeriod period = PostPeriod.allTime,
    String? timezone,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = _query(
        teamId, language, category, sort, period, timezone, limit, offset);
    return _feeds.load(query);
  }

  @override
  Future<List<Post>> refreshPosts({
    required int teamId,
    required String language,
    PostCategory? category,
    PostSort sort = PostSort.newest,
    PostPeriod period = PostPeriod.allTime,
    String? timezone,
    int limit = 50,
    int offset = 0,
  }) async =>
      _feeds.refresh(_query(
          teamId, language, category, sort, period, timezone, limit, offset));

  PostFeedQuery _query(
    int teamId,
    String language,
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
      language: language,
      category: category,
      sort: sort,
      period: period,
      timezone: period == PostPeriod.allTime ? null : timezone!.trim(),
      limit: limit,
      offset: offset,
    );
  }

  Future<Map<String, dynamic>> _fetchFeed(PostFeedQuery query) async {
    final queryParameters = <String, String>{
      'team_id': '${query.teamId}',
      'language': query.language,
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

    return _api.decodeJson<Map<String, dynamic>>(response);
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
          post.language != query.language ||
          (query.category != null && post.category != query.category)) {
        throw FormatException(
          'Unexpected post ${post.postId} in requested feed.',
        );
      }
    }
    return List.unmodifiable(posts);
  }

  String _feedKey(PostFeedQuery query) => LocalCacheKeys.communityFeed(
        query.teamId,
        query.language,
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
        'language': input.language,
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
