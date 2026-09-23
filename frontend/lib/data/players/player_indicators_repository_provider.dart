import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/players/api/api_player_indicators_repository.dart';
import 'package:onetouch/data/players/player_indicators_repository.dart';

final PlayerIndicatorsRepository playerIndicatorsRepository =
    ApiPlayerIndicatorsRepository(api: apiClient);
