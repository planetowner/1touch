import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Opens a team profile through the Team branch of the bottom-navigation
/// shell, so the selected navigation item always matches the visible screen.
void openTeamPage(BuildContext context, int teamId) {
  context.go('/team/$teamId');
}
