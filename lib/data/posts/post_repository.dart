import 'package:onetouch/models/post.dart';

enum PostSort { newest, popular, best }

abstract interface class PostRepository {
  Future<List<Post>> loadPosts({
    PostCategory? category,
    PostSort sort = PostSort.newest,
    int limit = 50,
    int offset = 0,
  });
}
