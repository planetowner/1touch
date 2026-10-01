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
  final List<int> attachmentIds;

  CreatePostInput({
    required this.teamId,
    required this.category,
    required this.title,
    required this.body,
    List<int> attachmentIds = const [],
  }) : attachmentIds = List.unmodifiable(attachmentIds);
}

class UpdatePostInput {
  const UpdatePostInput({
    required this.postId,
    required this.category,
    required this.title,
    required this.body,
    required this.attachmentIds,
  });

  final int postId;
  final PostCategory category;
  final String title;
  final String body;
  final List<int> attachmentIds;
}

abstract interface class PostRepository {
  Future<int> loadAttachmentLimit();

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

  Future<void> deletePost({required int postId});

  Future<void> updatePost(UpdatePostInput input);

  Future<void> reportPost({
    required int postId,
    required String reason,
  });

  Future<void> setPostLiked({
    required int postId,
    required bool liked,
  });
}

/// Loads one post for notification and deep-link destinations.
abstract interface class PostDetailRepository {
  Future<Post> loadPost(int postId);
}
