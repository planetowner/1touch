import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';

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
}
