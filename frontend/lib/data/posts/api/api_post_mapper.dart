import 'package:onetouch/data/posts/api/api_post_response.dart';
import 'package:onetouch/models/post.dart';

Post postFromApiResponse(ApiPostResponse response, {required Uri apiBaseUri}) {
  final category = switch (response.category) {
    'general' => PostCategory.general,
    'analysis' => PostCategory.analysis,
    'news' => PostCategory.news,
    _ => throw FormatException(
        'Unrecognized post category "${response.category}".',
      ),
  };
  if (DateTime.tryParse(response.createdAt) == null) {
    throw const FormatException('Expected created_at to be ISO 8601.');
  }
  if (response.editedAt != null &&
      DateTime.tryParse(response.editedAt!) == null) {
    throw const FormatException('Expected edited_at to be nullable ISO 8601.');
  }
  if (response.authorDeleted != (response.userId == null)) {
    throw const FormatException(
      'Expected author_deleted to match nullable user_id.',
    );
  }

  final attachments = response.attachments
      .map(
        (item) => PostAttachment(
          attachmentId: item.attachmentId,
          position: item.position,
          linkUrl: _resolveOptionalUri(apiBaseUri, item.linkUrl),
          mediaUrl: _resolveOptionalUri(apiBaseUri, item.mediaUrl),
          contentType: item.contentType,
          byteSize: item.byteSize,
        ),
      )
      .toList(growable: false);
  final firstMediaUrl = attachments
      .where((attachment) => attachment.mediaUrl != null)
      .firstOrNull
      ?.mediaUrl;

  return Post(
    postId: response.postId,
    teamId: response.teamId,
    userId: response.userId,
    category: category,
    title: response.title,
    body: response.body,
    mediaUrl: firstMediaUrl,
    createdAt: response.createdAt,
    editedAt: response.editedAt,
    username: response.username,
    avatarUrl: _resolveOptionalUri(apiBaseUri, response.avatarUrl),
    authorDeleted: response.authorDeleted,
    likeCount: response.likeCount,
    commentCount: response.commentCount,
    liked: response.liked,
    attachments: List.unmodifiable(attachments),
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
