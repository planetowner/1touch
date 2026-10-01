import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/players/api/api_player_detail_response.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/models/player_detail.dart';

import 'support/player_detail_fixture.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('shows a stored player without a loader at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final detail = detailFixture(playerId: 1);
      final repository = _CachedDetailRepository(
        memory: PlayerDetailSnapshot(detail, DateTime.now()),
      );

      await tester.pumpWidget(_playerView(repository));
      expect(find.text('Player 1'), findsOneWidget);
      expect(find.byType(FootballLoadingIndicator), findsNothing);
      expect(repository.loads, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('restores an old detail, then replaces it after refresh',
      (tester) async {
    final cached = detailFixture(playerId: 1);
    final repository = _CachedDetailRepository(
      disk: PlayerDetailSnapshot(
          cached, DateTime.now().subtract(const Duration(hours: 2))),
    );
    await tester.pumpWidget(_playerView(repository));
    await tester.pump();

    expect(find.text('Player 1'), findsOneWidget);
    expect(find.byType(FootballLoadingIndicator), findsNothing);
    expect(repository.loads, 1);

    final updatedJson = playerDetailJson(playerId: 1);
    (updatedJson['profile'] as Map<String, dynamic>)['name'] = 'Updated Player';
    repository.complete(playerDetailFromJson(updatedJson));
    await tester.pump();
    await tester.pump();
    expect(find.text('Updated Player'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the stored detail if refresh fails', (tester) async {
    final repository = _CachedDetailRepository(
      disk: PlayerDetailSnapshot(detailFixture(playerId: 1),
          DateTime.now().subtract(const Duration(hours: 2))),
    );
    await tester.pumpWidget(_playerView(repository));
    await tester.pump();
    repository.failRefresh();
    await tester.pump();
    expect(find.text('Player 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not show the previous season while another one loads',
      (tester) async {
    final repository = _ControlledDetailRepository();
    int? seasonId;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlayerDetailScope(
          store: PlayerDetailStore(playerId: 1, repository: repository),
          child: StatefulBuilder(
              builder: (context, update) => Column(
                    children: [
                      TextButton(
                        onPressed: () => update(() => seasonId = 42),
                        child: const Text('Change season'),
                      ),
                      Expanded(
                        child: PlayerDetailView(
                          playerId: 1,
                          seasonId: seasonId,
                          builder: (_, detail) => Text(detail.profile.name),
                        ),
                      ),
                    ],
                  )),
        ),
      ),
    ));
    repository.complete(null, detailFixture(playerId: 1));
    await tester.pump();
    expect(find.text('Player 1'), findsOneWidget);

    await tester.tap(find.text('Change season'));
    await tester.pump();
    expect(find.text('Player 1'), findsNothing);
    expect(find.byType(FootballLoadingIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _playerView(_CachedDetailRepository repository) => MaterialApp(
      home: Scaffold(
        body: PlayerDetailScope(
          store: PlayerDetailStore(playerId: 1, repository: repository),
          child: PlayerDetailView(
            playerId: 1,
            builder: (_, detail) => Text(detail.profile.name),
          ),
        ),
      ),
    );

class _CachedDetailRepository extends FakePlayerDetailRepository
    implements CachedPlayerDetailRepository {
  _CachedDetailRepository({this.memory, this.disk});

  final PlayerDetailSnapshot? memory;
  final PlayerDetailSnapshot? disk;
  final _refresh = Completer<PlayerDetail>();
  int loads = 0;

  @override
  PlayerDetailSnapshot? snapshotFor(int playerId, {int? seasonId}) => memory;

  @override
  Future<PlayerDetailSnapshot?> restoreFor(int playerId,
          {int? seasonId}) async =>
      disk;

  @override
  Future<PlayerDetail> load(int playerId, {int? seasonId}) {
    loads++;
    return _refresh.future;
  }

  void complete(PlayerDetail detail) => _refresh.complete(detail);
  void failRefresh() => _refresh.completeError(StateError('offline'));

  @override
  Future<List<PlayerCandidate>> search(String query) async => const [];
}

class _ControlledDetailRepository extends FakePlayerDetailRepository {
  final _requests = <int?, Completer<PlayerDetail>>{};

  @override
  Future<PlayerDetail> load(int playerId, {int? seasonId}) =>
      _requests.putIfAbsent(seasonId, Completer<PlayerDetail>.new).future;

  void complete(int? seasonId, PlayerDetail detail) =>
      _requests[seasonId]!.complete(detail);

  @override
  Future<List<PlayerCandidate>> search(String query) async => const [];
}
