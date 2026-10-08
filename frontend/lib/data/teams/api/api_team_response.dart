import 'package:onetouch/core/api_json.dart' as api_json;

/// Transport model for the backend's `TeamOut` response.
class ApiTeamResponse {
  const ApiTeamResponse({
    required this.teamId,
    required this.name,
    this.shortName,
    required this.shortCode,
    required this.imagePath,
  });

  final int teamId;
  final String name;
  final String? shortName;
  final String? shortCode;
  final String? imagePath;

  factory ApiTeamResponse.fromJson(Map<String, dynamic> json) {
    return ApiTeamResponse(
      teamId: api_json.requiredInt(json, 'team_id'),
      name: api_json.requiredString(json, 'name'),
      shortName: _optionalString(json, 'short_name'),
      shortCode: _optionalString(json, 'short_code'),
      imagePath: _optionalString(json, 'image_path'),
    );
  }
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Expected nullable string field "$key".');
}
