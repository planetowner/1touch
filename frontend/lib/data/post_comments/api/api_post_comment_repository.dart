import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onetouch/data/post_comments/api/api_post_comment_mapper.dart';
import 'package:onetouch/data/post_comments/api/api_post_comment_response.dart';
import 'package:onetouch/data/post_comments/post_comment_repository.dart';
import 'package:onetouch/models/post_comment.dart';

class ApiPostCommentRepository implements PostCommentRepository {
  ApiPostCommentRepository({
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
  Future<int> createComment({
    required int postId,
    required String body,
    int? replyToId,
  }) async {
    if (postId < 1) {
      throw RangeError.value(postId, 'postId', 'Must be positive');
    }
    if (replyToId != null && replyToId < 1) {
      throw RangeError.value(replyToId, 'replyToId', 'Must be positive');
    }
    final normalizedBody = body.trim();
    if (normalizedBody.isEmpty ||
        normalizedBody.length > maxPostCommentBodyLength) {
      throw ArgumentError.value(
        body,
        'body',
        'Must contain between 1 and $maxPostCommentBodyLength characters',
      );
    }

    final uri = _apiBaseUri.resolve('posts/$postId/comments');
    final response = await _client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        ..._requestHeaders,
      },
      body: jsonEncode({
        'body': normalizedBody,
        'reply_to_id': replyToId,
      }),
    );
    if (response.statusCode != 201) {
      throw http.ClientException(
        'Comment creation failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['comment_id'] is! int) {
      throw const FormatException(
        'Expected comment creation to return integer "comment_id".',
      );
    }
    final commentId = decoded['comment_id'] as int;
    if (commentId < 1) {
      throw const FormatException(
        'Expected the created comment ID to be positive.',
      );
    }
    return commentId;
  }

  @override
  Future<List<PostComment>> loadForPost({
    required int postId,
    int afterId = 0,
    int limit = 50,
  }) async {
    if (postId < 1) {
      throw RangeError.value(postId, 'postId', 'Must be positive');
    }
    if (afterId < 0) {
      throw RangeError.value(afterId, 'afterId', 'Must not be negative');
    }
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }

    final uri = _apiBaseUri.resolve('posts/$postId/comments').replace(
      queryParameters: {
        'after_id': '$afterId',
        'limit': '$limit',
      },
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
        'Comments request failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the comments response to be a JSON object.',
      );
    }
    final apiResponse = ApiPostCommentListResponse.fromJson(decoded);
    final comments = apiResponse.items
        .map(
          (item) => postCommentFromApiResponse(
            item,
            apiBaseUri: _apiBaseUri,
          ),
        )
        .toList(growable: false);

    var previousId = afterId;
    for (final comment in comments) {
      if (comment.postId != postId) {
        throw FormatException(
          'Expected post_id $postId but received ${comment.postId}.',
        );
      }
      if (comment.commentId <= previousId) {
        throw const FormatException(
          'Expected comments in strictly increasing cursor order.',
        );
      }
      previousId = comment.commentId;
    }
    return List.unmodifiable(comments);
  }

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
