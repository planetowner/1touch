/// Keeps a notification destination while the current account is loading.
/// A destination opened under one session must not carry over to another user.
class NotificationNavigation {
  String? _destination;
  String? _sessionToken;

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
