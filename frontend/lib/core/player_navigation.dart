import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/match_origin_navigation.dart';

/// Keeps a source match in the route stack; otherwise opens the Players branch.
void openPlayerPage(BuildContext context, String playerId) {
  final location = playerPageLocation(context, playerId);
  if (shouldPushFromMatch(context)) {
    context.push(location);
  } else {
    context.go(location);
  }
}

String playerPageLocation(BuildContext context, String playerId) {
  final encodedId = Uri.encodeComponent(playerId);
  return shouldPushFromMatch(context)
      ? '/match-player/$encodedId'
      : '/players/$encodedId';
}
