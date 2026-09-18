class ApiPostCommentListResponse {
  ApiPostCommentListResponse({required List<ApiPostCommentResponse> items})
      : items = List.unmodifiable(items);

  final List<ApiPostCommentResponse> items;

  factory ApiPostCommentListResponse.fromJson(Map<String, dynamic> json) {
    final value = json['items'];
    if (value is! List) {
      throw const FormatException(
        'Expected the comments response to contain an "items" list.',
      );
    }
    return ApiPostCommentListResponse(
      items: value.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException(
            'Expected every comment item to be a JSON object.',
          );
        }
        return ApiPostCommentResponse.fromJson(item);
      }).toList(growable: false),
    );
  }
}

class ApiPostCommentResponse {
  const ApiPostCommentResponse({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.replyToId,
    required this.body,
    required this.createdAt,
    required this.editedAt,
    required this.state,
    required this.username,
    required this.avatarUrl,
    required this.authorDeleted,
    required this.likeCount,
    required this.liked,
  });

  final int commentId;
  final int postId;
  final int? userId;
  final int? replyToId;
  final String body;
  final String createdAt;
  final String? editedAt;
  final String state;
  final String? username;
  final String? avatarUrl;
  final bool authorDeleted;
  final int likeCount;
  final bool liked;

  factory ApiPostCommentResponse.fromJson(Map<String, dynamic> json) {
    return ApiPostCommentResponse(
      commentId: _requiredInt(json, 'comment_id'),
      postId: _requiredInt(json, 'post_id'),
      userId: _nullableInt(json, 'user_id'),
      replyToId: _nullableInt(json, 'reply_to_id'),
      body: _requiredString(json, 'body'),
      createdAt: _requiredString(json, 'created_at'),
      editedAt: _nullableString(json, 'edited_at'),
      state: _requiredString(json, 'state'),
      username: _nullableString(json, 'username'),
      avatarUrl: _nullableString(json, 'avatar_url'),
      authorDeleted: _requiredBool(json, 'author_deleted'),
      likeCount: _requiredInt(json, 'like_count'),
      liked: _requiredBool(json, 'liked', acceptBinaryInteger: true),
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected required integer field "$key".');
}

int? _nullableInt(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable integer field "$key".');
  }
  final value = json[key];
  if (value == null || value is int) return value as int?;
  throw FormatException('Expected nullable integer field "$key".');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected required string field "$key".');
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
