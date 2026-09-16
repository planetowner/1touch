import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onetouch/data/posts/api/api_post_mapper.dart';
import 'package:onetouch/data/posts/api/api_post_response.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/models/post.dart';

/// HTTP implementation of the connected Community post operations.
///
/// Post creation remains disabled until its API contract is connected and
/// tested. This repository is therefore not the active provider yet.
class ApiPostRepository implements PostRepository {
  ApiPostRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;

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
    final uri = _apiBaseUri.resolve('posts').replace(
          queryParameters: queryParameters,
        );
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Posts request failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the posts response to be a JSON object.',
      );
    }
    final apiResponse = ApiPostListResponse.fromJson(decoded);
    if (apiResponse.limit != limit || apiResponse.offset != offset) {
      throw FormatException(
        'Expected posts pagination ($limit, $offset) but received '
        '(${apiResponse.limit}, ${apiResponse.offset}).',
      );
    }

    final posts = apiResponse.items
        .map((item) => postFromApiResponse(item, apiBaseUri: _apiBaseUri))
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
  Future<int> createPost(CreatePostInput input) {
    throw UnsupportedError(
      'Post creation is not connected in the read-only API repository.',
    );
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

    final uri = _apiBaseUri.resolve('posts/$postId/report');
    final response = await _client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        ..._requestHeaders,
      },
      body: jsonEncode({'reason': normalizedReason}),
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Post-report request failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['ok'] is! bool) {
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

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
