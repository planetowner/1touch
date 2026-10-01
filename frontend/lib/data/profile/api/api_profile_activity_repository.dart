import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/post_comments/api/api_post_comment_mapper.dart';
import 'package:onetouch/data/post_comments/api/api_post_comment_response.dart';
import 'package:onetouch/data/posts/api/api_post_mapper.dart';
import 'package:onetouch/data/posts/api/api_post_response.dart';
import 'package:onetouch/data/profile/profile_activity_repository.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/profile_activity_counts.dart';
import 'package:onetouch/models/profile_comment_activity.dart';

class ApiProfileActivityRepository implements ProfileActivityRepository {
  ApiProfileActivityRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<ProfileActivityCounts> loadCounts() async {
    final response =
        await _api.get(_api.baseUri.resolve('users/me/activity/counts'));
    final json = _api.decodeJson<Map<String, dynamic>>(response);
    final posts = json['post_count'];
    final comments = json['comment_count'];
    if (posts is! int || comments is! int || posts < 0 || comments < 0) {
      throw const FormatException('Expected non-negative activity counts.');
    }
    return ProfileActivityCounts(postCount: posts, commentCount: comments);
  }

  @override
  Future<List<Post>> loadPosts({int limit = 50, int offset = 0}) =>
      _loadPage('users/me/posts', limit, offset, _post);

  @override
  Future<List<ProfileCommentActivity>> loadComments({
    int limit = 50,
    int offset = 0,
  }) =>
      _loadPage('users/me/comments', limit, offset, (json) {
        final post = _post(json['post'] as Map<String, dynamic>);
        final comment = postCommentFromApiResponse(
          ApiPostCommentResponse.fromJson(
              json['comment'] as Map<String, dynamic>),
          apiBaseUri: _api.baseUri,
        );
        if (comment.postId != post.postId) {
          throw const FormatException(
              'Expected the comment to belong to its activity post.');
        }
        return ProfileCommentActivity(post: post, comment: comment);
      });

  Post _post(Map<String, dynamic> json) => postFromApiResponse(
        ApiPostResponse.fromJson(json),
        apiBaseUri: _api.baseUri,
      );

  // 두 탭은 같은 페이지 계약을 쓰고 항목 변환만 달라요.
  Future<List<T>> _loadPage<T>(
    String path,
    int limit,
    int offset,
    T Function(Map<String, dynamic>) parse,
  ) async {
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    if (offset < 0) {
      throw RangeError.value(offset, 'offset', 'Must not be negative');
    }
    final response = await _api.get(_api.baseUri.resolve(path).replace(
      queryParameters: {'limit': '$limit', 'offset': '$offset'},
    ));
    final json = _api.decodeJson<Map<String, dynamic>>(response);
    if (json['limit'] != limit || json['offset'] != offset) {
      throw const FormatException('Unexpected activity pagination.');
    }
    final items = json['items'];
    if (items is! List) {
      throw const FormatException('Expected an activity items list.');
    }
    return List.unmodifiable(items.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Expected an activity item object.');
      }
      return parse(item);
    }));
  }
}
