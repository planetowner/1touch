import 'package:flutter/services.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/data/auth/social_identity_service.dart';

const kakaoNativeAppKey = '25516ea3190521a9be6f2e3e7d696c80';
const lineChannelId = '2011572463';

class NativeSocialIdentityService implements SocialIdentityService {
  Future<void>? _lineInitialization;
  Future<void>? _kakaoInitialization;

  @override
  Future<Map<String, String>> authenticate(LoginProvider provider) async {
    switch (provider) {
      case LoginProvider.kakao:
        _kakaoInitialization ??= KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);
        await _kakaoInitialization;
        try {
          // 카카오톡이 없으면 브라우저에서 같은 카카오계정으로 로그인해요.
          final token = await isKakaoTalkInstalled()
              ? await UserApi.instance.loginWithKakaoTalk()
              : await UserApi.instance.loginWithKakaoAccount();
          return {'access_token': token.accessToken};
        } on KakaoClientException catch (error) {
          if (error.reason == ClientErrorCause.cancelled) {
            throw const SocialLoginCancelled();
          }
          rethrow;
        } on PlatformException catch (error) {
          if (error.code == 'CANCELED') throw const SocialLoginCancelled();
          rethrow;
        }
      case LoginProvider.line:
        _lineInitialization ??= LineSDK.instance.setup(lineChannelId);
        await _lineInitialization;
        try {
          // 서버는 openid 권한의 userinfo에서 검증된 계정 ID만 읽어요.
          final result = await LineSDK.instance.login(scopes: const ['openid']);
          return {'access_token': result.accessToken.value};
        } on PlatformException catch (error) {
          // LINE SDK의 취소 코드는 iOS에서 3003, Android에서 CANCEL이에요.
          if (error.code == '3003' || error.code == 'CANCEL') {
            throw const SocialLoginCancelled();
          }
          rethrow;
        }
      case LoginProvider.apple:
        // 서버가 Apple의 일회용 코드를 교환하고 같은 nonce인지 검증해요.
        final nonce = generateNonce();
        try {
          final credential = await SignInWithApple.getAppleIDCredential(
            scopes: const [],
            nonce: nonce,
          );
          return {
            'code': credential.authorizationCode,
            'client_id': 'com.onetouch.football',
            'nonce': nonce,
          };
        } on SignInWithAppleAuthorizationException catch (error) {
          if (error.code == AuthorizationErrorCode.canceled) {
            throw const SocialLoginCancelled();
          }
          rethrow;
        }
      case LoginProvider.google:
      case LoginProvider.email:
        throw ArgumentError.value(provider, 'provider');
    }
  }
}
