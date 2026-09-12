import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/profile/api/api_current_user_mapper.dart';
import 'package:onetouch/data/profile/api/api_current_user_response.dart';

void main() {
  group('currentUserProfileFromApiResponse', () {
    test('maps a completed profile into the stable domain model', () {
      final profile = currentUserProfileFromApiResponse(
        _response(),
        apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
      );

      expect(profile.userId, 1);
      expect(profile.username, 'planetowner');
      expect(profile.firstName, 'Planet');
      expect(profile.lastName, 'Owner');
      expect(profile.displayName, 'Planet Owner');
      expect(profile.email, 'owner@example.com');
      expect(
        profile.avatarUri,
        Uri.parse('https://api.1touch.football/v1/users/1/avatar'),
      );
      expect(profile.favoriteTeamId, 83);
      expect(profile.createdAt, DateTime.utc(2026, 9, 1, 14));
    });

    test('preserves nullable optional fields and an absolute avatar URI', () {
      final profile = currentUserProfileFromApiResponse(
        _response(
          email: null,
          avatarUrl: 'https://cdn.example/avatar.png',
        ),
        apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
      );

      expect(profile.email, isNull);
      expect(profile.avatarUri, Uri.parse('https://cdn.example/avatar.png'));

      final profileWithoutAvatar = currentUserProfileFromApiResponse(
        _response(email: null, avatarUrl: null),
        apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
      );
      expect(profileWithoutAvatar.avatarUri, isNull);
    });

    test('rejects a user who has not completed onboarding', () {
      expect(
        () => currentUserProfileFromApiResponse(
          _response(onboardingComplete: false),
          apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
        ),
        throwsStateError,
      );
    });

    test('requires completed-profile identity and favorite-team fields', () {
      for (final response in [
        _response(username: null),
        _response(firstName: null),
        _response(lastName: null),
        _response(favoriteTeamId: null),
      ]) {
        expect(
          () => currentUserProfileFromApiResponse(
            response,
            apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
          ),
          throwsStateError,
        );
      }
    });

    test('rejects ambiguous timestamps and invalid avatar URIs', () {
      expect(
        () => currentUserProfileFromApiResponse(
          _response(createdAt: '2026-09-01 14:00:00'),
          apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
        ),
        throwsFormatException,
      );
      expect(
        () => currentUserProfileFromApiResponse(
          _response(avatarUrl: 'file:///tmp/avatar.png'),
          apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
        ),
        throwsFormatException,
      );
    });
  });
}

ApiCurrentUserResponse _response({
  bool onboardingComplete = true,
  String? username = 'planetowner',
  String? firstName = 'Planet',
  String? lastName = 'Owner',
  String? email = 'owner@example.com',
  String? avatarUrl = '/v1/users/1/avatar',
  int? favoriteTeamId = 83,
  String createdAt = '2026-09-01T14:00:00Z',
}) {
  return ApiCurrentUserResponse(
    userId: 1,
    username: username,
    firstName: firstName,
    lastName: lastName,
    email: email,
    avatarUrl: avatarUrl,
    favoriteTeamId: favoriteTeamId,
    createdAt: createdAt,
    onboardingComplete: onboardingComplete,
  );
}
