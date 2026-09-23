import 'dart:convert';

import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/post_comments/api/api_post_comment_mapper.dart';
import 'package:onetouch/data/post_comments/api/api_post_comment_response.dart';
import 'package:onetouch/data/post_comments/post_comment_repository.dart';
import 'package:onetouch/models/post_comment.dart';

class ApiPostCommentRepository implements PostCommentRepository {
  ApiPostCommentRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

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

    final uri = _api.baseUri.resolve('posts/$postId/comments');
    final response = await _api.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'body': normalizedBody,
        'reply_to_id': replyToId,
      }),
    );

    final decoded =
        _api.decodeJson<Map<String, dynamic>>(response, expectedStatus: 201);
    if (decoded['comment_id'] is! int) {
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

    final uri = _api.baseUri.resolve('posts/$postId/comments').replace(
      queryParameters: {
        'after_id': '$afterId',
        'limit': '$limit',
      },
    );
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final apiResponse = ApiPostCommentListResponse.fromJson(decoded);
    final comments = apiResponse.items
        .map(
          (item) => postCommentFromApiResponse(
            item,
            apiBaseUri: _api.baseUri,
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
}
