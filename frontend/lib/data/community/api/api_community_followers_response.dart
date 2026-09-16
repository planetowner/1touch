class ApiCommunityFollowersResponse {
  const ApiCommunityFollowersResponse({
    required this.teamId,
    required this.followerCount,
  });

  final int teamId;
  final int followerCount;

  factory ApiCommunityFollowersResponse.fromJson(Map<String, dynamic> json) {
    final teamId = _requiredInt(json, 'team_id');
    final followerCount = _requiredInt(json, 'follower_count');
    if (teamId < 1) {
      throw const FormatException('Expected "team_id" to be positive.');
    }
    if (followerCount < 0) {
      throw const FormatException(
        'Expected "follower_count" to be non-negative.',
      );
    }
    return ApiCommunityFollowersResponse(
      teamId: teamId,
      followerCount: followerCount,
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected required integer field "$key".');
}
