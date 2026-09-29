import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/profile/api/api_profile_activity_repository.dart';
import 'package:onetouch/data/profile/profile_activity_repository.dart';

final ProfileActivityRepository profileActivityRepository =
    ApiProfileActivityRepository(api: apiClient);
