import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/auth/api/api_google_auth_repository.dart';
import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/google/google_sign_in_identity_service.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'package:flutter/foundation.dart';
import 'package:onetouch/core/device_region.dart';
import 'package:onetouch/data/auth/api/api_login_options_repository.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/data/auth/native_social_identity_service.dart';

final GoogleIdentityService _googleIdentityService =
    GoogleSignInIdentityService();
final AuthRepository _authRepository = ApiGoogleAuthRepository(
  api: apiClient,
);

final AuthService authService = AuthService(
  googleIdentityService: _googleIdentityService,
  repository: _authRepository,
  session: authSession,
  socialIdentityService: NativeSocialIdentityService(),
);

Future<LoginOptions> loadLoginOptions() async {
  final platform = switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => throw UnsupportedError('Login is supported on iOS and Android.'),
  };
  final country = await const DeviceRegion().readCountryCode();
  return ApiLoginOptionsRepository(api: apiClient)
      .load(platform: platform, country: country);
}
