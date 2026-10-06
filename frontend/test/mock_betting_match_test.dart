import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/debug/mock_betting_match.dart';
import 'package:onetouch/models/betting.dart';
import 'package:onetouch/models/fixture.dart';

void main() {
  test('debug betting fixture is upcoming and inside the betting window',
      () async {
    final match = MockBettingMatch();
    final fixture = match.fixtures.findById(mockBettingMatchId)!;
    final market = await match.betting.loadMarket(mockBettingMatchId);

    expect(fixture.status, FixtureStatus.upcoming);
    expect(fixture.kickoff!.isAfter(DateTime.now()), isTrue);
    expect(fixture.kickoff!.difference(DateTime.now()).inHours, 11);
    expect(market.canBet, isTrue);
    expect(market.closesAt!.isAfter(DateTime.now()), isTrue);
    expect(market.wallet.balance, 1200);
    expect(market.options, hasLength(3));
    expect(
      market.options.map((option) => option.probability).toList(),
      [0.978, 0.011, 0.011],
    );
  });

  test('debug betting repository saves and cancels locally', () async {
    final repository = MockBettingRepository();
    final market = await repository.loadMarket(mockBettingMatchId);
    final saved = await repository.saveBet(
      fixtureId: mockBettingMatchId,
      requestId: 'debug-save',
      expectedRevision: 0,
      predictionRunId: market.predictionRunId!,
      outcome: BetOutcome.homeWin,
      stake: 120,
    );

    expect(saved.wallet.balance, 1080);
    expect(saved.bet.stake, 120);

    final cancelled = await repository.cancelBet(
      fixtureId: mockBettingMatchId,
      requestId: 'debug-cancel',
      expectedRevision: saved.bet.revision,
    );
    expect(cancelled.wallet.balance, 1200);
    expect(cancelled.bet.status, 'cancelled');
  });
}
