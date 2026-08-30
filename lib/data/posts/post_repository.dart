import 'package:onetouch/models/post.dart';

enum PostSort { newest, popular, best }

class CreatePostInput {
  final PostCategory category;
  final String title;
  final String body;
  final String? mediaUrl;

  const CreatePostInput({
    required this.category,
    required this.title,
    required this.body,
    this.mediaUrl,
  });
}

abstract interface class PostRepository {
  Future<List<Post>> loadPosts({
    PostCategory? category,
    PostSort sort = PostSort.newest,
    int limit = 50,
    int offset = 0,
  });

  Future<int> createPost(CreatePostInput input);
}
