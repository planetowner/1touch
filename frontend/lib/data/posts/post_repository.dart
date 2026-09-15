import 'package:onetouch/models/post.dart';

enum PostSort { newest, popular, best }

enum PostPeriod { allTime, today, week, month, year }

extension PostPeriodApiValue on PostPeriod {
  String get apiValue => switch (this) {
        PostPeriod.allTime => 'all_time',
        PostPeriod.today => 'today',
        PostPeriod.week => 'week',
        PostPeriod.month => 'month',
        PostPeriod.year => 'year',
      };
}

// POST /v1/posts/{post_id}/report currently declares a 500-character FastAPI
// limit, but post_reports.reason is VARCHAR(255) in the MySQL schema. Keep the
// client/mock contract at the safe storage limit until those backend contracts
// are aligned; then this constant and its contract tests can be updated.
const int maxPostReportReasonLength = 255;

class CreatePostInput {
  final int teamId;
  final PostCategory category;
  final String title;
  final String body;
  final String? mediaUrl;

  const CreatePostInput({
    required this.teamId,
    required this.category,
    required this.title,
    required this.body,
    this.mediaUrl,
  });
}

abstract interface class PostRepository {
  Future<List<Post>> loadPosts({
    required int teamId,
    PostCategory? category,
    PostSort sort = PostSort.newest,
    PostPeriod period = PostPeriod.allTime,
    String? timezone,
    int limit = 50,
    int offset = 0,
  });

  Future<int> createPost(CreatePostInput input);

  Future<void> reportPost({
    required int postId,
    required String reason,
  });
}
