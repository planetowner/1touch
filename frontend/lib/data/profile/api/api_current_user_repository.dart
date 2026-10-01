import 'package:onetouch/models/profile_change_limit_exception.dart';
import 'dart:convert';

import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/profile/api/api_current_user_mapper.dart';
import 'package:onetouch/data/profile/api/api_current_user_response.dart';
import 'package:onetouch/data/profile/current_user_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/models/current_user_profile.dart';

class ProfileNameConflictException implements Exception {}

/// HTTP implementation of the verified `GET /v1/users/me` contract.
class ApiCurrentUserRepository implements CurrentUserRepository {
  ApiCurrentUserRepository({
    required ApiClient api,
    LocalCacheStore? cacheStore,
  })  : _api = api,
        _cacheStore = cacheStore;

  final ApiClient _api;
  final LocalCacheStore? _cacheStore;

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
    final account = ApiCurrentUserResponse.fromJson(decoded);
    await _cacheStore?.write(
      LocalCacheKeys.currentUser,
      decoded,
      scope: LocalCacheScopes.authenticatedUser,
    );
    return account;
  }

  Future<ApiCurrentUserResponse?> loadCachedAccount() async {
    final record = await _cacheStore?.read(
      LocalCacheKeys.currentUser,
      scope: LocalCacheScopes.authenticatedUser,
    );
    if (record == null) return null;
    try {
      return ApiCurrentUserResponse.fromJson(
        (record.payload as Map).cast<String, dynamic>(),
      );
    } on Object {
      await _cacheStore?.delete(
        LocalCacheKeys.currentUser,
        scope: LocalCacheScopes.authenticatedUser,
      );
      return null;
    }
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
        throw ProfileChangeLimitException.fromJson(detail);
      }
      if (detail == 'Username or nickname is already in use') {
        throw ProfileNameConflictException();
      }
    }
    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    // The endpoint returns the authoritative updated account. Validate and
    // persist it so the next session read cannot revive the pre-edit profile.
    ApiCurrentUserResponse.fromJson(decoded);
    await _cacheStore?.write(
      LocalCacheKeys.currentUser,
      decoded,
      scope: LocalCacheScopes.authenticatedUser,
    );
  }
}
