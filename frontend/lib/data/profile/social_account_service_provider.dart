import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/auth/google/google_sign_in_identity_service.dart';
import 'package:onetouch/data/auth/native_social_identity_service.dart';
import 'package:onetouch/data/profile/social_account_service.dart';

final socialAccountService = SocialAccountService(
  api: apiClient,
  googleIdentityService: GoogleSignInIdentityService(),
  socialIdentityService: NativeSocialIdentityService(),
);
