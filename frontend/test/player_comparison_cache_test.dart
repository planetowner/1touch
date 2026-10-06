import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/players/api/api_player_detail_repository.dart';
import 'package:onetouch/data/players/api/api_player_detail_response.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/screens/player_comparison_screen.dart';

import 'support/app_catalog.dart';
import 'support/player_detail_fixture.dart';

class _CachedRepository extends FakePlayerDetailRepository
    implements CachedPlayerDetailRepository {
  PlayerDetailSnapshot? memory, disk;
  int restores = 0;
  final pending = Completer<PlayerDetail>();

  @override
  PlayerDetailSnapshot? snapshotFor(int playerId, {int? seasonId}) => memory;

  @override
  Future<PlayerDetailSnapshot?> restoreFor(int playerId,
      {int? seasonId}) async {
    restores++;
    return disk;
  }

  @override
  Future<PlayerDetail> load(int playerId, {int? seasonId}) {
    calls.add((playerId: playerId, seasonId: seasonId));
    return pending.future;
  }
}

PlayerDetail _detail({String name = 'Player 2'}) {
  final json = playerDetailJson(playerId: 2, position: 'GK');
  json['profile']['name'] = name;
  json['profile']['team_image'] = null;
  return playerDetailFromJson(json);
}

Widget _screen(PlayerDetailRepository repository, {PlayerCandidate? initial}) =>
    MaterialApp(
        home: PlayerComparisonScreen(
      initialPlayerId: '2',
      initialPlayer: initial,
      repository: repository,
    ));

void main() {
  setUpAppCatalog();

  testWidgets(
      'fresh API snapshot appears on first frame without another HTTP request',
      (tester) async {
    final payload = playerDetailJson(playerId: 2, position: 'GK');
    payload['profile']['team_image'] = null;
    var requests = 0;
    final api = ApiClient(
      baseUri: Uri.parse('https://api.test/v1/'),
      requestHeaders: () => {},
      client: MockClient((request) async {
        requests++;
        return http.Response(jsonEncode(payload), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );
    addTearDown(api.close);
    final repository = ApiPlayerDetailRepository(api: api);
    await tester.runAsync(() => repository.load(2));
    expect(requests, 1);
    await tester.pumpWidget(_screen(repository));
    expect(find.text('Player 2'), findsOneWidget);
    expect(find.text('PLAYER 1'), findsNothing);
    await tester.pumpAndSettle();
    expect(requests, 1);
  });

  testWidgets('disk snapshot restores without requesting the API',
      (tester) async {
    final repository = _CachedRepository()
      ..disk = PlayerDetailSnapshot(_detail(), DateTime.now().toUtc());
    await tester.pumpWidget(_screen(repository));
    await tester.pumpAndSettle();
    expect(find.text('Player 2'), findsOneWidget);
    expect(repository.restores, 1);
    expect(repository.calls, isEmpty);
  });

  for (final fails in [false, true]) {
    testWidgets('stale snapshot remains visible during refresh; failure=$fails',
        (tester) async {
      final repository = _CachedRepository()
        ..memory = PlayerDetailSnapshot(_detail(),
            DateTime.now().toUtc().subtract(const Duration(hours: 2)));
      await tester.pumpWidget(_screen(repository));
      expect(find.text('Player 2'), findsOneWidget);
      expect(repository.calls, [(playerId: 2, seasonId: null)]);
      if (fails) {
        repository.pending.completeError(StateError('offline'));
      } else {
        repository.pending.complete(_detail(name: 'Updated player'));
      }
      await tester.pumpAndSettle();
      expect(find.text(fails ? 'Player 2' : 'Updated player'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'known player name and photo appear while first detail is pending',
      (tester) async {
    final repository = _CachedRepository();
    await tester.pumpWidget(_screen(repository, initial: (
      id: 2,
      name: 'Known player',
      image: 'https://cdn.example/player.png'
    )));
    await tester.pump();
    expect(find.text('Known player'), findsOneWidget);
    final image =
        tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.imageUrl, 'https://cdn.example/player.png');
    expect(repository.calls, [(playerId: 2, seasonId: null)]);
    repository.pending.complete(_detail());
    await tester.pumpAndSettle();
    expect(find.text('Player 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final hasCache in [false, true]) {
    testWidgets(
        'leaving during a pending detail does not publish to a disposed store; cache=$hasCache',
        (tester) async {
      final repository = _CachedRepository();
      if (hasCache) {
        repository.memory = PlayerDetailSnapshot(
            _detail(), DateTime.now().subtract(const Duration(hours: 2)));
      }
      await tester.pumpWidget(_screen(repository));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      repository.pending.complete(_detail());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
