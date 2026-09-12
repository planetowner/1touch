import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/models/post.dart';

void postRepositoryContract({
  required PostRepository Function(List<Post> posts) createRepository,
}) {
  const posts = [
    Post(
      postId: 1,
      userId: 101,
      category: PostCategory.general,
      title: 'Older general post',
      body: 'Body 1',
      createdAt: '2026-08-20 10:00:00',
    ),
    Post(
      postId: 2,
      userId: 102,
      category: PostCategory.analysis,
      title: 'Newest analysis post',
      body: 'Body 2',
      createdAt: '2026-08-23 10:00:00',
    ),
    Post(
      postId: 3,
      userId: 103,
      category: PostCategory.general,
      title: 'Middle general post',
      body: 'Body 3',
      createdAt: '2026-08-22 10:00:00',
    ),
    Post(
      postId: 4,
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
      (await repository.loadPosts()).map((post) => post.postId),
      [2, 3, 4, 1],
    );
  });

  test('filters by the backend category contract', () async {
    final repository = createRepository(posts);

    expect(
      (await repository.loadPosts(category: PostCategory.general))
          .map((post) => post.postId),
      [3, 1],
    );
  });

  test('mirrors the backend placeholder ordering for every sort', () async {
    final repository = createRepository(posts);

    for (final sort in PostSort.values) {
      expect(
        (await repository.loadPosts(sort: sort)).map((post) => post.postId),
        [2, 3, 4, 1],
        reason: '$sort should currently use newest-first ordering',
      );
    }
  });

  test('applies offset and limit after filtering and sorting', () async {
    final repository = createRepository(posts);

    expect(
      (await repository.loadPosts(limit: 2, offset: 1))
          .map((post) => post.postId),
      [3, 4],
    );
  });

  test('rejects values outside the backend pagination bounds', () async {
    final repository = createRepository(posts);

    await expectLater(repository.loadPosts(limit: 0), throwsRangeError);
    await expectLater(repository.loadPosts(limit: 201), throwsRangeError);
    await expectLater(repository.loadPosts(offset: -1), throwsRangeError);
  });

  test('does not expose a mutable result list', () async {
    final repository = createRepository(posts);
    final result = await repository.loadPosts();

    expect(() => result.clear(), throwsUnsupportedError);
  });

  test('creates a post that appears in subsequent loads', () async {
    final repository = createRepository(posts);
    const input = CreatePostInput(
      category: PostCategory.analysis,
      title: 'Created through repository',
      body: 'Repository creation body',
      mediaUrl: 'https://example.com/post.jpg',
    );

    final postId = await repository.createPost(input);
    final created = (await repository.loadPosts())
        .singleWhere((post) => post.postId == postId);

    expect(created.category, input.category);
    expect(created.title, input.title);
    expect(created.body, input.body);
    expect(created.mediaUrl, input.mediaUrl);
    expect(DateTime.tryParse(created.createdAt), isNotNull);
  });

  test('rejects creation values outside backend text bounds', () async {
    final repository = createRepository(posts);

    await expectLater(
      repository.createPost(
        const CreatePostInput(
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
          category: PostCategory.general,
          title: 'Title',
          body: ''.padRight(10001, 'x'),
        ),
      ),
      throwsArgumentError,
    );
  });

  test('accepts a report at the effective backend storage limit', () async {
    final repository = createRepository(posts);

    await expectLater(
      repository.reportPost(
        postId: posts.first.postId,
        reason: ''.padRight(maxPostReportReasonLength, 'x'),
      ),
      completes,
    );
  });

  test('rejects report reasons outside the effective storage bounds', () async {
    final repository = createRepository(posts);

    await expectLater(
      repository.reportPost(postId: posts.first.postId, reason: ''),
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
