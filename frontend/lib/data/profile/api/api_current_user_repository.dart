import 'dart:convert';

import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/profile/api/api_current_user_mapper.dart';
import 'package:onetouch/data/profile/api/api_current_user_response.dart';
import 'package:onetouch/data/profile/current_user_repository.dart';
import 'package:onetouch/models/current_user_profile.dart';

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
      required String firstName,
      required String lastName}) async {
    final response = await _api.put(_api.baseUri.resolve('users/me/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'first_name': firstName,
          'last_name': lastName
        }));
    _api.decodeJson<Map<String, dynamic>>(response);
  }
}
