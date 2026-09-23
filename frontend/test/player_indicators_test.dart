import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/players/api/api_player_indicators_repository.dart';
import 'package:onetouch/data/players/api/api_player_indicators_response.dart';
import 'package:onetouch/data/players/player_indicators_repository.dart';
import 'package:onetouch/data/players/player_repository_provider.dart';
import 'package:onetouch/models/player_indicators.dart';
import 'package:onetouch/features/player/rating_level_ring.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/Overview.dart';

Map<String, Object?> _scoreJson({String? grade = 'Fair', int? band = 2}) => {
      'grade': grade,
      'band': band,
      'percentile': grade == null ? null : 50,
      'reference_count': grade == null ? 0 : 1900,
      'rated_matches': 4,
      'unavailable_reason': grade == null ? 'wage_unavailable' : null,
    };

Map<String, Object?> _response() => {
      'player_id': 997,
      'season_name': '2026/2027',
      'as_of': '2026-09-20T18:00:00Z',
      'comparison_scope': 'current_season_big_five_all_positions',
      'form': _scoreJson(),
      'cost_effectiveness': _scoreJson(grade: null, band: null),
    };

PlayerIndicators _indicators(int id,
        {bool missingWage = false, String? squadRole = 'Crucial'}) =>
    PlayerIndicators(
      playerId: id,
      squadRole: squadRole,
      seasonName: '2026/2027',
      asOf: DateTime.utc(2026, 9, 20),
      form: const PlayerIndicatorScore(
        grade: 'Fair',
        band: 2,
        percentile: 50,
        referenceCount: 1953,
        ratedMatches: 4,
      ),
      costEffectiveness: PlayerIndicatorScore(
        grade: missingWage ? null : 'Very Good',
        band: missingWage ? null : 4,
        percentile: null,
        referenceCount: missingWage ? 0 : 1486,
        ratedMatches: 4,
        unavailableReason: missingWage ? 'wage_unavailable' : null,
      ),
    );

class _Repository implements PlayerIndicatorsRepository {
  _Repository(this.load);
  final Future<PlayerIndicators?> Function(int) load;

  @override
  Future<PlayerIndicators?> loadCurrent(int playerId) => load(playerId);
}

