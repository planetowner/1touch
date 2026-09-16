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

// Matches ReportBody and content_reports.reason in the current backend.
const int maxPostReportReasonLength = 500;

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
