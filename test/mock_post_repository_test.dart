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
    final posts = await repository.loadPosts();

    expect(posts, hasLength(5));
    expect(posts.first.postId, 4);
  });

  test('isolates the temporary mock user identity', () async {
    final repository = MockPostRepository(
      posts: const [],
      currentUserId: 42,
    );

    final postId = await repository.createPost(
      const CreatePostInput(
        category: PostCategory.general,
        title: 'Mock user post',
        body: 'Stored only for this repository instance.',
      ),
    );
    final post = (await repository.loadPosts()).single;

    expect(post.postId, postId);
    expect(post.userId, 42);
  });
}
