import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/players/api/api_player_detail_repository.dart';
import 'package:onetouch/data/players/api/api_player_detail_response.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/Overview.dart';

import 'support/player_detail_fixture.dart';

Map<String, dynamic> _detailWithIndicators() {
  final payload = playerDetailJson(playerId: 1);
  payload['profile']['team_id'] = null;
  payload['current_indicators'] = {
    'player_id': 1,
    'season_name': '2026/2027',
    'as_of': '2026-10-09T18:00:00Z',
    'comparison_scope': 'current_season_big_five_all_positions',
    'squad_role': 'crucial',
    'form': {
      'grade': 'Fair',
      'band': 2,
      'percentile': 50,
      'reference_count': 1900,
      'rated_matches': 4,
    },
    'cost_effectiveness': {
      'grade': 'Very Good',
      'band': 4,
      'percentile': null,
      'reference_count': 1400,
      'rated_matches': 4,
    },
  };
  return payload;
}

void main() {
  test('embedded indicators must belong to the requested player', () {
    final payload = _detailWithIndicators();
    payload['current_indicators']['player_id'] = 2;
    expect(() => playerDetailFromJson(payload), throwsFormatException);
  });

  testWidgets('overview shows indicators with the profile from API and cache',
      (tester) async {
    final store = MemoryLocalCacheStore();
    await store.write('player-detail:1:current', playerDetailJson(playerId: 1));
    final requests = <String>[];
    final response = Completer<http.Response>();
    final client = MockClient((request) async {
      requests.add(request.url.path);
      return response.future;
    });
    ApiPlayerDetailRepository repository() => ApiPlayerDetailRepository(
          api: ApiClient(
            client: client,
            baseUri: Uri.parse('https://example.com/v1/'),
            requestHeaders: () => const {},
          ),
          cacheStore: store,
        );
    final original = repository();
    expect(await original.restoreFor(1), isNull);
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await http.runWithClient(() async {
      for (final mode in ['network', 'memory', 'disk']) {
        final source = mode == 'disk' ? repository() : original;
        if (mode == 'disk') await source.restoreFor(1);
        final detailStore = PlayerDetailStore(playerId: 1, repository: source);
        await tester.pumpWidget(MaterialApp(
          theme: whitetheme,
          home: Scaffold(
            body: PlayerDetailScope(
              store: detailStore,
              child: const PlayerOverviewTab(playerId: 1),
            ),
          ),
        ));

        if (mode == 'network') {
          expect(find.text('Height'), findsNothing);
          response.complete(http.Response.bytes(
              utf8.encode(jsonEncode(_detailWithIndicators())), 200));
          await tester.pump();
        }
        expect(find.text('Height'), findsOneWidget);
        expect(find.text('Crucial'), findsOneWidget);
        expect(find.text('Fair'), findsOneWidget);
        expect(find.text('Very Good'), findsOneWidget);
        expect(find.text('Loading'), findsNothing);
        expect(requests, ['/v1/players/1/detail']);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        detailStore.dispose();
      }
    }, () => client);
  });
}
