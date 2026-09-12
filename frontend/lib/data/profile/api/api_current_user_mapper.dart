import 'package:onetouch/data/profile/api/api_current_user_response.dart';
import 'package:onetouch/models/current_user_profile.dart';

CurrentUserProfile currentUserProfileFromApiResponse(
  ApiCurrentUserResponse response, {
  required Uri apiBaseUri,
}) {
  if (!response.onboardingComplete) {
    throw StateError('Current user has not completed onboarding.');
  }

  final createdAt = DateTime.tryParse(response.createdAt);
  if (createdAt == null || !createdAt.isUtc) {
    throw FormatException(
      'Expected created_at to include a UTC offset: ${response.createdAt}',
    );
  }

  return CurrentUserProfile(
    userId: response.userId,
    username: _requiredCompletedField(response.username, 'username'),
    firstName: _requiredCompletedField(response.firstName, 'first_name'),
    lastName: _requiredCompletedField(response.lastName, 'last_name'),
    email: response.email,
    avatarUri: _avatarUri(response.avatarUrl, apiBaseUri),
    favoriteTeamId: _requiredCompletedField(
      response.favoriteTeamId,
      'favorite_team_id',
    ),
    createdAt: createdAt.toUtc(),
  );
}

T _requiredCompletedField<T>(T? value, String fieldName) {
  if (value == null) {
    throw StateError('Completed profile requires $fieldName.');
  }
  return value;
}

Uri? _avatarUri(String? value, Uri apiBaseUri) {
  if (value == null) return null;

  final parsed = Uri.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid avatar_url: $value');
  }
  final resolved = parsed.isAbsolute ? parsed : apiBaseUri.resolveUri(parsed);
  if ((resolved.scheme != 'http' && resolved.scheme != 'https') ||
      resolved.host.isEmpty) {
    throw FormatException('Invalid avatar_url: $value');
  }
  return resolved;
}
