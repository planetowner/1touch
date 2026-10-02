import 'dart:convert';

import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/data/auth/social_identity_service.dart';

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
    return (decoded['social_accounts'] as List<dynamic>)
        .map((value) => value as String)
        .toSet();
  }
}
