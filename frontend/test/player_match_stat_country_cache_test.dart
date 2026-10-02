import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/features/kane_rest.dart';
import 'package:onetouch/features/player/player_following_controller.dart';

import 'support/player_detail_fixture.dart';
import 'support/player_directory_fixture.dart';

class _CachedDetailRepository extends FakePlayerDetailRepository
    implements CachedPlayerDetailRepository {
  PlayerDetailSnapshot? memory;
  PlayerDetailSnapshot? disk;
  int restoreCalls = 0;

  @override
  PlayerDetailSnapshot? snapshotFor(int playerId, {int? seasonId}) => memory;

  @override
  Future<PlayerDetailSnapshot?> restoreFor(int playerId,
      {int? seasonId}) async {
    restoreCalls++;
    return disk;
  }
}

void main() {
  const player = PlayerMatchStatData(
    playerId: 2,
    teamPrimaryColor: 0xFFA50044,
    name: 'Test Player',
    jerseyNumber: 7,
    positions: ['FW'],
    club: 'Barcelona',
    nationality: null,
    sections: [],
  );

  Future<void> showSheet(
      WidgetTester tester, _CachedDetailRepository repository) async {
    final following = PlayerFollowingController(
      repository: FakeFollowingPlayersRepository(),
    );
    addTearDown(following.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlayerMatchStatSheet(
          player: player,
          detailRepository: repository,
          followingController: following,
        ),
      ),
    ));
  }

  testWidgets('memory-cached country is visible on the first frame',
      (tester) async {
    final repository = _CachedDetailRepository()
      ..memory = PlayerDetailSnapshot(
        detailFixture(playerId: 2),
        DateTime.now().toUtc(),
      );

    await showSheet(tester, repository);

    expect(find.text('South Korea'), findsOneWidget);
    expect(repository.restoreCalls, 0);
    expect(repository.calls, isEmpty);
  });

  testWidgets('disk-cached country restores without an API request',
      (tester) async {
    final repository = _CachedDetailRepository()
      ..disk = PlayerDetailSnapshot(
        detailFixture(playerId: 2),
        DateTime.now().toUtc(),
      );

    await showSheet(tester, repository);
    await tester.pump();

    expect(find.text('South Korea'), findsOneWidget);
    expect(repository.restoreCalls, 1);
    expect(repository.calls, isEmpty);
  });

  testWidgets('stale country stays visible when refresh fails', (tester) async {
    final repository = _CachedDetailRepository()
      ..memory = PlayerDetailSnapshot(
        detailFixture(playerId: 2),
        DateTime.now().toUtc().subtract(const Duration(hours: 2)),
      )
      ..fail = true;

    await showSheet(tester, repository);
    expect(find.text('South Korea'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('South Korea'), findsOneWidget);
    expect(repository.calls, [(playerId: 2, seasonId: null)]);
    expect(tester.takeException(), isNull);
  });
}
