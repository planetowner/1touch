import 'package:onetouch/models/post.dart';

/// Enable only after 1touch.app serves post pages and app-link verification.
const communityShareLinksEnabled = bool.fromEnvironment(
  'COMMUNITY_SHARE_LINKS_ENABLED',
);

Uri communityPostShareUri(int postId) {
  if (postId < 1) throw ArgumentError.value(postId, 'postId');
  return Uri.https('1touch.app', '/community/$postId');
}

String communityPostShareText(
  Post post, {
  bool includeLink = communityShareLinksEnabled,
}) =>
    includeLink
        ? '${post.title}\n\n${communityPostShareUri(post.postId)}'
        : '${post.title}\n\n${post.body}';
