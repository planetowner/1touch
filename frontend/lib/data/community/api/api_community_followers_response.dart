import 'package:onetouch/core/api_json.dart' as api_json;

class ApiCommunityFollowersResponse {
  const ApiCommunityFollowersResponse({
    required this.teamId,
    required this.followerCount,
  });

  final int teamId;
  final int followerCount;

  factory ApiCommunityFollowersResponse.fromJson(Map<String, dynamic> json) {
    final teamId = api_json.requiredInt(json, 'team_id');
    final followerCount = api_json.requiredInt(json, 'follower_count');
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
