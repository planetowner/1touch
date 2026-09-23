import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_repository.dart';
import 'package:onetouch/data/fixtures/fixture_repository.dart';

final FixtureRepository fixtureRepository = ApiFixtureRepository(api: apiClient);
final FixtureRepository fixtureDetailRepository = fixtureRepository;
