import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/auth/auth_session.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();
final AuthSession authSession = _createSession();

final ApiClient apiClient = ApiClient(
  client: http.Client(),
  baseUri: _apiConfig.baseUri,
  requestHeaders: () => authSession.requestHeaders,
);

AuthSession _createSession() {
  final session = AuthSession();
  final developmentToken = _apiConfig.sessionToken;
  // 개발 토큰도 같은 세션에 넣어 실제 로그인 후에는 새 토큰만 사용해요.
  if (developmentToken != null) session.establish(developmentToken);
  return session;
}
