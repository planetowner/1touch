import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/community/community_identity.dart';

void main() {
  test('formats a community identity from the username', () {
    expect(
      communityUsernameLabel(
        username: ' planetowner ',
        authorDeleted: false,
      ),
      '@planetowner',
    );
  });

  test('does not expose an identity for a deleted author', () {
    expect(
      communityUsernameLabel(
        username: 'planetowner',
        authorDeleted: true,
      ),
      'Deleted user',
    );
  });

  test('handles an unexpectedly missing username', () {
    expect(
      communityUsernameLabel(
        username: null,
        authorDeleted: false,
      ),
      'Unknown user',
    );
  });
}
