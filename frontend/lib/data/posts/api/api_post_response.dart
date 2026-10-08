import 'package:onetouch/core/api_json.dart' as api_json;

class ApiPostListResponse {
  ApiPostListResponse({
    required List<ApiPostResponse> items,
    required this.limit,
    required this.offset,
  }) : items = List.unmodifiable(items);

  final List<ApiPostResponse> items;
  final int limit;
  final int offset;

  factory ApiPostListResponse.fromJson(Map<String, dynamic> json) {
    return ApiPostListResponse(
      items: _objectList(json, 'items', ApiPostResponse.fromJson),
      limit: api_json.requiredInt(json, 'limit'),
      offset: api_json.requiredInt(json, 'offset'),
    );
  }
}

class ApiPostResponse {
  ApiPostResponse({
    required this.postId,
    required this.teamId,
    required this.language,
    required this.userId,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.editedAt,
    required this.username,
    this.displayName,
    required this.avatarUrl,
    required this.authorDeleted,
    required this.likeCount,
    required this.commentCount,
    required this.liked,
    required List<ApiPostAttachmentResponse> attachments,
  }) : attachments = List.unmodifiable(attachments);

  final int postId;
  final int teamId;
  final String language;
  final int? userId;
  final String category;
  final String title;
  final String body;
  final String createdAt;
  final String? editedAt;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final bool authorDeleted;
  final int likeCount;
  final int commentCount;
  final bool liked;
  final List<ApiPostAttachmentResponse> attachments;

  factory ApiPostResponse.fromJson(Map<String, dynamic> json) {
    return ApiPostResponse(
      postId: api_json.requiredInt(json, 'post_id'),
      teamId: api_json.requiredInt(json, 'team_id'),
      language: api_json.requiredString(json, 'language'),
      userId: _nullableInt(json, 'user_id'),
      category: api_json.requiredString(json, 'category'),
      title: api_json.requiredString(json, 'title'),
      body: api_json.requiredString(json, 'body'),
      createdAt: api_json.requiredString(json, 'created_at'),
      editedAt: _nullableString(json, 'edited_at'),
      username: _nullableString(json, 'username'),
      displayName: json['display_name'] as String?,
      avatarUrl: _nullableString(json, 'avatar_url'),
      authorDeleted: _requiredBool(json, 'author_deleted'),
      likeCount: api_json.requiredInt(json, 'like_count'),
      commentCount: api_json.requiredInt(json, 'comment_count'),
      liked: _requiredBool(json, 'liked', acceptBinaryInteger: true),
      attachments: _objectList(
        json,
        'attachments',
        ApiPostAttachmentResponse.fromJson,
      ),
    );
  }
}

class ApiPostAttachmentResponse {
  const ApiPostAttachmentResponse({
    required this.attachmentId,
    required this.position,
    required this.linkUrl,
    required this.mediaUrl,
    this.previewUrl,
    required this.contentType,
    required this.byteSize,
  });

  final int attachmentId;
  final int position;
  final String? linkUrl;
  final String? mediaUrl;
  final String? previewUrl;
  final String? contentType;
  final int? byteSize;

  factory ApiPostAttachmentResponse.fromJson(Map<String, dynamic> json) {
    final response = ApiPostAttachmentResponse(
      attachmentId: api_json.requiredInt(json, 'attachment_id'),
      position: api_json.requiredInt(json, 'position'),
      linkUrl: _nullableString(json, 'link_url'),
      mediaUrl: _nullableString(json, 'media_url'),
      previewUrl: json['preview_url'] as String?,
      contentType: _nullableString(json, 'content_type'),
      byteSize: _nullableInt(json, 'byte_size'),
    );
    final isLink = response.linkUrl != null &&
        response.mediaUrl == null &&
        response.contentType == null &&
        response.byteSize == null;
    final isUpload = response.linkUrl == null &&
        response.mediaUrl != null &&
        response.contentType != null &&
        response.byteSize != null;
    if (!isLink && !isUpload) {
      throw const FormatException(
        'Expected a post attachment to be either a link or an uploaded file.',
      );
    }
    return response;
  }
}

int? _nullableInt(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable integer field "$key".');
  }
  final value = json[key];
  if (value == null || value is int) return value as int?;
  throw FormatException('Expected nullable integer field "$key".');
}

String? _nullableString(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable string field "$key".');
  }
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Expected nullable string field "$key".');
}

bool _requiredBool(
  Map<String, dynamic> json,
  String key, {
  bool acceptBinaryInteger = false,
}) {
  final value = json[key];
  if (value is bool) return value;
  if (acceptBinaryInteger && (value == 0 || value == 1)) return value == 1;
  throw FormatException('Expected required boolean field "$key".');
}

List<T> _objectList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Expected required list field "$key".');
  }
  return value.map((item) {
    if (item is! Map<String, dynamic>) {
      throw FormatException('Expected every "$key" entry to be an object.');
    }
    return parse(item);
  }).toList(growable: false);
}
