import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/data/best_eleven/mock/mock_best_eleven_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/players/api/api_player_detail_repository.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/features/player/player_image_cache.dart';
import 'package:onetouch/features/team/best_eleven/team_best_eleven_section.dart';
import 'package:onetouch/models/team_best_eleven.dart';
import 'package:onetouch/screens/all_players_screen.dart';

import 'support/app_catalog.dart';
import 'support/decoded_photo_cache.dart';
import 'support/player_detail_fixture.dart';

void main() {
  final photos = DecodedPhotoTestBinding().imageCache as DecodedPhotoCache;
  setUpAppCatalog();
  tearDown(photos.reset);

  for (final variant in TeamBestElevenVariant.values) {
    for (final fromDisk in [false, true]) {
      testWidgets(
          '$variant prepares profiles and portraits before a tap (disk: $fromDisk)',
          (tester) async {
        final store = MemoryLocalCacheStore();
        final requests = <int>[];
        final lineup = _lineup(9, List.generate(11, (i) => i + 1));
        final keys = <Object>[];
        for (final player in lineup.players) {
          keys.add(await registerDecodedPhoto(
              tester,
              photos,
              PlayerImageCache.portraitProvider(_image(player.playerId),
                  devicePixelRatio: 2)));
          if (fromDisk) {
            await store.write(
                LocalCacheKeys.playerDetail(player.playerId, null),
                _detail(player.playerId));
          }
        }
        final details = ApiPlayerDetailRepository(
            cacheStore: store,
            api: _api((request) async {
              final id = int.parse(request.url.pathSegments[2]);
              requests.add(id);
              return _response(id);
            }));
        final lineups = _Lineups({(9, '4-3-3'): lineup}, restored: fromDisk);
        final router = GoRouter(initialLocation: '/team', routes: [
          GoRoute(
              path: '/team',
              builder: (_, __) => Scaffold(
                  body: SingleChildScrollView(
                      child: TeamBestElevenSection(
                          teamId: 9,
                          variant: variant,
                          repository: lineups,
                          playerDetailRepository: details)))),
          GoRoute(
              path: '/players/:id',
              pageBuilder: (_, state) => NoTransitionPage(
                  child: PlayerCard(
                      playerId: int.parse(state.pathParameters['id']!),
                      detailRepository: details))),
        ]);
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(
            routerConfig: router,
            builder: (_, child) => MediaQuery(
                data: const MediaQueryData(
                    size: Size(800, 600), devicePixelRatio: 2),
                child: child!)));
        await tester.pumpAndSettle();
        expect(
            requests,
            fromDisk
                ? isEmpty
                : unorderedEquals(List.generate(11, (i) => i + 1)));
        expect(photos.loads, {for (final key in keys) key: 1});
        for (final id in [11, 6, 1]) {
          await tester.ensureVisible(
              find.byKey(ValueKey('best-eleven-player-link-$id')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ValueKey('best-eleven-player-link-$id')));
          await tester.pump();
          expect(find.byType(FootballLoadingIndicator), findsNothing);
          expect(find.text('174cm'), findsOneWidget);
          final portrait = find.descendant(
              of: find.byKey(const ValueKey('player-overview-image')),
              matching: find.byType(RawImage));
          expect(portrait, findsOneWidget);
          expect(tester.widget<RawImage>(portrait).image, isNotNull);
          expect(details.snapshotFor(id)!.data.playerId, id);
          expect(photos.loads, {for (final key in keys) key: 1});
          router.pop();
          await tester.pumpAndSettle();
        }
        expect(requests.length, fromDisk ? 0 : 11);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets(
      'opening a player during preparation shares the request and failures can retry',
      (tester) async {
    final pending = Completer<http.Response>();
    var requests = 0;
    final details = ApiPlayerDetailRepository(api: _api((_) {
      requests++;
      return requests == 1
          ? pending.future
          : Future.value(_response(1, withImage: false));
    }));
    final lineups = _Lineups({
      (9, '4-3-3'): _lineup(9, [1])
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TeamBestElevenSection(
                teamId: 9,
                variant: TeamBestElevenVariant.overview,
                repository: lineups,
                playerDetailRepository: details))));
    await tester.pumpAndSettle();
    expect(requests, 1);
    await tester.pumpWidget(
        MaterialApp(home: PlayerCard(playerId: 1, detailRepository: details)));
    await tester.pump();
    expect(requests, 1);
    pending.complete(http.Response('Unavailable', 503));
    await tester.pumpAndSettle();
    expect(find.text('Could not load player data'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('174cm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'formation and team changes prepare new players and ignore obsolete photos',
      (tester) async {
    final pending = <int, Completer<http.Response>>{};
    final details = ApiPlayerDetailRepository(
        api: _api((request) => pending
            .putIfAbsent(int.parse(request.url.pathSegments[2]),
                Completer<http.Response>.new)
            .future));
    final lineups = _Lineups({
      (9, '4-3-3'): _lineup(9, [1]),
      (9, '4-4-2'): _lineup(9, [2], formation: '4-4-2'),
      (19, '4-3-3'): _lineup(19, [3]),
    });
    final keys = <int, Object>{
      for (final id in [1, 2, 3])
        id: await registerDecodedPhoto(tester, photos,
            PlayerImageCache.portraitProvider(_image(id), devicePixelRatio: 2)),
    };
    Widget app(int teamId) => MaterialApp(
        home: MediaQuery(
            data:
                const MediaQueryData(size: Size(800, 600), devicePixelRatio: 2),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: TeamBestElevenSection(
                        teamId: teamId,
                        variant: TeamBestElevenVariant.analysis,
                        repository: lineups,
                        playerDetailRepository: details)))));
    await tester.pumpWidget(app(9));
    await tester.pumpAndSettle();
    tester
        .widget<AppDropdown<String>>(find.byType(AppDropdown<String>))
        .onChanged('4-4-2');
    await tester.pumpAndSettle();
    pending[1]!.complete(_response(1));
    pending[2]!.complete(_response(2));
    await tester.pumpAndSettle();
    expect(photos.loads, {keys[2]!: 1});
    await tester.pumpWidget(app(19));
    await tester.pumpAndSettle();
    expect(pending.keys, unorderedEquals([1, 2, 3]));
    await tester.pumpWidget(const SizedBox());
    pending[3]!.complete(_response(3));
    await tester.pumpAndSettle();
    expect(photos.loads, {keys[2]!: 1});
    expect(tester.takeException(), isNull);
  });
}

String _image(int id) => 'https://images.example.test/player-$id.png';
Map<String, dynamic> _detail(int id, {bool withImage = true}) {
  final json = playerDetailJson(
      playerId: id, playerImage: withImage ? _image(id) : null);
  json['profile']['team_id'] = null;
  json['current_indicators'] = {
    'player_id': id,
    'season_name': '2026/2027',
    'as_of': '2026-10-09T18:00:00Z',
    'comparison_scope': 'current_season_big_five_all_positions',
    'squad_role': 'crucial',
    for (final key in ['form', 'cost_effectiveness'])
      key: {
        'grade': 'Fair',
        'band': 2,
        'percentile': 50,
        'reference_count': 1900,
        'rated_matches': 4,
      },
  };
  return json;
}

http.Response _response(int id, {bool withImage = true}) => http.Response.bytes(
    utf8.encode(jsonEncode(_detail(id, withImage: withImage))), 200);
ApiClient _api(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
        client: MockClient(handler),
        baseUri: Uri.parse('https://api.test/v1/'),
        requestHeaders: () => const {});
TeamBestEleven _lineup(int teamId, List<int> ids,
        {String formation = '4-3-3'}) =>
    TeamBestEleven(
      teamId: teamId,
      seasonId: 25583,
      formation: formation,
      formations: const [
        BestElevenFormationOption(formation: '4-3-3', isDefault: true),
        BestElevenFormationOption(formation: '4-4-2', isDefault: false)
      ],
      players: [
        for (var i = 0; i < ids.length; i++)
          BestElevenEntry(
              slotKey: const [
                '1:1',
                '2:1',
                '2:2',
                '2:3',
                '2:4',
                '3:1',
                '3:2',
                '3:3',
                '4:1',
                '4:2',
                '4:3'
              ][i],
              slotIndex: i,
              playerId: ids[i],
              playerName: 'Player ${ids[i]}',
              starts: 1,
              jerseyNumber: ids[i])
      ],
    );

class _Lineups extends MockBestElevenRepository {
  _Lineups(this.lineups, {this.restored = false}) : super(rows: const []);
  final Map<(int, String), TeamBestEleven> lineups;
  final bool restored;
  @override
  TeamBestEleven? cachedForTeam(int teamId,
          {int? seasonId, String? formation}) =>
      restored ? lineups[(teamId, formation ?? '4-3-3')] : null;
  @override
  Future<TeamBestEleven?> loadForTeam(int teamId,
          {bool forceRefresh = false,
          int? seasonId,
          String? formation}) async =>
      lineups[(teamId, formation ?? '4-3-3')];
}
