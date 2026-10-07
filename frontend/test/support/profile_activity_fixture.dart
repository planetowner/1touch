Map<String, dynamic> activityPostJson({int id = 42}) => {
      'post_id': id,
      'team_id': 83,
      'language': 'en',
      'user_id': 1,
      'category': 'general',
      'title': 'My post $id',
      'body': 'Post body $id',
      'created_at': '2026-09-29T12:00:00Z',
      'edited_at': null,
      'username': 'owner',
      'avatar_url': '/v1/users/1/avatar',
      'author_deleted': false,
      'like_count': 2,
      'comment_count': 1,
      'liked': 1,
      'attachments': <Map<String, dynamic>>[],
    };

Map<String, dynamic> activityCommentJson({int id = 71, int postId = 42}) => {
      'post': activityPostJson(id: postId),
      'comment': {
        'comment_id': id,
        'post_id': postId,
        'user_id': 1,
        'reply_to_id': 70,
        'body': 'My comment $id',
        'created_at': '2026-09-29T13:00:00Z',
        'edited_at': null,
        'state': 'active',
        'username': 'owner',
        'avatar_url': '/v1/users/1/avatar',
        'author_deleted': false,
        'like_count': 3,
        'liked': 0,
      },
    };

Map<String, dynamic> activityPageJson(
  List<Map<String, dynamic>> items, {
  int limit = 50,
  int offset = 0,
}) =>
    {'items': items, 'limit': limit, 'offset': offset};
