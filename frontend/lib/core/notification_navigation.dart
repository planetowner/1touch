import 'package:go_router/go_router.dart';
import 'package:onetouch/core/detail_navigation.dart';

/// Keeps a notification destination while the current account is loading.
/// A destination opened under one session must not carry over to another user.
class NotificationNavigation {
  String? _destination;
  String? _sessionToken;

  void open(
    String destination, {
    required GoRouter router,
    required String? sessionToken,
    required bool isSessionReady,
  }) {
    if (!isSupportedDestination(destination) || sessionToken == null) return;
    final currentPath = router.routeInformationProvider.value.uri.path;
    // 앱 준비 중에는 로그인 화면 위로 상세를 쌓지 않고 목적지만 보관해요.
    if (!isSessionReady || currentPath == '/' || currentPath == '/session') {
      queue(destination, sessionToken: sessionToken);
      return;
    }
    pushDetailPage(router, destination);
  }

  void queue(String destination, {required String sessionToken}) {
    if (!isSupportedDestination(destination)) return;
    _destination = destination;
    _sessionToken = sessionToken;
  }

  String? take({required String sessionToken}) {
    final destination = _sessionToken == sessionToken ? _destination : null;
    clear();
    return destination;
  }

  void clear() {
    _destination = null;
    _sessionToken = null;
  }
}

bool isSupportedDestination(String destination) {
  final uri = Uri.tryParse(destination);
  if (uri == null || uri.hasScheme || uri.hasAuthority || uri.hasFragment) {
    return false;
  }
  if (RegExp(r'^/notifications/post/[1-9][0-9]*$').hasMatch(uri.path)) {
    return uri.queryParameters.isEmpty;
  }
  if (!RegExp(r'^/match/[1-9][0-9]*$').hasMatch(uri.path)) return false;
  if (uri.queryParameters.isEmpty) return true;
  return uri.queryParametersAll.length == 1 &&
      uri.queryParametersAll['status']?.length == 1 &&
      const {'upcoming', 'live', 'past'}
          .contains(uri.queryParameters['status']);
}

final notificationNavigation = NotificationNavigation();
