import 'package:onetouch/models/player_indicators.dart';

abstract interface class PlayerIndicatorsRepository {
  Future<PlayerIndicators?> loadCurrent(int playerId);
}
