import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/posts/api/api_post_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/data/local/local_cache_store_provider.dart';

final ApiPostRepository _apiPostRepository = ApiPostRepository(
  api: apiClient,
  cacheStore: localCacheStore,
);
final PostRepository postRepository = _apiPostRepository;
final PostDetailRepository postDetailRepository = _apiPostRepository;

Future<void> invalidateCommunityPostCache() =>
    _apiPostRepository.invalidatePostCaches();
