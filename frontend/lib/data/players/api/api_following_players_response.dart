class ApiFollowingPlayersResponse {
  ApiFollowingPlayersResponse({
    required List<ApiFollowingPlayerResponse> items,
  }) : items = List.unmodifiable(items);

  final List<ApiFollowingPlayerResponse> items;

  factory ApiFollowingPlayersResponse.fromJson(Map<String, dynamic> json) {
    final value = json['items'];
    if (value is! List) {
      throw const FormatException(
        'Expected required list field "items".',
      );
    }

    return ApiFollowingPlayersResponse(
      items: value.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException(
            'Expected each "items" entry to be an object.',
          );
        }
        return ApiFollowingPlayerResponse.fromJson(item);
      }).toList(),
    );
  }
}

class ApiFollowingPlayerResponse {
  const ApiFollowingPlayerResponse({
    required this.playerId,
    required this.name,
    required this.imagePath,
  });

  final int playerId;
  final String name;
  final String? imagePath;

  factory ApiFollowingPlayerResponse.fromJson(Map<String, dynamic> json) {
    return ApiFollowingPlayerResponse(
      playerId: _requiredInt(json, 'player_id'),
      name: _requiredString(json, 'name'),
      imagePath: _requiredNullableString(json, 'image_path'),
    );
  }
}

class ApiFollowingPlayersUpdateResponse {
  const ApiFollowingPlayersUpdateResponse({required this.ok});

  final bool ok;

  factory ApiFollowingPlayersUpdateResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final value = json['ok'];
    if (value is! bool) {
      throw const FormatException('Expected required boolean field "ok".');
    }
    return ApiFollowingPlayersUpdateResponse(ok: value);
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected required integer field "$key".');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected required string field "$key".');
}

String? _requiredNullableString(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable string field "$key".');
  }
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Expected nullable string field "$key".');
}
