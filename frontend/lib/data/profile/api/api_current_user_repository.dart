import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onetouch/data/profile/api/api_current_user_mapper.dart';
import 'package:onetouch/data/profile/api/api_current_user_response.dart';
import 'package:onetouch/data/profile/current_user_repository.dart';
import 'package:onetouch/models/current_user_profile.dart';

/// HTTP implementation of the verified `GET /v1/users/me` contract.
class ApiCurrentUserRepository implements CurrentUserRepository {
  ApiCurrentUserRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;

  @override
  Future<CurrentUserProfile> load() async {
    final uri = _apiBaseUri.resolve('users/me');
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Current-user request failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the current-user response to be a JSON object.',
      );
    }
    return currentUserProfileFromApiResponse(
      ApiCurrentUserResponse.fromJson(decoded),
      apiBaseUri: _apiBaseUri,
    );
  }

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
