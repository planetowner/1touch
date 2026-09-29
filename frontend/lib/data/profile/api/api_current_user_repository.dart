import 'dart:convert';

import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/profile/api/api_current_user_mapper.dart';
import 'package:onetouch/data/profile/api/api_current_user_response.dart';
import 'package:onetouch/data/profile/current_user_repository.dart';
import 'package:onetouch/models/current_user_profile.dart';

class ProfileChangeLimitException implements Exception {
  const ProfileChangeLimitException(this.availableAt);
  final DateTime availableAt;
}

class ProfileNameConflictException implements Exception {}

/// HTTP implementation of the verified `GET /v1/users/me` contract.
class ApiCurrentUserRepository implements CurrentUserRepository {
  ApiCurrentUserRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<CurrentUserProfile> load() async {
    return currentUserProfileFromApiResponse(await loadAccount(),
        apiBaseUri: _api.baseUri);
  }

  Future<ApiCurrentUserResponse> loadAccount() async {
    final uri = _api.baseUri.resolve('users/me');
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    return ApiCurrentUserResponse.fromJson(decoded);
  }

  Future<void> updateProfile(
      {required String username,
      required String displayName,
      required String firstName,
      required String lastName}) async {
    final response = await _api.put(_api.baseUri.resolve('users/me/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'display_name': displayName,
          'first_name': firstName,
          'last_name': lastName
        }));
    if (response.statusCode == 409) {
      final body =
          _api.decodeJson<Map<String, dynamic>>(response, expectedStatus: 409);
      final detail = body['detail'];
      if (detail is Map<String, dynamic> && detail['available_at'] is String) {
        final availableAt = DateTime.tryParse(detail['available_at'] as String);
        if (availableAt != null) {
          throw ProfileChangeLimitException(availableAt.toUtc());
        }
      }
      if (detail == 'Username or nickname is already in use') {
        throw ProfileNameConflictException();
      }
    }
    _api.decodeJson<Map<String, dynamic>>(response);
  }
}
