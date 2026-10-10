import 'package:flutter/widgets.dart';
import 'package:onetouch/core/detail_navigation.dart';

void openPlayerPage(
  BuildContext context,
  String playerId, {
  bool dismissSheet = false,
}) =>
    openDetailPage(
      context,
      '/players/${Uri.encodeComponent(playerId)}',
      dismissSheet: dismissSheet,
    );
