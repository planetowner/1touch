import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/local/local_cache_store_provider.dart';
import 'package:onetouch/data/posts/api/api_post_draft_repository.dart';
import 'package:onetouch/data/posts/post_draft_repository.dart';

final CachedPostDraftRepository postDraftRepository = ApiPostDraftRepository(
  api: apiClient,
  cacheStore: localCacheStore,
);

Future<void> invalidatePostDraftCache() =>
    postDraftRepository.invalidateDraftCaches();
