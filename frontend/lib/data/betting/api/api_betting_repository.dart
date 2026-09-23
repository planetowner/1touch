import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/betting/api/api_betting_mapper.dart';
import 'package:onetouch/data/betting/betting_repository.dart';
import 'package:onetouch/models/betting.dart';

class ApiBettingRepository implements BettingRepository {
  ApiBettingRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final request = http.Request(method, _api.baseUri.resolve(path))
      ..headers.addAll({
        'Content-Type': 'application/json',
      });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _api.send(request),
    );
    if (response.statusCode == 401) {
      throw const BettingRequestException('sign_in_required');
    }
    if (response.statusCode != 200) {
      String code = 'request_failed';
      try {
        final detail =
            (jsonDecode(response.body) as Map<String, dynamic>)['detail'];
        if (detail is Map<String, dynamic> && detail['code'] is String) {
          code = detail['code'] as String;
        }
      } on FormatException {
        // 서버·프록시의 비 JSON 오류도 같은 재시도 안내를 보여줘요.
      }
      throw BettingRequestException(code);
    }
    return _api.decodeJson<Map<String, dynamic>>(response);
  }

  @override
  Future<PointWallet> initializeWallet() async =>
      walletFromJson(await _request('POST', 'users/me/points/initialize'));

  @override
  Future<BettingMarket> loadMarket(int fixtureId) async {
    final market = marketFromJson(
      await _request('GET', 'fixtures/$fixtureId/betting'),
    );
    if (market.fixtureId != fixtureId) {
      throw const FormatException('Unexpected fixture in betting response');
    }
    return market;
  }

  @override
  Future<BetMutation> saveBet({
    required int fixtureId,
    required String requestId,
    required int expectedRevision,
    required String predictionRunId,
    required BetOutcome outcome,
    required int stake,
  }) async =>
      mutationFromJson(
        await _request('PUT', 'fixtures/$fixtureId/bet', {
          'request_id': requestId,
          'expected_revision': expectedRevision,
          'prediction_run_id': predictionRunId,
          'outcome': outcome.apiValue,
          'stake': stake,
        }),
      );

  @override
  Future<BetMutation> cancelBet({
    required int fixtureId,
    required String requestId,
    required int expectedRevision,
  }) async =>
      mutationFromJson(
        await _request('POST', 'fixtures/$fixtureId/bet/cancel', {
          'request_id': requestId,
          'expected_revision': expectedRevision,
        }),
      );
}
