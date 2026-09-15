import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Opens a player profile through the Players branch of the bottom-navigation
/// shell, so the selected navigation item always matches the visible screen.
void openPlayerPage(BuildContext context, String playerId) {
  context.go('/players/${Uri.encodeComponent(playerId)}');
}
