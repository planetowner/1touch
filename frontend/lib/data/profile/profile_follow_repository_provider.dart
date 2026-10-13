import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/profile/api/api_profile_follow_repository.dart';
import 'package:onetouch/data/profile/profile_follow_repository.dart';

final ProfileFollowRepository profileFollowRepository =
    ApiProfileFollowRepository(api: apiClient);
