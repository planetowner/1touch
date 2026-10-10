import 'package:flutter/widgets.dart';
import 'package:onetouch/core/detail_navigation.dart';
import 'package:onetouch/data/teams/team_page_eligibility_provider.dart';

bool isTeamPageSupported(int teamId) => teamPageEligibility.supports(teamId);

String? redirectUnsupportedTeamPath(String? rawTeamId) {
  final teamId = int.tryParse(rawTeamId ?? '');
  return teamId != null && isTeamPageSupported(teamId) ? null : '/home';
}

bool openTeamPage(BuildContext context, int teamId) {
  if (!isTeamPageSupported(teamId)) return false;
  openDetailPage(context, '/team/$teamId');
  return true;
}
