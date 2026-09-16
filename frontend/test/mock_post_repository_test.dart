import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/models/post.dart';

import 'support/post_repository_contract.dart';

void main() {
  group('MockPostRepository contract', () {
    postRepositoryContract(
      createRepository: (posts) => MockPostRepository(posts: posts),
    );
  });

  test('wraps the existing community post catalog by default', () async {
    final repository = MockPostRepository();
    final posts = await repository.loadPosts(teamId: 83);

    expect(posts, hasLength(2));
    expect(posts.first.postId, 1);
  });

  test('isolates the temporary mock user identity', () async {
    final repository = MockPostRepository(
      posts: const [],
      currentUserId: 42,
    );

    final postId = await repository.createPost(
      CreatePostInput(
        teamId: 83,
        category: PostCategory.general,
        title: 'Mock user post',
        body: 'Stored only for this repository instance.',
      ),
    );
    final post = (await repository.loadPosts(teamId: 83)).single;

    expect(post.postId, postId);
    expect(post.teamId, 83);
    expect(post.userId, 42);
  });

  test('keeps immutable report records inside the mock instance', () async {
    final repository = MockPostRepository(currentUserId: 42);

    await repository.reportPost(
      postId: 4,
      reason: 'Inappropriate Content',
    );

    expect(
      repository.reports,
      [
        (
          postId: 4,
          userId: 42,
          reason: 'Inappropriate Content',
        ),
      ],
    );
    expect(() => repository.reports.clear(), throwsUnsupportedError);
  });
}
