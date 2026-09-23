import 'dart:convert';

import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/posts/api/api_post_mapper.dart';
import 'package:onetouch/data/posts/api/api_post_response.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/models/post.dart';

/// HTTP implementation of the connected Community post operations.
///
/// Feed loading, text-post creation, and post reporting are connected. Media
/// uploads remain outside this repository and require attachment IDs first.
class ApiPostRepository implements PostRepository {
  ApiPostRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

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
    _validateQuery(
      teamId: teamId,
      period: period,
      timezone: timezone,
      limit: limit,
      offset: offset,
    );

    final queryParameters = <String, String>{
      'team_id': '$teamId',
      if (category != null) 'category': category.name,
      'sort': sort.name,
      'period': period.apiValue,
      'limit': '$limit',
      'offset': '$offset',
      if (period != PostPeriod.allTime) 'timezone': timezone!.trim(),
    };
    final uri = _api.baseUri.resolve('posts').replace(
          queryParameters: queryParameters,
        );
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final apiResponse = ApiPostListResponse.fromJson(decoded);
    if (apiResponse.limit != limit || apiResponse.offset != offset) {
      throw FormatException(
        'Expected posts pagination ($limit, $offset) but received '
        '(${apiResponse.limit}, ${apiResponse.offset}).',
      );
    }

    final posts = apiResponse.items
        .map((item) => postFromApiResponse(item, apiBaseUri: _api.baseUri))
        .toList(growable: false);
    for (final post in posts) {
      if (post.teamId != teamId) {
        throw FormatException(
          'Expected team_id $teamId but received ${post.teamId}.',
        );
      }
    }
    return List.unmodifiable(posts);
  }

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
    return postId;
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
    if (input.attachmentIds.length > 10) {
      throw RangeError.range(
        input.attachmentIds.length,
        0,
        10,
        'input.attachmentIds.length',
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
