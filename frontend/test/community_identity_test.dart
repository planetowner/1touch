import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/community/community_identity.dart';

void main() {
  test('shows the public display name instead of the account ID', () {
    expect(
      communityAuthorLabel(
        username: 'john_doe',
        displayName: '불광동호날두',
        authorDeleted: false,
      ),
      '불광동호날두',
    );
  });

  test('formats a community identity from the username', () {
    expect(
      communityAuthorLabel(
        username: ' planetowner ',
        authorDeleted: false,
      ),
      '@planetowner',
    );
  });

  test('does not expose an identity for a deleted author', () {
    expect(
      communityAuthorLabel(
        username: 'planetowner',
        authorDeleted: true,
      ),
      'Deleted user',
    );
  });

  test('handles an unexpectedly missing username', () {
    expect(
      communityAuthorLabel(
        username: null,
        authorDeleted: false,
      ),
      'Unknown user',
    );
  });
}
