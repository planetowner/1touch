import 'package:onetouch/core/api_json.dart' as api_json;

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
    this.jerseyNumber,
  });

  final int playerId;
  final String name;
  final String? imagePath;
  final int? jerseyNumber;

  factory ApiFollowingPlayerResponse.fromJson(Map<String, dynamic> json) {
    // 기존 로컬 캐시에는 등번호가 없으므로 목록을 갱신할 때까지 비워 둬요.
    final jerseyNumber = json['jersey_number'];
    if (jerseyNumber != null && jerseyNumber is! int) {
      throw const FormatException(
          'Expected nullable integer field "jersey_number".');
    }
    return ApiFollowingPlayerResponse(
      playerId: api_json.requiredInt(json, 'player_id'),
      name: api_json.requiredString(json, 'name'),
      imagePath: _requiredNullableString(json, 'image_path'),
      jerseyNumber: jerseyNumber as int?,
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

String? _requiredNullableString(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable string field "$key".');
  }
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Expected nullable string field "$key".');
}
