import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/profile/api/api_current_user_repository.dart';

/// API에서 제공하는 비공개 이미지도 현재 로그인 세션으로 요청해요.
Map<String, String> get currentUserMediaRequestHeaders =>
    authSession.requestHeaders;

final ApiCurrentUserRepository currentUserRepository = ApiCurrentUserRepository(
  api: apiClient,
);
