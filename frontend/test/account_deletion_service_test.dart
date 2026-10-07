import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/data/auth/social_identity_service.dart';
import 'package:onetouch/data/profile/api/api_account_deletion_service.dart';

void main() {
  test('deletes an email account without provider proof', () async {
    var requests = 0;
    final service = ApiAccountDeletionService(
      api: _api((request) async {
        requests++;
        expect(request.method, 'DELETE');
        expect(request.url.path, '/v1/users/me');
        expect(request.headers['Authorization'], 'Bearer account-token');
        expect(request.body, isEmpty);
        return http.Response('{"ok":true}', 200);
      }),
      socialIdentityService: _Identity(),
    );

    await service.deleteAccount({'email', 'google'});
    expect(requests, 1);
  });

  test('reauthenticates linked providers and sends their proof', () async {
    final identity = _Identity();
    final service = ApiAccountDeletionService(
      api: _api((request) async {
        expect(request.method, 'DELETE');
        expect(request.headers['Content-Type'], 'application/json');
        expect(jsonDecode(request.body), {
          'apple': {'code': 'apple-proof'},
          'kakao': {'access_token': 'kakao-proof'},
          'line': {'access_token': 'line-proof'},
        });
        return http.Response('{"ok":true}', 200);
      }),
      socialIdentityService: identity,
    );

    await service.deleteAccount({'apple', 'kakao', 'line', 'google'});
    expect(identity.authenticated,
        [LoginProvider.apple, LoginProvider.kakao, LoginProvider.line]);
  });

  test('cancelling provider authentication does not send delete', () async {
    var requests = 0;
    final service = ApiAccountDeletionService(
      api: _api((request) async {
        requests++;
        return http.Response('{"ok":true}', 200);
      }),
      socialIdentityService: _Identity(cancelled: true),
    );

    await expectLater(
      service.deleteAccount({'apple'}),
      throwsA(isA<SocialLoginCancelled>()),
    );
    expect(requests, 0);
  });

  test('server error preserves the failed deletion result', () async {
    final service = ApiAccountDeletionService(
      api: _api((_) async => http.Response('{"detail":"provider down"}', 503)),
      socialIdentityService: _Identity(),
    );

    await expectLater(
      service.deleteAccount({}),
      throwsA(isA<http.ClientException>()),
    );
  });
}

ApiClient _api(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      client: MockClient(handler),
      baseUri: Uri.parse('https://api.example.com/v1/'),
      requestHeaders: () => const {'Authorization': 'Bearer account-token'},
    );

class _Identity implements SocialIdentityService {
  _Identity({this.cancelled = false});

  final bool cancelled;
  final List<LoginProvider> authenticated = [];

  @override
  Future<Map<String, String>> authenticate(LoginProvider provider) async {
    authenticated.add(provider);
    if (cancelled) throw const SocialLoginCancelled();
    return provider == LoginProvider.apple
        ? {'code': 'apple-proof'}
        : {'access_token': '${provider.name}-proof'};
  }
}
