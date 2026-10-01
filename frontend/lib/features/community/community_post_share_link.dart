import 'package:onetouch/models/post.dart';

/// 1touch.football의 공유 페이지 배포와 앱 연결 검증을 마친 뒤 켜요.
const communityShareLinksEnabled = bool.fromEnvironment(
  'COMMUNITY_SHARE_LINKS_ENABLED',
);

Uri communityPostShareUri(int postId) {
  if (postId < 1) throw ArgumentError.value(postId, 'postId');
  return Uri.https('1touch.football', '/community/$postId');
}

String communityPostShareText(
  Post post, {
  bool includeLink = communityShareLinksEnabled,
}) =>
    includeLink
        ? '${post.title}\n\n${communityPostShareUri(post.postId)}'
        : '${post.title}\n\n${post.body}';
