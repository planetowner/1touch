import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Match-linked details stay on the root navigator until the user leaves it.
bool shouldPushFromMatch(BuildContext context) {
  final matches =
      GoRouter.of(context).routerDelegate.currentConfiguration.matches;
  return matches.any((match) {
    final segments = Uri.parse(match.matchedLocation).pathSegments;
    return segments.length == 2 && segments.first == 'match';
  });
}
