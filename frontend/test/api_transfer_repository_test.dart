import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/transfers/api/api_transfer_repository.dart';

void main() {
  test('requests, maps, and caches the latest team transfer window', () async {
    var requestCount = 0;
    final repository = ApiTransferRepository(
      client: MockClient((request) async {
        requestCount++;
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/teams/83/transfers');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Authorization'], 'Bearer session-token');
        return http.Response(
          jsonEncode(_windowJson()),
          200,
        );
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {'Authorization': 'Bearer session-token'},
    );

    final first = await repository.loadForTeam(83);
    final second = await repository.loadForTeam(83);

    expect(second, same(first));
    expect(first.teamId, 83);
    expect(first.windowKey, '2026/2027 summer');
    expect(first.incoming.single.transferId, 1);
    expect(first.outgoing.single.transferId, 2);
    expect(repository.cachedForTeam(83), same(first));
    expect(requestCount, 1);
    expect(
      () => repository.cachedWindows.value.clear(),
      throwsUnsupportedError,
    );
  });

  test('supports a trailing base-URI slash', () async {
    final repository = ApiTransferRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/v1/teams/83/transfers');
        return http.Response(jsonEncode(_windowJson()), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
      requestHeaders: const {},
    );

    expect(await repository.loadForTeam(83), isNotNull);
  });

  test('accepts a successful empty transfer window', () async {
    final repository = ApiTransferRepository(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'window_key': '2026/2027 summer',
            'transfers_in': [],
            'transfers_out': [],
          }),
          200,
        ),
      ),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    final result = await repository.loadForTeam(83);

    expect(result.incoming, isEmpty);
    expect(result.outgoing, isEmpty);
    expect(repository.cachedForTeam(83), same(result));
  });

  test('keeps different teams in separate cache entries', () async {
    final repository = ApiTransferRepository(
      client: MockClient(
        (_) async => http.Response(jsonEncode(_windowJson()), 200),
      ),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    final first = await repository.loadForTeam(83);
    final second = await repository.loadForTeam(3468);

    expect(first.teamId, 83);
    expect(second.teamId, 3468);
    expect(repository.cachedWindows.value, hasLength(2));
  });

  test('surfaces unavailable, authentication, and server failures', () async {
    final responses = [
      http.Response('Not found', 404),
      http.Response('Unauthorized', 401),
      http.Response('Server error', 500),
    ];
    var requestCount = 0;
    final repository = ApiTransferRepository(
      client: MockClient((_) async => responses[requestCount++]),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    for (var i = 0; i < responses.length; i++) {
      await expectLater(
        repository.loadForTeam(83),
        throwsA(isA<http.ClientException>()),
      );
    }
    expect(repository.cachedWindows.value, isEmpty);
  });

  test('rejects malformed roots and transfer entries without caching',
      () async {
    final malformedEntry = _transferJson(transferId: 1, direction: 'in')
      ..['player_id'] = '101';
    final responses = [
      http.Response(jsonEncode([]), 200),
      http.Response(
        jsonEncode({
          'window_key': '2026/2027 summer',
          'transfers_in': [malformedEntry],
          'transfers_out': [],
        }),
        200,
      ),
    ];
    var requestCount = 0;
    final repository = ApiTransferRepository(
      client: MockClient((_) async => responses[requestCount++]),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(repository.loadForTeam(83), throwsFormatException);
    await expectLater(repository.loadForTeam(83), throwsFormatException);
    expect(repository.cachedWindows.value, isEmpty);
  });
}

Map<String, dynamic> _windowJson() => {
      'window_key': '2026/2027 summer',
      'transfers_in': [_transferJson(transferId: 1, direction: 'in')],
      'transfers_out': [_transferJson(transferId: 2, direction: 'out')],
    };

Map<String, dynamic> _transferJson({
  required int transferId,
  required String direction,
}) =>
    {
      'transfer_id': transferId,
      'player_id': 100 + transferId,
      'player_name': 'Player $transferId',
      'player_image': null,
      'direction': direction,
      'other_team_id': 10,
      'other_team_name': 'Other Team',
      'other_team_image': null,
      'jersey_number': null,
      'type_id': 219,
      'display_type': 'Transfer',
      'amount': null,
      'currency': null,
      'transfer_date': '2026-07-01',
      'contract_start_date': null,
      'contract_end_date': null,
    };
