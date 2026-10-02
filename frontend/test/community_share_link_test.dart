import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/community_link_navigation.dart';
import 'package:onetouch/features/community/community_post_share_link.dart';

void main() {
  test('share URL uses the public post path', () {
    expect(communityPostShareUri(12).toString(),
        'https://1touch.football/community/12');
    expect(() => communityPostShareUri(0), throwsArgumentError);
  });

  test('only positive post IDs can be queued', () {
    final navigation = CommunityLinkNavigation();
    for (final path in [
      '/community/0',
      '/community/-1',
      '/community/12/extra',
      '/community/12?foo=bar',
      'https://1touch.football/community/12',
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
