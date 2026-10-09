import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/players/api/api_following_players_repository.dart';
import 'package:onetouch/features/player/player_directory_widgets.dart';
import 'package:onetouch/features/player/player_following_controller.dart';

import 'support/player_detail_fixture.dart';

void main() {
  for (final fromCache in [false, true]) {
    testWidgets(
        'editor shows all identity fields on its first frame, cache=$fromCache',
        (tester) async {
      final store = MemoryLocalCacheStore();
      var requests = 0;
      final repository = ApiFollowingPlayersRepository(
        api: ApiClient(
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {},
          client: MockClient((request) async {
            requests++;
            expect(request.url.path, '/v1/users/me/following/players');
            return http.Response(
                jsonEncode({
                  'items': [
                    {
                      'player_id': 1,
                      'name': 'Followed player',
                      'image_path': null,
                      'team_id': 9,
                      'team_name': 'Current club',
                      'jersey_number': 17,
                    },
                    {
                      'player_id': 2,
                      'name': 'Without number',
                      'image_path': null,
                      'team_id': 8,
                      'team_name': 'Other club',
                      'jersey_number': null,
                    },
                    {
                      'player_id': 3,
                      'name': 'Without club',
                      'image_path': null,
                      'team_id': null,
                      'team_name': null,
                      'jersey_number': null,
                    },
                  ],
                }),
                200);
          }),
        ),
        cacheStore: store,
      );
      final loaded = await repository.load();
      repository.clearMemory();
      final players = fromCache ? (await repository.restoreCached())! : loaded;
      final controller = PlayerFollowingController(repository: repository)
        ..applyAuthoritative(players);
      addTearDown(controller.dispose);
      final details = FakePlayerDetailRepository()..fail = true;
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: app_style.whitetheme,
        home: Scaffold(
          body: PlayerFavorites(
              controller: controller, searchRepository: details),
        ),
      ));

      await tester.tap(find.byTooltip('Edit favorites'));
      await tester.pump();

      final row = find.byKey(const ValueKey('following-editor-1'));
      expect(find.descendant(of: row, matching: find.text('Followed player')),
          findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Current club #17')),
          findsOneWidget);
      expect(find.text('Other club'), findsOneWidget);
      expect(find.byKey(const ValueKey('following-editor-3')), findsOneWidget);
      expect(details.calls, isEmpty);
      expect(requests, 1);
      await tester.pumpAndSettle();
      expect(find.text('Current club #17'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
