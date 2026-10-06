import 'package:flutter/foundation.dart';
import 'package:onetouch/data/betting/betting_repository.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/models/betting.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_detail.dart';

const bool mockBettingMatchEnabled =
    kDebugMode && bool.fromEnvironment('ENABLE_TEST_BETTING_MATCH');

const int mockBettingMatchId = 999999002;

class MockBettingMatch {
  MockBettingMatch()
      : fixtures = MockBettingFixtureRepository(),
        betting = MockBettingRepository();

  final MockBettingFixtureRepository fixtures;
  final MockBettingRepository betting;
}

class MockBettingFixtureRepository extends MockFixtureRepository {
  MockBettingFixtureRepository()
      : super(
          fixtures: [_fixture()],
          fixtureDetails: [_detail()],
        );

  static Fixture _fixture() => Fixture(
        fixtureId: mockBettingMatchId,
        seasonId: 25659,
        competitionId: 564,
        homeTeamId: 83,
        awayTeamId: 676,
        homeTeamName: 'FC Barcelona',
        awayTeamName: 'Girona',
        homeTeamShortName: 'FCB',
        awayTeamShortName: 'GIR',
        competitionType: CompetitionType.league,
        roundName: '8',
        status: FixtureStatus.upcoming,
        stateId: 1,
        startingAt:
            DateTime.now().add(const Duration(hours: 12)).toIso8601String(),
        homeScore: null,
        awayScore: null,
      );

  static FixtureDetail _detail() => FixtureDetail(
        fixture: _fixture(),
        clock: null,
        venueName: 'Estadi Olimpic Lluis Companys',
        expectedGoals: null,
        playerExpectedGoals: const [],
        shots: const [],
        events: const [],
        statistics: const [],
        lineups: const [],
        formations: const [],
        coaches: const [],
        pressure: const [],
      );
}

class MockBettingRepository implements BettingRepository {
  static const _options = [
    BettingOption(
      outcome: BetOutcome.homeWin,
      probabilityText: '0.978000000000000000',
      decimalOdds: 1.022494887526,
    ),
    BettingOption(
      outcome: BetOutcome.draw,
      probabilityText: '0.011000000000000000',
      decimalOdds: 90.909090909091,
    ),
    BettingOption(
      outcome: BetOutcome.awayWin,
      probabilityText: '0.011000000000000000',
      decimalOdds: 90.909090909091,
    ),
  ];

  int _balance = 1200;
  FixtureBet? _bet;

  @override
  Future<PointWallet> initializeWallet() async =>
      PointWallet(balance: _balance, initialized: true);

  @override
  Future<BettingMarket> loadMarket(int fixtureId) async {
    _requireFixture(fixtureId);
    return BettingMarket(
      fixtureId: fixtureId,
      stakeUnit: 10,
      opensAt: DateTime.now().subtract(const Duration(hours: 12)),
      available: true,
      canBet: true,
      canCancel: _bet?.isOpen == true,
      unavailableReason: null,
      closesAt: DateTime.now().add(const Duration(hours: 12)),
      predictionRunId: 'd' * 64,
      predictionAsOf: DateTime.now(),
      options: _options,
      wallet: PointWallet(balance: _balance, initialized: true),
      bet: _bet,
      participantCount: _bet?.isOpen == true ? 1 : 0,
      userProbabilities: _bet?.isOpen == true
          ? List.generate(
              BetOutcome.values.length,
              (index) => index == _bet!.outcome.index ? 1 : 0,
            )
          : null,
    );
  }

  @override
  Future<BetMutation> saveBet({
    required int fixtureId,
    required String requestId,
    required int expectedRevision,
    required String predictionRunId,
    required BetOutcome outcome,
    required int stake,
  }) async {
    _requireFixture(fixtureId);
    final previousStake = _bet?.isOpen == true ? _bet!.stake : 0;
    if (stake > _balance + previousStake) {
      throw const BettingRequestException('insufficient_points');
    }
    final option = _options.firstWhere((item) => item.outcome == outcome);
    _balance += previousStake - stake;
    _bet = FixtureBet(
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
      wallet: PointWallet(balance: _balance, initialized: true),
      bet: _bet!,
    );
  }

  @override
  Future<BetMutation> cancelBet({
    required int fixtureId,
    required String requestId,
    required int expectedRevision,
  }) async {
    _requireFixture(fixtureId);
    final current = _bet;
    if (current?.isOpen != true) {
      throw StateError('There is no open test bet.');
    }
    _balance += current!.stake;
    _bet = FixtureBet(
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
      wallet: PointWallet(balance: _balance, initialized: true),
      bet: _bet!,
    );
  }

  void _requireFixture(int fixtureId) {
    if (fixtureId != mockBettingMatchId) {
      throw StateError('Unknown test fixture: $fixtureId');
    }
  }
}
