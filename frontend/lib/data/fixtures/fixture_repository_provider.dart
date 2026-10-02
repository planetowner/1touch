import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_repository.dart';
import 'package:onetouch/data/fixtures/fixture_repository.dart';
import 'package:onetouch/data/local/local_cache_store_provider.dart';

final FixtureRepository fixtureRepository = ApiFixtureRepository(
  api: apiClient,
  cacheStore: localCacheStore,
);
final FixtureRepository fixtureDetailRepository = fixtureRepository;
