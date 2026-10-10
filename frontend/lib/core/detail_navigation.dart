import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// 탭 안에 쌓으면 검색 같은 루트 화면에 가려져서, 상세는 루트에 열어요.
GoRoute detailRoute({
  required GlobalKey<NavigatorState> rootNavigatorKey,
  required String path,
  required GoRouterPageBuilder pageBuilder,
  GoRouterRedirect? redirect,
}) =>
    GoRoute(
      path: path,
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: pageBuilder,
      redirect: redirect,
    );

/// 진입 화면을 남겨 뒤로 가면 같은 화면과 상태로 돌아가요.
void openDetailPage(
  BuildContext context,
  String location, {
  bool dismissSheet = false,
}) {
  final router = GoRouter.of(context);
  // 경기 기록 팝업은 닫되, 팝업을 열었던 화면은 그대로 남겨요.
  if (dismissSheet) Navigator.of(context).pop();
  pushDetailPage(router, location);
}

/// 화면 밖에서 받은 알림도 같은 이동 기록에 쌓아 원래 화면을 남겨요.
void pushDetailPage(GoRouter router, String location) {
  router.push(location);
}
