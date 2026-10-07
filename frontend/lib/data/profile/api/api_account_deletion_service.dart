import 'dart:convert';

import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/data/auth/social_identity_service.dart';
import 'package:onetouch/data/profile/account_deletion_service.dart';

class ApiAccountDeletionService implements AccountDeletionService {
  const ApiAccountDeletionService({
    required this.api,
    required this.socialIdentityService,
  });

  final ApiClient api;
  final SocialIdentityService socialIdentityService;

  @override
  Future<void> deleteAccount(Set<String> socialAccounts) async {
    final proof = <String, Map<String, String>>{};
    // 서버가 연결 해제를 요구하는 공급자만 삭제 직전에 다시 인증해요.
    for (final provider in [
      LoginProvider.apple,
      LoginProvider.kakao,
      LoginProvider.line,
    ]) {
      if (socialAccounts.contains(provider.name)) {
        proof[provider.name] =
            await socialIdentityService.authenticate(provider);
      }
    }

    final response = await api.delete(
      api.baseUri.resolve('users/me'),
      headers:
          proof.isEmpty ? null : const {'Content-Type': 'application/json'},
      body: proof.isEmpty ? null : jsonEncode(proof),
    );
    final result = api.decodeJson<Map<String, dynamic>>(response);
    if (result['ok'] != true) {
      throw const FormatException('Account deletion response is invalid.');
    }
  }
}