void main() {
  test(
    'all five squad roles are mapped and missing roles stay unavailable',
    () {
      for (final role in [
        'crucial',
        'important',
        'rotation',
        'sporadic',
        'prospect',
      ]) {
        final response = ApiPlayerIndicatorsResponse.fromJson(
          _response()..['squad_role'] = role,
        );
        expect(
          response.indicators.squadRole,
          '${role[0].toUpperCase()}${role.substring(1)}',
        );
      }
      expect(
        ApiPlayerIndicatorsResponse.fromJson(
          _response()..['squad_role'] = null,
        ).indicators.squadRole,
        isNull,
      );
      expect(
        () => ApiPlayerIndicatorsResponse.fromJson(
          _response()..['squad_role'] = 'unknown',
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'error-based cost grades accept null percentile while Form requires it',
    () {
      final payload = _response()
        ..['cost_effectiveness'] = (_scoreJson()..['percentile'] = null);
      final result = ApiPlayerIndicatorsResponse.fromJson(payload).indicators;
      expect(result.costEffectiveness.grade, 'Fair');
      expect(result.costEffectiveness.percentile, isNull);
      payload['form'] = _scoreJson()..['percentile'] = null;
      expect(
        () => ApiPlayerIndicatorsResponse.fromJson(payload),
        throwsFormatException,
      );
    },
  );

  test(
    'API requests current season by provider ID and preserves null wages',
    () async {
      final repository = ApiPlayerIndicatorsRepository(
        api: ApiClient(
            client: MockClient((request) async {
              expect(request.url.path, '/v1/players/997/indicators');
              expect(request.url.queryParameters, isEmpty);
              expect(request.headers['Authorization'], 'Bearer test-session');
              return http.Response(jsonEncode(_response()), 200);
            }),
            baseUri: Uri.parse('https://example.test/v1'),
            requestHeaders: () =>
                const {'Authorization': 'Bearer test-session'}),
      );
      final result = (await repository.loadCurrent(997))!;
      expect(result.seasonName, '2026/2027');
      expect(result.form.grade, 'Fair');
      expect(result.costEffectiveness.grade, isNull);
      expect(result.costEffectiveness.unavailableReason, 'wage_unavailable');
    },
  );

  test(
    'API distinguishes missing current roster from request failure',
    () async {
      var status = 404;
      final repository = ApiPlayerIndicatorsRepository(
        api: ApiClient(
            client: MockClient(
              (_) async => http.Response(
                '{"detail":"Player not in a current five-league squad"}',
                status,
              ),
            ),
            baseUri: Uri.parse('https://example.test/v1/'),
            requestHeaders: () => const {}),
      );
      expect(await repository.loadCurrent(997), isNull);
      status = 503;
      await expectLater(
        repository.loadCurrent(997),
        throwsA(isA<http.ClientException>()),
      );
      await expectLater(repository.loadCurrent(0), throwsRangeError);
    },
  );

  test(
    'API rejects a different player, comparison scope, or invalid grade band',
    () async {
      for (final payload in [
        _response()..['player_id'] = 4125,
        _response()..['comparison_scope'] = 'historical',
        _response()..['form'] = _scoreJson(band: 5),
      ]) {
        final repository = ApiPlayerIndicatorsRepository(
          api: ApiClient(
              client: MockClient(
                (_) async => http.Response(jsonEncode(payload), 200),
              ),
              baseUri: Uri.parse('https://example.test/v1/'),
              requestHeaders: () => const {}),
        );
        await expectLater(repository.loadCurrent(997), throwsFormatException);
      }
    },
  );

  test('catalog provider IDs are present and unique', () {
    final ids =
        playerRepository.allPlayers.map((p) => p.externalPlayerId).toList();
    expect(ids, isNot(contains(null)));
    expect(ids.toSet().length, ids.length);
    expect(playerRepository.findById('harry-kane')!.externalPlayerId, 997);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final dark in [false, true]) {
      testWidgets(
        'indicator card fits $size in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final player = playerRepository.findById('harry-kane')!;
          final repository = _Repository((id) async => _indicators(id));
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? darktheme : whitetheme,
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(24),
                  child: PlayerBioStatsBlock(
                    player: player,
                    repository: repository,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Fair'), findsOneWidget);
          expect(find.text('Very Good'), findsOneWidget);
          expect(find.text('Height'), findsOneWidget);
          expect(find.text('Squad Role'), findsOneWidget);
          // 최신 카드의 축소된 라벨 대신 같은 행에 있는 실제 값의 중심을 비교해요.
          expect(
            tester.getCenter(find.byKey(const ValueKey('player-form'))).dy,
            closeTo(
              tester
                  .getCenter(
                    find.byKey(const ValueKey('player-cost-effectiveness')),
                  )
                  .dy,
              .01,
            ),
          );
          expect(
            tester
                .widgetList<RatingLevelRing>(find.byType(RatingLevelRing))
                .map((ring) => ring.level),
            [3, 5],
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byIcon(Icons.help_outline));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Transfer fees are not included.'),
            findsOneWidget,
          );
        },
      );
    }
  }

  testWidgets('missing wage displays no invented grade or ring', (
    tester,
  ) async {
    final player = playerRepository.findById('harry-kane')!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerBioStatsBlock(
            player: player,
            repository: _Repository(
              (id) async => _indicators(id, missingWage: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fair'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Very Good'), findsNothing);
    final cost = find.byKey(const ValueKey('player-cost-effectiveness'));
    expect(
      find.descendant(of: cost, matching: find.byType(CustomPaint)),
      findsNothing,
    );
  });

  testWidgets('old response cannot overwrite a newly selected player', (
    tester,
  ) async {
    final first = Completer<PlayerIndicators?>();
    final second = Completer<PlayerIndicators?>();
    final kane = playerRepository.findById('harry-kane')!;
    final salah = playerRepository.findById('mohamed-salah')!;
    final repository = _Repository(
      (id) => id == 997 ? first.future : second.future,
    );
    Widget page(player) => MaterialApp(
          home: Scaffold(
            body: PlayerBioStatsBlock(player: player, repository: repository),
          ),
        );
    await tester.pumpWidget(page(kane));
    await tester.pumpWidget(page(salah));
    second.complete(null);
    await tester.pumpAndSettle();
    first.complete(_indicators(997));
    await tester.pumpAndSettle();
    expect(find.text('Fair'), findsNothing);
    expect(find.text('—'), findsNWidgets(3));
  });

  testWidgets('request failure offers a working retry', (tester) async {
    var calls = 0;
    final repository = _Repository((id) async {
      if (++calls == 1) throw Exception('Test network failure');
      return _indicators(id);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerBioStatsBlock(
            player: playerRepository.findById('harry-kane')!,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unavailable'), findsNWidgets(3));
    await tester.tap(find.byIcon(Icons.refresh).first);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Fair'), findsOneWidget);
    expect(find.text('Very Good'), findsOneWidget);
  });
  testWidgets('missing calculated squad role never displays the mock role', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerBioStatsBlock(
            player: playerRepository.findById('harry-kane')!,
            repository: _Repository(
              (id) async => _indicators(id, squadRole: null),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final role = find.byKey(const ValueKey('player-squad-role'));
    expect(find.descendant(of: role, matching: find.text('—')), findsOneWidget);
    expect(find.text('Fair'), findsOneWidget);
  });
}
