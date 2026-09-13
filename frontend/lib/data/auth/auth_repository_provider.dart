import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/auth/api/api_google_auth_repository.dart';
import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/auth/google/google_sign_in_identity_service.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';

final ApiConfig _apiConfig = ApiConfig.unauthenticatedFromEnvironment();
final http.Client _authHttpClient = http.Client();
final GoogleIdentityService _googleIdentityService =
    GoogleSignInIdentityService();
final AuthRepository _authRepository = ApiGoogleAuthRepository(
  client: _authHttpClient,
  apiBaseUri: _apiConfig.baseUri,
);

final AuthSession authSession = AuthSession();
final AuthService authService = AuthService(
  googleIdentityService: _googleIdentityService,
  repository: _authRepository,
  session: authSession,
);
