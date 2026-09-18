class ApiChatHistoryResponse {
  ApiChatHistoryResponse({required List<ApiChatMessageResponse> items})
      : items = List.unmodifiable(items);

  final List<ApiChatMessageResponse> items;

  factory ApiChatHistoryResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException(
          'Expected chat history "items" to be a list.');
    }
    return ApiChatHistoryResponse(
      items: rawItems.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException(
            'Expected each chat history item to be an object.',
          );
        }
        return ApiChatMessageResponse.fromJson(item);
      }).toList(growable: false),
    );
  }
}

class ApiChatMessageResponse {
  const ApiChatMessageResponse({
    required this.messageId,
    required this.fixtureId,
    required this.userId,
    required this.username,
    required this.text,
    required this.createdAt,
    required this.avatarUrl,
    required this.authorDeleted,
  });

  final int messageId;
  final int fixtureId;
  final int? userId;
  final String? username;
  final String text;
  final String createdAt;
  final String? avatarUrl;
  final bool authorDeleted;

  factory ApiChatMessageResponse.fromJson(Map<String, dynamic> json) {
    return ApiChatMessageResponse(
      messageId: _requiredInt(json, 'message_id'),
      fixtureId: _requiredInt(json, 'fixture_id'),
      userId: _nullableInt(json, 'user_id'),
      username: _nullableString(json, 'username'),
      text: _requiredString(json, 'text'),
      createdAt: _requiredString(json, 'created_at'),
      avatarUrl: _nullableString(json, 'avatar_url'),
      authorDeleted: _requiredBool(json, 'author_deleted'),
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected "$key" to be an integer.');
}

int? _nullableInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  throw FormatException('Expected "$key" to be a nullable integer.');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected "$key" to be a string.');
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Expected "$key" to be a nullable string.');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Expected "$key" to be a boolean.');
}
