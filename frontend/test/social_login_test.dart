import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/auth/api/api_google_auth_repository.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/data/auth/native_social_identity_service.dart';
import 'package:onetouch/data/auth/social_identity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final provider in [
    LoginProvider.kakao,
    LoginProvider.line,
    LoginProvider.apple
  ]) {
    for (final accepted in [true, false]) {
      test(
          '$provider establishes a session only after a successful server exchange ($accepted)',
          () async {
        final credentials = provider == LoginProvider.apple
            ? {
                'code': 'single-use-code',
                'client_id': 'com.onetouch.football',
                'nonce': 'nonce'
              }
            : {'access_token': 'provider-token'};
        final session = AuthSession();
        final service = AuthService(
          googleIdentityService: _UnusedGoogle(),
          socialIdentityService: _Identity((requested) async {
            expect(requested, provider);
            expect(session.isAuthenticated, isFalse);
            return credentials;
          }),
          repository: ApiGoogleAuthRepository(
              api: ApiClient(
            baseUri: Uri.parse('https://api.example.test/v1/'),
            requestHeaders: () => {},
            client: MockClient((request) async {
              expect(request.url.path, '/v1/auth/${provider.name}');
              expect(request.method, 'POST');
              expect(jsonDecode(request.body), credentials);
              expect(session.isAuthenticated, isFalse);
              return accepted
                  ? http.Response(
                      '{"access_token":"backend-token","token_type":"bearer"}',
                      200)
                  : http.Response('{"detail":"Invalid token"}', 401);
            }),
          )),
          session: session,
        );
        if (accepted) {
          await service.signInWithProvider(provider);
          expect(session.requestHeaders,
              {'Authorization': 'Bearer backend-token'});
        } else {
          await expectLater(
              service.signInWithProvider(provider), throwsException);
          expect(session.isAuthenticated, isFalse);
        }
      });
    }
  }
  for (final code in ['3003', 'CANCEL']) {
    test('LINE native cancellation $code is a silent user cancellation',
        () async {
      var setups = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(LineSDK.channel, (call) async {
        if (call.method == 'setup') {
          expect(call.arguments['channelId'], '2011572463');
          setups++;
          return null;
        }
        if (call.method == 'login') {
          expect(call.arguments['scopes'], ['openid']);
          throw PlatformException(code: code);
        }
        throw StateError('Unexpected method ${call.method}');
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(LineSDK.channel, null));
      final identity = NativeSocialIdentityService();
      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(identity.authenticate(LoginProvider.line),
            throwsA(isA<SocialLoginCancelled>()));
      }
      expect(setups, 1);
    });
  }
}

class _Identity implements SocialIdentityService {
  _Identity(this.signIn);
  final Future<Map<String, String>> Function(LoginProvider) signIn;
  @override
  Future<Map<String, String>> authenticate(LoginProvider provider) =>
      signIn(provider);
}

class _UnusedGoogle implements GoogleIdentityService {
  @override
  Future<String> authenticate() => throw UnimplementedError();
}
