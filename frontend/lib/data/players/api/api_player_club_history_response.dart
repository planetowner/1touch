class ApiPlayerClubHistoryResponse {
  ApiPlayerClubHistoryResponse({
    required this.playerId,
    required List<ApiPlayerClubHistoryEntryResponse> clubs,
  }) : clubs = List.unmodifiable(clubs);

  final int playerId;
  final List<ApiPlayerClubHistoryEntryResponse> clubs;

  factory ApiPlayerClubHistoryResponse.fromJson(Map<String, dynamic> json) {
    return ApiPlayerClubHistoryResponse(
      playerId: _requiredInt(json, 'player_id'),
      clubs: _requiredObjectList(
        json,
        'clubs',
        ApiPlayerClubHistoryEntryResponse.fromJson,
      ),
    );
  }
}

class ApiPlayerClubHistoryEntryResponse {
  const ApiPlayerClubHistoryEntryResponse({
    required this.teamId,
    required this.teamName,
    required this.teamImage,
    required this.startDate,
    required this.endDate,
  });

  final int teamId;
  final String? teamName;
  final String? teamImage;
  final String? startDate;
  final String? endDate;

  factory ApiPlayerClubHistoryEntryResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return ApiPlayerClubHistoryEntryResponse(
      teamId: _requiredInt(json, 'team_id'),
      teamName: _requiredNullableString(json, 'team_name'),
      teamImage: _requiredNullableString(json, 'team_image'),
      startDate: _requiredNullableString(json, 'start_date'),
      endDate: _requiredNullableString(json, 'end_date'),
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected required integer field "$key".');
}

String? _requiredNullableString(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable string field "$key".');
  }
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Expected nullable string field "$key".');
}

List<T> _requiredObjectList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Expected required list field "$key".');
  }
  return List.unmodifiable(
    value.map((item) {
      if (item is! Map<String, dynamic>) {
        throw FormatException('Expected each "$key" item to be an object.');
      }
      return parse(item);
    }),
  );
}
