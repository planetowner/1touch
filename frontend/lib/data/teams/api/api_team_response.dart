/// Transport model for the backend's `TeamOut` response.
class ApiTeamResponse {
  const ApiTeamResponse({
    required this.teamId,
    required this.name,
    required this.shortCode,
    required this.imagePath,
  });

  final int teamId;
  final String name;
  final String? shortCode;
  final String? imagePath;

  factory ApiTeamResponse.fromJson(Map<String, dynamic> json) {
    return ApiTeamResponse(
      teamId: _requiredInt(json, 'team_id'),
      name: _requiredString(json, 'name'),
      shortCode: _optionalString(json, 'short_code'),
      imagePath: _optionalString(json, 'image_path'),
    );
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

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Expected nullable string field "$key".');
}
