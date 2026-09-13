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
    initializeSdk: GoogleSignIn.instance.initialize,
    authenticateIdToken: () async {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    },
  );

  final _InitializeGoogleSdk _initializeSdk;
  final _AuthenticateGoogleSdk _authenticateIdToken;
  Future<void>? _initialization;

  @override
  Future<String> authenticate() async {
    String? idToken;
    try {
      await (_initialization ??= _initializeSdk());
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
