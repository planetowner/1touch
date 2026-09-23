import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/highlights/api/api_fixture_highlight_repository.dart';
import 'package:onetouch/data/highlights/fixture_highlight_repository.dart';

final FixtureHighlightRepository fixtureHighlightRepository =
    ApiFixtureHighlightRepository(
  api: apiClient,
);
