import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/models/community_profile.dart';

class ApiCommunityProfileRepository {
  const ApiCommunityProfileRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;
  Future<CommunityProfile> load(int userId) async {
    final response =
        await _api.get(_api.baseUri.resolve('users/$userId/community'));
    final json = _api.decodeJson<Map<String, dynamic>>(response);
    return CommunityProfile(
        userId: json['user_id'] as int,
        username: json['username'] as String?,
        displayName: json['display_name'] as String?,
        isSelf: json['is_self'] as bool,
        following: json['following'] as bool,
        avatarUri: json['avatar_url'] == null
            ? null
            : _api.baseUri.resolve(json['avatar_url'] as String));
  }

  Future<void> setFollowing(int userId, bool following) async {
    final uri = _api.baseUri.resolve('users/$userId/follow');
    final response = following ? await _api.put(uri) : await _api.delete(uri);
    if (_api.decodeJson<Map<String, dynamic>>(response)['ok'] != true) {
      throw const FormatException('Expected follow update to return ok=true.');
    }
  }
}
