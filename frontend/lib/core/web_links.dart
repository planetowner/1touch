// 목록의 밑줄 링크와 상세의 카드가 같은 URL 범위를 인식해야 해요.
final _webAddress =
    RegExp(r'(?:https?://|www\.)[^\s<>]+', caseSensitive: false);
final _trailingPunctuation = RegExp(r'[.,!?;:)\]}]+$');

Uri? webUri(String address) {
  final uri = Uri.tryParse(
      address.toLowerCase().startsWith('www.') ? 'https://$address' : address);
  return uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty
      ? uri
      : null;
}

Iterable<(int, int, Uri)> webLinks(String text) sync* {
  for (final match in _webAddress.allMatches(text)) {
    final address = match[0]!.replaceFirst(_trailingPunctuation, '');
    final uri = webUri(address);
    if (uri != null) yield (match.start, match.start + address.length, uri);
  }
}

enum WebLinkKind { website, x, instagram }

WebLinkKind webLinkKind(Uri uri) {
  final host = uri.host.toLowerCase();
  final path = uri.pathSegments.where((part) => part.isNotEmpty).toList();
  if ({
        'x.com',
        'www.x.com',
        'twitter.com',
        'www.twitter.com',
        'mobile.twitter.com'
      }.contains(host) &&
      ((path.length >= 3 && path[1] == 'status') ||
          (path.length >= 4 &&
              path[0] == 'i' &&
              path[1] == 'web' &&
              path[2] == 'status')) &&
      RegExp(r'^\d+$').hasMatch(path[path.indexOf('status') + 1])) {
    return WebLinkKind.x;
  }
  if ({'instagram.com', 'www.instagram.com'}.contains(host) &&
      path.length >= 2 &&
      {'p', 'reel', 'tv'}.contains(path[0]) &&
      RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(path[1])) {
    return WebLinkKind.instagram;
  }
  return WebLinkKind.website;
}

Uri socialPostUri(Uri uri) => switch (webLinkKind(uri)) {
      WebLinkKind.x => Uri.https('x.com',
          '/i/status/${uri.pathSegments[uri.pathSegments.indexOf('status') + 1]}'),
      WebLinkKind.instagram => Uri.https('www.instagram.com',
          '/${uri.pathSegments[0]}/${uri.pathSegments[1]}/'),
      WebLinkKind.website => uri,
    };
