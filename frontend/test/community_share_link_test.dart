import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/community_link_navigation.dart';
import 'package:onetouch/features/community/community_post_share_link.dart';
import 'package:onetouch/models/post.dart';

void main() {
  const post = Post(
    postId: 12,
    teamId: 9,
    userId: 1,
    category: PostCategory.general,
    title: 'Match reaction',
    body: 'Full post text',
    createdAt: '2026-09-27T12:00:00Z',
  );

  test('share URL uses the public post path', () {
    expect(communityPostShareUri(12).toString(),
        'https://1touch.app/community/12');
    expect(() => communityPostShareUri(0), throwsArgumentError);
  });

  test('share respects the public-link build setting', () {
    expect(
      communityPostShareText(post),
      communityShareLinksEnabled
          ? 'Match reaction\n\nhttps://1touch.app/community/12'
          : 'Match reaction\n\nFull post text',
    );
    expect(communityPostShareText(post, includeLink: true),
        'Match reaction\n\nhttps://1touch.app/community/12');
    expect(communityPostShareText(post, includeLink: false),
        'Match reaction\n\nFull post text');
  });

  test('only positive post IDs can be queued', () {
    final navigation = CommunityLinkNavigation();
    for (final path in [
      '/community/0',
      '/community/-1',
      '/community/12/extra',
      '/community/12?foo=bar',
      'https://1touch.app/community/12',
    ]) {
      expect(isCommunityPostDestination(path), isFalse);
      navigation.queue(path);
    }
    expect(navigation.take(sessionToken: 'signed-in'), isNull);
    navigation.queue('/community/12');
    expect(navigation.take(sessionToken: 'signed-in'), '/community/12');
  });

  test('an authenticated link does not cross accounts', () {
    final navigation = CommunityLinkNavigation();
    navigation.queue('/community/12', sessionToken: 'account-a');
    expect(navigation.take(sessionToken: 'account-b'), isNull);
    navigation.queue('/community/12', sessionToken: 'account-a');
    expect(navigation.take(sessionToken: 'account-a'), '/community/12');
    expect(navigation.take(sessionToken: 'account-a'), isNull);
  });
}
