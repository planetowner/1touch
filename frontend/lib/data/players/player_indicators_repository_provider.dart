import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/players/api/api_player_indicators_repository.dart';
import 'package:onetouch/data/players/player_indicators_repository.dart';

final PlayerIndicatorsRepository playerIndicatorsRepository =
    _createRepository();

PlayerIndicatorsRepository _createRepository() {
  final config = ApiConfig.unauthenticatedFromEnvironment();
  return ApiPlayerIndicatorsRepository(
    client: ApiConfig.sessionAwareClient(),
    apiBaseUri: config.baseUri,
    requestHeaders: config.requestHeaders,
  );
}
