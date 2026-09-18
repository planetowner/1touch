import 'package:onetouch/models/betting.dart';

abstract interface class BettingRepository {
  Future<PointWallet> initializeWallet();
  Future<BettingMarket> loadMarket(int fixtureId);
  Future<BetMutation> saveBet({
    required int fixtureId,
    required String requestId,
    required int expectedRevision,
    required String predictionRunId,
    required BetOutcome outcome,
    required int stake,
  });
  Future<BetMutation> cancelBet({
    required int fixtureId,
    required String requestId,
    required int expectedRevision,
  });
}

class BettingRequestException implements Exception {
  const BettingRequestException(this.code);
  final String code;
}
