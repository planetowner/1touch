import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/profile/api/api_profile_avatar_repository.dart';
import 'package:onetouch/data/profile/profile_avatar_repository.dart';

final ProfileAvatarRepository profileAvatarRepository =
    ApiProfileAvatarRepository(
  api: apiClient,
);
