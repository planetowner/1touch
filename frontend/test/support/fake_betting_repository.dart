import 'dart:async';

import 'package:onetouch/data/betting/betting_repository.dart';
import 'package:onetouch/features/betting/betting_controller.dart';
import 'package:onetouch/models/betting.dart';

class FakeBettingRepository implements BettingRepository {
  int balance = 1000;
  FixtureBet? bet;
  int saveCalls = 0;
  Completer<void>? submitGate;
  Object? saveError;
  final requestIds = <String>[];
  static const options = [
    BettingOption(
      outcome: BetOutcome.homeWin,
      probabilityText: '0.600000000000000000',
      decimalOdds: 1.666666666667,
    ),
    BettingOption(
      outcome: BetOutcome.draw,
      probabilityText: '0.100000000000000000',
      decimalOdds: 10,
    ),
    BettingOption(
      outcome: BetOutcome.awayWin,
      probabilityText: '0.300000000000000000',
      decimalOdds: 3.333333333333,
    ),
  ];

  @override
  Future<PointWallet> initializeWallet() async =>
      PointWallet(balance: balance, initialized: true);

  @override
  Future<BettingMarket> loadMarket(int fixtureId) async => BettingMarket(
        fixtureId: fixtureId,
        available: true,
        canBet: true,
        canCancel: bet?.isOpen == true,
        unavailableReason: null,
        closesAt: DateTime.now().add(const Duration(days: 1)),
        predictionRunId: 'a' * 64,
        predictionAsOf: DateTime.now(),
        options: options,
        wallet: PointWallet(balance: balance, initialized: true),
        bet: bet,
        participantCount: bet?.isOpen == true ? 1 : 0,
        userProbabilities: bet?.isOpen == true
            ? List.generate(3, (i) => i == bet!.outcome.index ? 1.0 : 0.0)
            : null,
      );

  @override
  Future<BetMutation> saveBet({
    required int fixtureId,
    required String requestId,
    required int expectedRevision,
    required String predictionRunId,
    required BetOutcome outcome,
    required int stake,
  }) async {
    saveCalls++;
    requestIds.add(requestId);
    if (submitGate != null) await submitGate!.future;
    if (saveError != null) throw saveError!;
    balance += (bet?.isOpen == true ? bet!.stake : 0) - stake;
    final option = options[outcome.index];
    bet = FixtureBet(
      betId: 1,
      fixtureId: fixtureId,
      outcome: outcome,
      stake: stake,
      probabilityText: option.probabilityText,
      decimalOdds: option.decimalOdds,
      potentialReturn: option.totalReturn(stake),
      status: 'open',
      revision: expectedRevision + 1,
      payout: 0,
    );
    return BetMutation(
      wallet: PointWallet(balance: balance, initialized: true),
      bet: bet!,
    );
  }

  @override
  Future<BetMutation> cancelBet({
    required int fixtureId,
    required String requestId,
    required int expectedRevision,
  }) async {
    final current = bet!;
    balance += current.stake;
    bet = FixtureBet(
      betId: current.betId,
      fixtureId: fixtureId,
      outcome: current.outcome,
      stake: current.stake,
      probabilityText: current.probabilityText,
      decimalOdds: current.decimalOdds,
      potentialReturn: current.potentialReturn,
      status: 'cancelled',
      revision: expectedRevision + 1,
      payout: current.stake,
    );
    return BetMutation(
      wallet: PointWallet(balance: balance, initialized: true),
      bet: bet!,
    );
  }
}

BettingController fakeBettingController(int fixtureId) => BettingController(
      fixtureId: fixtureId,
      repository: FakeBettingRepository(),
    );
