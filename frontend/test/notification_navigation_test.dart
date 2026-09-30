import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/notification_navigation.dart';

void main() {
  test('accepts only supported in-app notification routes', () {
    expect(isSupportedDestination('/match/42?status=live'), isTrue);
    expect(isSupportedDestination('/notifications/post/91'), isTrue);
    expect(isSupportedDestination('https://example.com/match/42'), isFalse);
    expect(isSupportedDestination('/match/42?status=invalid'), isFalse);
    expect(isSupportedDestination('/profile/edit'), isFalse);
  });

  test('pending destination belongs to the session that received it', () {
    final navigation = NotificationNavigation();
    navigation.queue('/notifications/post/91', sessionToken: 'first-session');

    expect(navigation.take(sessionToken: 'second-session'), isNull);
    expect(navigation.take(sessionToken: 'first-session'), isNull);
  });
}
