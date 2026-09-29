import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';

typedef _InitializeGoogleSdk = Future<void> Function();
typedef _AuthenticateGoogleSdk = Future<String?> Function();

class GoogleSignInIdentityService implements GoogleIdentityService {
  factory GoogleSignInIdentityService() => _instance;

  @visibleForTesting
  GoogleSignInIdentityService.testing({
    required Future<void> Function() initializeSdk,
    required Future<String?> Function() authenticateIdToken,
  })  : _initializeSdk = initializeSdk,
        _authenticateIdToken = authenticateIdToken;

  static final GoogleSignInIdentityService _instance =
      GoogleSignInIdentityService.testing(
    // 두 플랫폼 모두 운영 서버가 허용한 같은 Web Client ID를 사용해요.
    initializeSdk: () => GoogleSignIn.instance.initialize(
      // iOS SDK는 런타임 서버 ID를 쓰려면 iOS 클라이언트 ID도 함께 받아야 해요.
      clientId: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
          ? '20814259598-q73q31tk4qpc0cv1j08drjiofd854hk6.apps.googleusercontent.com'
          : null,
      serverClientId:
          '20814259598-dsu514vmr01t3cflhn6c8mobiu5pmpft.apps.googleusercontent.com',
    ),
    authenticateIdToken: () async {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    },
  );

  final _InitializeGoogleSdk _initializeSdk;
  final _AuthenticateGoogleSdk _authenticateIdToken;
  Future<void>? _initialization;

  // 로그인과 캘린더 연결이 같은 Google SDK 초기화를 공유해요.
  Future<void> initialize() => _initialization ??= _initializeSdk();

  @override
  Future<String> authenticate() async {
    String? idToken;
    try {
      await initialize();
      idToken = await _authenticateIdToken();
    } on GoogleSignInException catch (error) {
      throw GoogleIdentityException(
        error.code == GoogleSignInExceptionCode.canceled
            ? GoogleIdentityFailureType.cancelled
            : GoogleIdentityFailureType.sdk,
        cause: error,
      );
    } on Object catch (error) {
      throw GoogleIdentityException(
        GoogleIdentityFailureType.sdk,
        cause: error,
      );
    }

    final normalizedIdToken = idToken?.trim();
    if (normalizedIdToken == null || normalizedIdToken.isEmpty) {
      throw const GoogleIdentityException(
        GoogleIdentityFailureType.missingIdToken,
      );
    }
    return normalizedIdToken;
  }
}
