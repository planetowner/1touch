import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/auth/native_social_identity_service.dart';
import 'package:onetouch/data/profile/account_deletion_service.dart';
import 'package:onetouch/data/profile/api/api_account_deletion_service.dart';

final AccountDeletionService accountDeletionService = ApiAccountDeletionService(
  api: apiClient,
  socialIdentityService: NativeSocialIdentityService(),
);
