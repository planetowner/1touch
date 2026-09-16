import 'package:onetouch/data/community/mock/community_catalog.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/models/post.dart';

typedef MockPostReport = ({int postId, int userId, String reason});

class MockPostRepository implements PostRepository {
  MockPostRepository({List<Post>? posts, int currentUserId = 1001})
      : _posts = List.of(posts ?? mockPosts),
        _currentUserId = currentUserId {
    for (final post in _posts) {
      if (post.postId >= _nextPostId) {
        _nextPostId = post.postId + 1;
      }
    }
  }

  // Temporary in-memory identity until an API implementation derives the
  // current user from the authenticated request.
  final int _currentUserId;
  final List<Post> _posts;
  final List<MockPostReport> _reports = [];
  int _nextPostId = 1;

  List<MockPostReport> get reports => List.unmodifiable(_reports);

  @override
  Future<int> createPost(CreatePostInput input) async {
    if (input.title.isEmpty || input.title.length > 200) {
      throw ArgumentError.value(
        input.title,
        'input.title',
        'Must contain between 1 and 200 characters',
      );
    }
    if (input.body.isEmpty || input.body.length > 10000) {
      throw ArgumentError.value(
        input.body,
        'input.body',
        'Must contain between 1 and 10000 characters',
      );
    }

    final postId = _nextPostId++;
    _posts.add(
      Post(
        postId: postId,
        teamId: input.teamId,
        userId: _currentUserId,
        username: _mockUsernameFor(_currentUserId),
        category: input.category,
        title: input.title,
        body: input.body,
        mediaUrl: input.mediaUrl,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    return postId;
  }

  @override
  Future<List<Post>> loadPosts({
    required int teamId,
    PostCategory? category,
    PostSort sort = PostSort.newest,
    PostPeriod period = PostPeriod.allTime,
    String? timezone,
    int limit = 50,
    int offset = 0,
  }) async {
    if (teamId < 1) {
      throw RangeError.value(teamId, 'teamId', 'Must be positive');
    }
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    if (offset < 0) {
      throw RangeError.value(offset, 'offset', 'Must not be negative');
    }

    if (period != PostPeriod.allTime &&
        (timezone == null || timezone.trim().isEmpty)) {
      throw ArgumentError.value(
        timezone,
        'timezone',
        'An IANA device timezone is required for a date period',
      );
    }

    final posts = _posts
        .where(
          (post) =>
              post.teamId == teamId &&
              (category == null || post.category == category),
        )
        .toList();

    // The current mock Post model does not expose engagement aggregates yet,
    // so keep every mock sort deterministic until those response fields are
    // modeled. The real backend already implements popular and best ordering.
    switch (sort) {
      case PostSort.newest:
      case PostSort.popular:
      case PostSort.best:
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return List.unmodifiable(posts.skip(offset).take(limit));
  }

  @override
  Future<void> reportPost({
    required int postId,
    required String reason,
  }) async {
    if (postId < 1) {
      throw RangeError.value(postId, 'postId', 'Must be positive');
    }
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty ||
        normalizedReason.length > maxPostReportReasonLength) {
      throw ArgumentError.value(
        reason,
        'reason',
        'Must contain between 1 and $maxPostReportReasonLength characters',
      );
    }

    _reports.add(
      (postId: postId, userId: _currentUserId, reason: normalizedReason),
    );
  }
}

String _mockUsernameFor(int userId) {
  for (final user in mockUsers) {
    if (user.userId == userId) return user.username;
  }
  return 'user$userId';
}
