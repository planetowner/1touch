import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/team_attributes/api/api_team_attribute_repository.dart';
import 'package:onetouch/data/team_attributes/team_attribute_repository.dart';

final TeamAttributeRepository teamAttributeRepository =
    ApiTeamAttributeRepository(
  api: apiClient,
);
