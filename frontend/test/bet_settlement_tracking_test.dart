import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/betting/bet_settlement_registry.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/features/betting/bet_settlement_notifications.dart';
import 'package:onetouch/features/betting/betting_controller.dart';
import 'package:onetouch/models/betting.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_betting_repository.dart';

class _MemorySettlementTracker implements BetSettlementTracker {
  final Set<int> ids = {};

  @override
  Set<int> get pendingFixtureIds => Set.unmodifiable(ids);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> remove(int fixtureId) async => ids.remove(fixtureId);

  @override
  Future<void> track(int fixtureId) async => ids.add(fixtureId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final selection in [
    (BetOutcome.homeWin, 90001, 'Home'),
    (BetOutcome.awayWin, 90002, 'Away'),
    (BetOutcome.draw, null, 'Draw'),
  ]) {
    test('settlement retains the selected team identity for ${selection.$1}',
        () async {
      SharedPreferences.setMockInitialValues({});
      final registry = BetSettlementRegistry(
          preferences: await SharedPreferences.getInstance());
      addTearDown(registry.dispose);
      await registry.track(123);
      final betting = FakeBettingRepository()
        ..bet = FixtureBet(
          betId: 7,
          fixtureId: 123,
          outcome: selection.$1,
          stake: 100,
          probabilityText: '0.200000000000000000',
          decimalOdds: 5,
          potentialReturn: 500,
          status: 'won',
          revision: 2,
          payout: 500,
        );
      final controller = BetSettlementNotificationController(
        bettingRepository: betting,
        registry: registry,
        fixtureRepository: MockFixtureRepository(fixtures: const [
          Fixture(
            fixtureId: 123,
            seasonId: 1,
            competitionId: 1,
            homeTeamId: 90001,
            awayTeamId: 90002,
            homeTeamName: 'FC Home',
            awayTeamName: 'FC Away',
            homeTeamShortName: 'Home',
            awayTeamShortName: 'Away',
            competitionType: CompetitionType.league,
            roundName: '1',
            status: FixtureStatus.past,
            startingAt: null,
          ),
        ]),
      );
      addTearDown(controller.dispose);
      await controller.start();
      expect(controller.notice?.selectionTeamId, selection.$2);
      expect(controller.notice?.selectionName, selection.$3);
      expect(controller.notice?.fixture?.homeTeamId, 90001);
      expect(controller.notice?.fixture?.awayTeamId, 90002);
      expect(controller.notice?.fixture?.homeTeamShortName, 'Home');
      expect(controller.notice?.fixture?.awayTeamShortName, 'Away');
    });
  }

  test('tracks an accepted bet and removes a cancelled bet', () async {
    final repository = FakeBettingRepository();
    final tracker = _MemorySettlementTracker();
    final controller = BettingController(
      fixtureId: 19200001,
      repository: repository,
      settlementTracker: tracker,
    );

    await controller.load();
    expect(
        await controller.save(FakeBettingRepository.options.first.outcome, 100),
        isTrue);
    expect(tracker.pendingFixtureIds, {19200001});

    expect(await controller.cancel(), isTrue);
    expect(tracker.pendingFixtureIds, isEmpty);
    controller.dispose();
  });
}
