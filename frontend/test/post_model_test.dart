import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/models/post.dart';

void main() {
  test('parses the GET /v1/posts item contract', () {
    final post = Post.fromJson(const {
      'post_id': 42,
      'user_id': 1001,
      'category': 'analysis',
      'title': 'Pressing structure',
      'body': 'A tactical breakdown.',
      'media_url': null,
      'created_at': '2026-08-24 09:30:00',
    });

    expect(post.postId, 42);
    expect(post.userId, 1001);
    expect(post.category, PostCategory.analysis);
    expect(post.title, 'Pressing structure');
    expect(post.body, 'A tactical breakdown.');
    expect(post.mediaUrl, isNull);
    expect(post.createdAt, '2026-08-24 09:30:00');
  });
}
