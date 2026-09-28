import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/match_origin_navigation.dart';
import 'package:onetouch/data/teams/team_page_eligibility_provider.dart';

bool isTeamPageSupported(int teamId) => teamPageEligibility.supports(teamId);

String? redirectUnsupportedTeamPath(String? rawTeamId) {
  final teamId = int.tryParse(rawTeamId ?? '');
  return teamId != null && isTeamPageSupported(teamId) ? null : '/home';
}

/// Keeps a source match in the route stack; otherwise opens the Team branch.
bool openTeamPage(BuildContext context, int teamId) {
  if (!isTeamPageSupported(teamId)) return false;
  if (shouldPushFromMatch(context)) {
    context.push('/match-team/$teamId');
  } else {
    context.go('/team/$teamId');
  }
  return true;
}
