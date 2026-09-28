import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/betting/bet_settlement_registry.dart';
import 'package:onetouch/features/betting/betting_controller.dart';

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
