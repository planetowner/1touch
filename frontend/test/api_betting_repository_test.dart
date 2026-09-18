import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/betting/api/api_betting_repository.dart';
import 'package:onetouch/data/betting/betting_repository.dart';
import 'package:onetouch/models/betting.dart';

void main() {
  test('reads current auth headers, wallet and decimal model probabilities',
      () async {
    var token = 'first-session';
    var calls = 0;
    final repository = ApiBettingRepository(
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer $token');
        if (calls++ == 0) {
          expect(request.method, 'POST');
          expect(request.url.path, '/v1/users/me/points/initialize');
          return http.Response(jsonEncode(_wallet), 200);
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/fixtures/42/betting');
        return http.Response(jsonEncode(_market()), 200);
      }),
      apiBaseUri: Uri.parse('https://example.test/v1/'),
      requestHeaders: () => {'Authorization': 'Bearer $token'},
    );
    expect((await repository.initializeWallet()).balance, 1000);
    token = 'refreshed-session';
    final market = await repository.loadMarket(42);
    expect(market.options[0].totalReturn(100), 166);
    expect(market.options[1].probability, 0.1);
    expect(market.predictionRunId, 'a' * 64);
    expect(market.userProbabilities, [0.5, 0.0, 0.5]);
    expect(market.closesAt!.isUtc, isTrue);
  });

  test('sends accepted quote, revision and request ID for place and cancel',
      () async {
    var calls = 0;
    const requestId = '08f2f891-c382-4367-a81d-00a96c085d8b';
    final repository = ApiBettingRepository(
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['request_id'], requestId);
        if (calls++ == 0) {
          expect(request.method, 'PUT');
          expect(request.url.path, '/v1/fixtures/42/bet');
          expect(body, {
            'request_id': requestId,
            'expected_revision': 0,
            'prediction_run_id': 'a' * 64,
            'outcome': 'draw',
            'stake': 100,
          });
        } else {
          expect(request.method, 'POST');
          expect(request.url.path, '/v1/fixtures/42/bet/cancel');
          expect(body, {'request_id': requestId, 'expected_revision': 1});
        }
        return http.Response(jsonEncode({'wallet': _wallet, 'bet': _bet}), 200);
      }),
      apiBaseUri: Uri.parse('https://example.test/v1/'),
      requestHeaders: () => {},
    );
    final result = await repository.saveBet(
      fixtureId: 42,
      requestId: requestId,
      expectedRevision: 0,
      predictionRunId: 'a' * 64,
      outcome: BetOutcome.draw,
      stake: 100,
    );
    expect(result.bet.potentialReturn, 1000);
    expect(result.bet.revision, 1);
    await repository.cancelBet(
        fixtureId: 42, requestId: requestId, expectedRevision: 1);
  });

  test('surfaces authentication and stale quotes and rejects wrong fixtures',
      () async {
    final responses = [
      http.Response('Unauthorized', 401),
      http.Response(
          jsonEncode({
            'detail': {'code': 'prediction_changed'}
          }),
          409),
      http.Response(jsonEncode({..._market(), 'fixture_id': 99}), 200),
    ];
    var calls = 0;
    final repository = ApiBettingRepository(
      client: MockClient((_) async => responses[calls++]),
      apiBaseUri: Uri.parse('https://example.test/v1/'),
      requestHeaders: () => {},
    );
    for (final code in ['sign_in_required', 'prediction_changed']) {
      await expectLater(
          repository.loadMarket(42),
          throwsA(
            isA<BettingRequestException>()
                .having((error) => error.code, 'code', code),
          ));
    }
    await expectLater(repository.loadMarket(42), throwsFormatException);
  });
}

const _wallet = {'balance': 1000, 'initialized': true, 'welcome_points': 1000};
const _bet = {
  'bet_id': 1,
  'fixture_id': 42,
  'outcome': 'draw',
  'stake': 100,
  'probability': '0.100000000000000000',
  'decimal_odds': '10.000000000000',
  'potential_return': 1000,
  'status': 'open',
  'revision': 1,
  'payout': 0,
};

Map<String, dynamic> _market() => {
      'fixture_id': 42,
      'available': true,
      'can_bet': true,
      'can_cancel': false,
      'unavailable_reason': null,
      'closes_at': '2026-09-20T18:00:00Z',
      'prediction_run_id': 'a' * 64,
      'prediction_as_of': '2026-09-18T12:00:00Z',
      'options': [
        {
          'outcome': 'home_win',
          'probability': '0.600000000000000000',
          'decimal_odds': '1.666666666667'
        },
        {
          'outcome': 'draw',
          'probability': '0.100000000000000000',
          'decimal_odds': '10.000000000000'
        },
        {
          'outcome': 'away_win',
          'probability': '0.300000000000000000',
          'decimal_odds': '3.333333333333'
        },
      ],
      'wallet': _wallet,
      'bet': null,
      'participation': {
        'total': 2,
        'counts': {'home_win': 1, 'draw': 0, 'away_win': 1},
        'probabilities': {'home_win': 0.5, 'draw': 0.0, 'away_win': 0.5}
      },
    };
