import 'dart:convert';

import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/data/auth/social_identity_service.dart';

/// 공급자 인증 결과를 현재 로그인한 1touch 계정에 연결해요. 로그인 세션은 바꾸지 않아요.
class SocialAccountService {
  const SocialAccountService({
    required this.api,
    required this.googleIdentityService,
    required this.socialIdentityService,
  });

  final ApiClient api;
  final GoogleIdentityService googleIdentityService;
  final SocialIdentityService socialIdentityService;

  Future<Set<String>> connect(LoginProvider provider) async {
    if (provider != LoginProvider.google && provider != LoginProvider.apple) {
      throw ArgumentError.value(provider, 'provider');
    }
    // Google은 ID 토큰, Apple은 일회용 코드·클라이언트 ID·nonce를 서버에 전달해요.
    final credentials = provider == LoginProvider.google
        ? {'id_token': await googleIdentityService.authenticate()}
        : await socialIdentityService.authenticate(provider);
    // 로그인 엔드포인트를 호출하면 새 계정으로 전환될 수 있어 현재 세션의 연결 API만 써요.
    final response = await api.put(
      api.baseUri.resolve('users/me/social-accounts/${provider.name}'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(credentials),
    );
    final decoded = api.decodeJson<Map<String, dynamic>>(response);
    // 성공 응답의 전체 연결 목록을 사용해 화면이 서버 상태와 일치하게 해요.
    return (decoded['social_accounts'] as List<dynamic>)
        .map((value) => value as String)
        .toSet();
  }
}
