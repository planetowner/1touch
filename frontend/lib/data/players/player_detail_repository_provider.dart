import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/players/api/api_player_detail_repository.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';

final PlayerDetailRepository playerDetailRepository = _create();
PlayerDetailRepository _create() {
  final config = ApiConfig.fromEnvironment();
  return ApiPlayerDetailRepository(
      client: http.Client(),
      baseUri: config.baseUri,
      headers: config.requestHeaders);
}
