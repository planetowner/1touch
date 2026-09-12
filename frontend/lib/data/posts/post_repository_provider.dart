import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';

// TODO(posts): Replace this mock-backed provider after the app has a configured
// API base URL and authenticated transport for the required X-User-Id header.
final PostRepository postRepository = MockPostRepository();
