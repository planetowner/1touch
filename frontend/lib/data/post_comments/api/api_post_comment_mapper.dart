import 'package:onetouch/data/post_comments/api/api_post_comment_response.dart';
import 'package:onetouch/models/post_comment.dart';

PostComment postCommentFromApiResponse(
  ApiPostCommentResponse response, {
  required Uri apiBaseUri,
}) {
  if (response.commentId < 1 || response.postId < 1) {
    throw const FormatException('Expected positive comment and post IDs.');
  }
  if (response.userId != null && response.userId! < 1) {
    throw const FormatException('Expected user_id to be null or positive.');
  }
  if (response.replyToId != null && response.replyToId! < 1) {
    throw const FormatException('Expected reply_to_id to be null or positive.');
  }
  if (DateTime.tryParse(response.createdAt) == null) {
    throw const FormatException('Expected created_at to be ISO 8601.');
  }
  if (response.editedAt != null &&
      DateTime.tryParse(response.editedAt!) == null) {
    throw const FormatException('Expected edited_at to be nullable ISO 8601.');
  }
  if (response.likeCount < 0) {
    throw const FormatException('Expected a non-negative comment like count.');
  }

  final state = switch (response.state) {
    'active' => PostCommentState.active,
    'deleted' => PostCommentState.deleted,
    'hidden' => PostCommentState.hidden,
    'blocked' => PostCommentState.blocked,
    _ => throw FormatException(
        'Unrecognized comment state "${response.state}".',
      ),
  };
  if (state == PostCommentState.active &&
      response.authorDeleted != (response.userId == null)) {
    throw const FormatException(
      'Expected an active comment author_deleted value to match user_id.',
    );
  }

  return PostComment(
    commentId: response.commentId,
    postId: response.postId,
    userId: response.userId,
    replyToId: response.replyToId,
    body: response.body,
    createdAt: response.createdAt,
    editedAt: response.editedAt,
    state: state,
    username: response.username,
    avatarUrl: _resolveOptionalUri(apiBaseUri, response.avatarUrl),
    authorDeleted: response.authorDeleted,
    likeCount: response.likeCount,
    liked: response.liked,
  );
}

String? _resolveOptionalUri(Uri baseUri, String? value) {
  if (value == null) return null;
  final parsed = Uri.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid response URI: $value');
  }
  final resolved = parsed.hasScheme ? parsed : baseUri.resolveUri(parsed);
  if ((resolved.scheme != 'http' && resolved.scheme != 'https') ||
      resolved.host.isEmpty) {
    throw FormatException('Expected an HTTP(S) response URI: $value');
  }
  return resolved.toString();
}
