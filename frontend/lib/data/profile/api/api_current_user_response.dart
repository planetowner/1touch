/// Transport response for the fields consumed from `GET /v1/users/me`.
///
/// The backend currently has no explicit response model and also returns
/// additional account-state columns. Those extra fields are intentionally
/// ignored until the endpoint publishes a stable schema that needs them.
class ApiCurrentUserResponse {
  const ApiCurrentUserResponse({
    required this.userId,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.avatarUrl,
    required this.favoriteTeamId,
    required this.createdAt,
    required this.onboardingComplete,
  });

  final int userId;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? avatarUrl;
  final int? favoriteTeamId;
  final String createdAt;
  final bool onboardingComplete;

  factory ApiCurrentUserResponse.fromJson(Map<String, dynamic> json) {
    return ApiCurrentUserResponse(
      userId: _requiredInt(json, 'user_id'),
      username: _optionalString(json, 'username'),
      firstName: _optionalString(json, 'first_name'),
      lastName: _optionalString(json, 'last_name'),
      email: _optionalString(json, 'email'),
      avatarUrl: _optionalString(json, 'avatar_url'),
      favoriteTeamId: _optionalInt(json, 'favorite_team_id'),
      createdAt: _requiredString(json, 'created_at'),
      onboardingComplete: _requiredBool(json, 'onboarding_complete'),
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected required integer field "$key".');
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable integer field "$key".');
  }
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  throw FormatException('Expected nullable integer field "$key".');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected required string field "$key".');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable string field "$key".');
  }
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Expected nullable string field "$key".');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Expected required boolean field "$key".');
}
