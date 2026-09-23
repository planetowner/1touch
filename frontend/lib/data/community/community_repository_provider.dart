import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/community/api/api_community_repository.dart';
import 'package:onetouch/data/community/community_repository.dart';

final CommunityRepository communityRepository = ApiCommunityRepository(
  api: apiClient,
);
