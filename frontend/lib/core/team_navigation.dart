import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/data/teams/team_page_eligibility_provider.dart';

bool isTeamPageSupported(int teamId) => teamPageEligibility.supports(teamId);

String? redirectUnsupportedTeamPath(String? rawTeamId) {
  final teamId = int.tryParse(rawTeamId ?? '');
  return teamId != null && isTeamPageSupported(teamId) ? null : '/home';
}

/// Opens a team profile through the Team branch of the bottom-navigation
/// shell, so the selected navigation item always matches the visible screen.
bool openTeamPage(BuildContext context, int teamId) {
  if (!isTeamPageSupported(teamId)) return false;
  context.go('/team/$teamId');
  return true;
}
