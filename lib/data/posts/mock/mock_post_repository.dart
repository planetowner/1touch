import 'package:onetouch/data/community/mock/community_catalog.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/models/post.dart';

class MockPostRepository implements PostRepository {
  MockPostRepository({List<Post>? posts})
      : _posts = List.unmodifiable(posts ?? mockPosts);

  final List<Post> _posts;

  @override
  Future<List<Post>> loadPosts({
    PostCategory? category,
    PostSort sort = PostSort.newest,
    int limit = 50,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 200) {
      throw RangeError.range(limit, 1, 200, 'limit');
    }
    if (offset < 0) {
      throw RangeError.value(offset, 'offset', 'Must not be negative');
    }

    final posts = _posts
        .where((post) => category == null || post.category == category)
        .toList();

    // The backend currently maps newest, popular, and best to the same
    // created_at-descending order until engagement aggregates are available.
    switch (sort) {
      case PostSort.newest:
      case PostSort.popular:
      case PostSort.best:
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return List.unmodifiable(posts.skip(offset).take(limit));
  }
}
