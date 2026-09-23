import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/team_overview/api/api_team_overview_repository.dart';
import 'package:onetouch/data/team_overview/team_overview_repository.dart';

final TeamOverviewRepository teamOverviewRepository = ApiTeamOverviewRepository(
  api: apiClient,
);
