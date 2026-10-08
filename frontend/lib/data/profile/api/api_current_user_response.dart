import 'package:onetouch/core/api_json.dart' as api_json;

/// Transport response for the fields consumed from `GET /v1/users/me`.
///
/// The backend currently has no explicit response model and also returns
/// additional account-state columns. Those extra fields are intentionally
/// ignored until the endpoint publishes a stable schema that needs them.
class ApiCurrentUserResponse {
  const ApiCurrentUserResponse({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.favoriteTeamId,
    required this.createdAt,
    required this.onboardingComplete,
    this.socialAccounts = const [],
  });

  final int userId;
  final String? username;
  final String? displayName;
  final String? email;
  final String? avatarUrl;
  final int? favoriteTeamId;
  final String createdAt;
  final bool onboardingComplete;
  final List<String> socialAccounts;

  // 이메일·소셜 가입 모두 닉네임을 정하면 프로필 입력이 끝나요.
  bool get profileComplete => displayName != null && displayName!.isNotEmpty;

  factory ApiCurrentUserResponse.fromJson(Map<String, dynamic> json) {
    return ApiCurrentUserResponse(
      userId: api_json.requiredInt(json, 'user_id'),
      username: _optionalString(json, 'username'),
      displayName: _optionalString(json, 'display_name'),
      email: _optionalString(json, 'email'),
      avatarUrl: _optionalString(json, 'avatar_url'),
      favoriteTeamId: _optionalInt(json, 'favorite_team_id'),
      createdAt: api_json.requiredString(json, 'created_at'),
      onboardingComplete: api_json.requiredBool(json, 'onboarding_complete'),
      // 백엔드가 이 필드를 배포하기 전에는 빈 목록으로 읽어요. 배포 전에는
      // 실제 연결 계정도 '연결 안 됨'으로 보일 수 있으므로 함께 출시해야 해요.
      socialAccounts: (json['social_accounts'] as List<dynamic>? ?? const [])
          .map((value) => value as String)
          .toList(growable: false),
    );
  }
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

String? _optionalString(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable string field "$key".');
  }
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Expected nullable string field "$key".');
}
