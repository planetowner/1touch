import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/profile/profile_follow_repository.dart';
import 'package:onetouch/models/profile_follow.dart';

class ApiProfileFollowRepository implements ProfileFollowRepository {
  const ApiProfileFollowRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<ProfileFollowCounts> loadCounts() async {
    final response =
        await _api.get(_api.baseUri.resolve('users/me/follow/counts'));
    final json = _api.decodeJson<Map<String, dynamic>>(response);
    final followers = json['follower_count'];
    final following = json['following_count'];
    if (followers is! int ||
        following is! int ||
        followers < 0 ||
        following < 0) {
      throw const FormatException('Expected non-negative follow counts.');
    }
    return ProfileFollowCounts(followers: followers, following: following);
  }

  @override
  Future<List<ProfileFollowUser>> loadUsers({
    required ProfileFollowTab tab,
    required ProfileFollowSort sort,
    int limit = 50,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    if (offset < 0) {
      throw RangeError.value(offset, 'offset');
    }
    final uri = _api.baseUri.resolve('users/me/${tab.name}').replace(
      queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
        'sort': sort.name,
      },
    );
    final json = _api.decodeJson<Map<String, dynamic>>(await _api.get(uri));
    if (json['limit'] != limit ||
        json['offset'] != offset ||
        json['items'] is! List) {
      throw const FormatException('Unexpected follow pagination.');
    }
    return List.unmodifiable((json['items'] as List).map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Expected a follow user object.');
      }
      final id = item['user_id'];
      final displayName = item['display_name'];
      final username = item['username'];
      final avatarUrl = item['avatar_url'];
      if (id is! int ||
          id <= 0 ||
          (displayName != null && displayName is! String) ||
          (username != null && username is! String) ||
          (avatarUrl != null && avatarUrl is! String)) {
        throw const FormatException('Unexpected follow user fields.');
      }
      final name = (displayName as String?)?.trim();
      return ProfileFollowUser(
        userId: id,
        name: name != null && name.isNotEmpty
            ? name
            : (username as String?) ?? 'User $id',
        avatarUri: avatarUrl == null ? null : _api.baseUri.resolve(avatarUrl),
      );
    }));
  }

  @override
  Future<void> unfollow(int userId) async {
    final response =
        await _api.delete(_api.baseUri.resolve('users/$userId/follow'));
    if (_api.decodeJson<Map<String, dynamic>>(response)['ok'] != true) {
      throw const FormatException('Expected follow update to return ok=true.');
    }
  }
}
