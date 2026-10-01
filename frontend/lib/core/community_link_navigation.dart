/// Keeps an incoming post link through sign-in and session initialization.
/// Authenticated links are tied to the account that originally opened them.
class CommunityLinkNavigation {
  String? _destination;
  String? _sessionToken;

  void queue(String destination, {String? sessionToken}) {
    if (!isCommunityPostDestination(destination)) return;
    _destination = destination;
    _sessionToken = sessionToken;
  }

  String? take({required String sessionToken}) {
    final destination = _sessionToken == null || _sessionToken == sessionToken
        ? _destination
        : null;
    clear();
    return destination;
  }

  void clear() {
    _destination = null;
    _sessionToken = null;
  }
}

bool isCommunityPostDestination(String destination) {
  final uri = Uri.tryParse(destination);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasFragment ||
      uri.hasQuery ||
      uri.pathSegments.length != 2 ||
      uri.pathSegments.first != 'community') {
    return false;
  }
  final rawId = uri.pathSegments.last;
  final postId = int.tryParse(rawId);
  return postId != null && postId > 0 && rawId == '$postId';
}

final communityLinkNavigation = CommunityLinkNavigation();
