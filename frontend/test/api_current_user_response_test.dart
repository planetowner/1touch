import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/profile/api/api_current_user_response.dart';

void main() {
  group('ApiCurrentUserResponse', () {
    test('parses the verified completed-profile fields', () {
      final response = ApiCurrentUserResponse.fromJson(_profileJson());

      expect(response.userId, 1001);
      expect(response.username, 'colin');
      expect(response.firstName, 'Colin');
      expect(response.lastName, 'Sung');
      expect(response.email, 'colin@example.com');
      expect(response.avatarUrl, '/v1/users/1001/avatar');
      expect(response.favoriteTeamId, 8);
      expect(response.createdAt, '2026-09-01T14:00:00Z');
      expect(response.onboardingComplete, isTrue);
    });

    test('preserves legitimate pre-onboarding and social-account nulls', () {
      final response = ApiCurrentUserResponse.fromJson({
        ..._profileJson(),
        'username': null,
        'first_name': null,
        'last_name': null,
        'email': null,
        'avatar_url': null,
        'favorite_team_id': null,
        'onboarding_complete': false,
      });

      expect(response.username, isNull);
      expect(response.firstName, isNull);
      expect(response.lastName, isNull);
      expect(response.email, isNull);
      expect(response.avatarUrl, isNull);
      expect(response.favoriteTeamId, isNull);
      expect(response.onboardingComplete, isFalse);
    });

    test('ignores extra account-state fields from the current endpoint', () {
      final response = ApiCurrentUserResponse.fromJson({
        ..._profileJson(),
        'favorite_changed_at': '2026-09-02T14:00:00Z',
        'suspended_until': null,
      });

      expect(response.userId, 1001);
      expect(response.username, 'colin');
    });

    test('requires every declared field even when its value may be null', () {
      for (final field in [
        'user_id',
        'username',
        'first_name',
        'last_name',
        'email',
        'avatar_url',
        'favorite_team_id',
        'created_at',
        'onboarding_complete',
      ]) {
        final json = _profileJson()..remove(field);

        expect(
          () => ApiCurrentUserResponse.fromJson(json),
          throwsFormatException,
          reason: 'missing $field should be rejected',
        );
      }
    });

    test('rejects malformed declared field values', () {
      for (final malformed in [
        _profileJson()..['user_id'] = '1001',
        _profileJson()..['username'] = 7,
        _profileJson()..['favorite_team_id'] = '8',
        _profileJson()..['created_at'] = 123,
        _profileJson()..['onboarding_complete'] = 'true',
      ]) {
        expect(
          () => ApiCurrentUserResponse.fromJson(malformed),
          throwsFormatException,
        );
      }
    });
  });
}

Map<String, dynamic> _profileJson() {
  return {
    'user_id': 1001,
    'username': 'colin',
    'first_name': 'Colin',
    'last_name': 'Sung',
    'email': 'colin@example.com',
    'avatar_url': '/v1/users/1001/avatar',
    'favorite_team_id': 8,
    'created_at': '2026-09-01T14:00:00Z',
    'onboarding_complete': true,
  };
}
