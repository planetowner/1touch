import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/auth/auth_repository_provider.dart';
import 'package:onetouch/data/betting/api/api_betting_repository.dart';
import 'package:onetouch/data/betting/betting_repository.dart';

final BettingRepository bettingRepository = ApiBettingRepository(
  client: ApiConfig.sessionAwareClient(),
  apiBaseUri: ApiConfig.unauthenticatedFromEnvironment().baseUri,
  // 실제 로그인 토큰을 우선하고, 기존 개발 실행에서는 명시한 개발 세션을 사용해요.
  requestHeaders: () => authSession.isAuthenticated
      ? authSession.requestHeaders
      : ApiConfig.unauthenticatedFromEnvironment().requestHeaders,
);
