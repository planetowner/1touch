import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/auth/api/api_google_auth_repository.dart';
import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/google/google_sign_in_identity_service.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';

final GoogleIdentityService _googleIdentityService =
    GoogleSignInIdentityService();
final AuthRepository _authRepository = ApiGoogleAuthRepository(
  api: apiClient,
);

final AuthService authService = AuthService(
  googleIdentityService: _googleIdentityService,
  repository: _authRepository,
  session: authSession,
);
