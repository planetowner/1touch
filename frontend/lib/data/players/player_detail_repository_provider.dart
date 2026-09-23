import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/players/api/api_player_detail_repository.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';

final PlayerDetailRepository playerDetailRepository =
    ApiPlayerDetailRepository(api: apiClient);
