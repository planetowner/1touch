import 'package:onetouch/models/post.dart';

enum PostSort { newest, popular, best }

// POST /v1/posts/{post_id}/report currently declares a 500-character FastAPI
// limit, but post_reports.reason is VARCHAR(255) in the MySQL schema. Keep the
// client/mock contract at the safe storage limit until those backend contracts
// are aligned; then this constant and its contract tests can be updated.
const int maxPostReportReasonLength = 255;

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

  Future<void> reportPost({
    required int postId,
    required String reason,
  });
}
