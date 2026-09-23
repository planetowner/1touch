import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';

/// API 주소와 요청 시점의 인증 헤더를 한곳에서 관리해요.
class ApiClient extends http.BaseClient {
  ApiClient({
    required http.Client client,
    required Uri baseUri,
    required Map<String, String> Function() requestHeaders,
  })  : _client = client,
        baseUri = ApiConfig.fromValues(baseUri: baseUri.toString()).baseUri,
        _requestHeaders = requestHeaders;

  final http.Client _client;
  final Uri baseUri;
  final Map<String, String> Function() _requestHeaders;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // 저장소가 로그인 전에 만들어져도 새 세션으로 요청해야 해요.
    request.headers.addAll({
      'Accept': 'application/json',
      ..._requestHeaders(),
    });
    return _client.send(request);
  }

  T decodeJson<T>(http.Response response, {int? expectedStatus = 200}) {
    final successful = expectedStatus == null
        ? response.statusCode >= 200 && response.statusCode < 300
        : response.statusCode == expectedStatus;
    if (!successful) {
      throw http.ClientException(
        'API request failed with status ${response.statusCode}.',
        response.request?.url,
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! T) {
      throw FormatException('Expected a JSON response of type $T.');
    }
    return decoded;
  }

  @override
  void close() => _client.close();
}
