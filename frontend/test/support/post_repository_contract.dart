import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/models/post.dart';

void postRepositoryContract({
  required PostRepository Function(List<Post> posts) createRepository,
}) {
  const posts = [
    Post(
      postId: 1,
      teamId: 83,
      userId: 101,
      category: PostCategory.general,
      title: 'Older general post',
      body: 'Body 1',
      createdAt: '2026-08-20 10:00:00',
    ),
    Post(
      postId: 2,
      teamId: 83,
      userId: 102,
      category: PostCategory.analysis,
      title: 'Newest analysis post',
      body: 'Body 2',
      createdAt: '2026-08-23 10:00:00',
    ),
    Post(
      postId: 3,
      teamId: 83,
      userId: 103,
      category: PostCategory.general,
      title: 'Middle general post',
      body: 'Body 3',
      createdAt: '2026-08-22 10:00:00',
    ),
    Post(
      postId: 4,
      teamId: 83,
      userId: 104,
      category: PostCategory.news,
      title: 'News post',
      body: 'Body 4',
      createdAt: '2026-08-21 10:00:00',
    ),
  ];

  test('loads posts newest first by default', () async {
    final repository = createRepository(posts);

    expect(
      (await repository.loadPosts(teamId: 83)).map((post) => post.postId),
      [2, 3, 4, 1],
    );
  });

  test('filters by the backend category contract', () async {
    final repository = createRepository(posts);

    expect(
      (await repository.loadPosts(
        teamId: 83,
        category: PostCategory.general,
      ))
          .map((post) => post.postId),
      [3, 1],
    );
  });

  test('isolates posts by the required team query', () async {
    final repository = createRepository([
      ...posts,
      const Post(
        postId: 5,
        teamId: 9,
        userId: 105,
        category: PostCategory.general,
        title: 'Other team post',
        body: 'Body 5',
        createdAt: '2026-08-24 10:00:00',
      ),
    ]);

    expect(
      (await repository.loadPosts(teamId: 9)).map((post) => post.postId),
      [5],
    );
    expect(
      (await repository.loadPosts(teamId: 83)).map((post) => post.postId),
      [2, 3, 4, 1],
    );
  });

  test('keeps mock ordering deterministic for every sort', () async {
    final repository = createRepository(posts);

    for (final sort in PostSort.values) {
      expect(
        (await repository.loadPosts(teamId: 83, sort: sort))
            .map((post) => post.postId),
        [2, 3, 4, 1],
        reason: '$sort should currently use newest-first ordering',
      );
    }
  });

  test('applies offset and limit after filtering and sorting', () async {
    final repository = createRepository(posts);

    expect(
      (await repository.loadPosts(teamId: 83, limit: 2, offset: 1))
          .map((post) => post.postId),
      [3, 4],
    );
  });

  test('rejects values outside the backend pagination bounds', () async {
    final repository = createRepository(posts);

    await expectLater(
      repository.loadPosts(teamId: 83, limit: 0),
      throwsRangeError,
    );
    await expectLater(
      repository.loadPosts(teamId: 83, limit: 101),
      throwsRangeError,
    );
    await expectLater(
      repository.loadPosts(teamId: 83, offset: -1),
      throwsRangeError,
    );
    await expectLater(
      repository.loadPosts(teamId: 0),
      throwsRangeError,
    );
  });

  test('requires an IANA timezone for a date-bounded period', () async {
    final repository = createRepository(posts);

    await expectLater(
      repository.loadPosts(teamId: 83, period: PostPeriod.today),
      throwsArgumentError,
    );
    await expectLater(
      repository.loadPosts(
        teamId: 83,
        period: PostPeriod.today,
        timezone: 'America/New_York',
      ),
      completes,
    );
  });

  test('uses the backend period wire values', () {
    expect(
      PostPeriod.values.map((period) => period.apiValue),
      ['all_time', 'today', 'week', 'month', 'year'],
    );
  });

  test('does not expose a mutable result list', () async {
    final repository = createRepository(posts);
    final result = await repository.loadPosts(teamId: 83);

    expect(() => result.clear(), throwsUnsupportedError);
  });

  test('creates a post that appears in subsequent loads', () async {
    final repository = createRepository(posts);
    final input = CreatePostInput(
      teamId: 83,
      category: PostCategory.analysis,
      title: 'Created through repository',
      body: 'Repository creation body',
      attachmentIds: const [11, 12],
    );

    final postId = await repository.createPost(input);
    final created = (await repository.loadPosts(teamId: 83))
        .singleWhere((post) => post.postId == postId);

    expect(created.category, input.category);
    expect(created.title, input.title);
    expect(created.body, input.body);
    expect(
      created.attachments.map((attachment) => attachment.attachmentId),
      input.attachmentIds,
    );
    expect(DateTime.tryParse(created.createdAt), isNotNull);
  });

  test('rejects creation values outside backend text bounds', () async {
    final repository = createRepository(posts);

    await expectLater(
      repository.createPost(
        CreatePostInput(
          teamId: 83,
          category: PostCategory.general,
          title: '',
          body: 'Body',
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.createPost(
        CreatePostInput(
          teamId: 83,
          category: PostCategory.general,
          title: 'Title',
          body: ''.padRight(10001, 'x'),
        ),
      ),
      throwsArgumentError,
    );
  });

  test('rejects invalid creation team and attachment IDs', () async {
    final repository = createRepository(posts);

    await expectLater(
      repository.createPost(
        CreatePostInput(
          teamId: 0,
          category: PostCategory.general,
          title: 'Title',
          body: 'Body',
        ),
      ),
      throwsRangeError,
    );
    await expectLater(
      repository.createPost(
        CreatePostInput(
          teamId: 83,
          category: PostCategory.general,
          title: 'Title',
          body: 'Body',
          attachmentIds: const [1, 1],
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.createPost(
        CreatePostInput(
          teamId: 83,
          category: PostCategory.general,
          title: 'Title',
          body: 'Body',
          attachmentIds: const [0],
        ),
      ),
      throwsArgumentError,
    );
  });

  test('accepts a report at the backend limit', () async {
    final repository = createRepository(posts);

    await expectLater(
      repository.reportPost(
        postId: posts.first.postId,
        reason: ''.padRight(maxPostReportReasonLength, 'x'),
      ),
      completes,
    );
  });

  test('rejects invalid post IDs and reasons outside backend bounds', () async {
    final repository = createRepository(posts);

    await expectLater(
      repository.reportPost(postId: 0, reason: 'Spam'),
      throwsRangeError,
    );
    await expectLater(
      repository.reportPost(postId: posts.first.postId, reason: ''),
      throwsArgumentError,
    );
    await expectLater(
      repository.reportPost(postId: posts.first.postId, reason: '   '),
      throwsArgumentError,
    );
    await expectLater(
      repository.reportPost(
        postId: posts.first.postId,
        reason: ''.padRight(maxPostReportReasonLength + 1, 'x'),
      ),
      throwsArgumentError,
    );
  });
}
