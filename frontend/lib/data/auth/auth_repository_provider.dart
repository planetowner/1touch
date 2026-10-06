import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/data/auth/api/api_google_auth_repository.dart';
import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/auth_token_store.dart';
import 'package:onetouch/data/auth/google/google_sign_in_identity_service.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'package:flutter/foundation.dart';
import 'package:onetouch/data/auth/api/api_login_options_repository.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/data/auth/native_social_identity_service.dart';
import 'package:onetouch/data/session/clear_session_data.dart';
import 'package:onetouch/services/push_device_registration_service_provider.dart';

final GoogleIdentityService _googleIdentityService =
    GoogleSignInIdentityService();
final AuthRepository _authRepository = ApiGoogleAuthRepository(
  api: apiClient,
  locale: () => appLocaleController.value.languageCode,
);

final AuthService authService = AuthService(
  googleIdentityService: _googleIdentityService,
  repository: _authRepository,
  session: authSession,
  socialIdentityService: NativeSocialIdentityService(),
  tokenStore: const SecureAuthTokenStore(),
  clearLocalUserData: clearSessionData,
  onSessionEstablished: pushDeviceRegistrationService.synchronize,
  beforeSessionCleared: pushDeviceRegistrationService.unregister,
);

Future<LoginOptions> loadLoginOptions() async {
  final platform = switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => throw UnsupportedError('Login is supported on iOS and Android.'),
  };
  return ApiLoginOptionsRepository(api: apiClient).load(platform: platform);
}
