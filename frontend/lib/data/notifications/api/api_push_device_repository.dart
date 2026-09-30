import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/notifications/push_device_repository.dart';

class ApiPushDeviceRepository implements PushDeviceRepository {
  ApiPushDeviceRepository({required ApiClient api}) : _api = api;

  static final RegExp _deviceIdPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _localePattern = RegExp(
    r'^[a-zA-Z]{2,3}([-_][a-zA-Z0-9]{2,8}){0,2}$',
  );

  final ApiClient _api;

  @override
  Future<void> register({
    required String deviceId,
    required String token,
    required PushDevicePlatform platform,
    required String locale,
  }) async {
    _validateDeviceId(deviceId);
    final normalizedToken = token.trim();
    final normalizedLocale = locale.trim();
    if (normalizedToken.length < 20 || normalizedToken.length > 4096) {
      throw ArgumentError.value(
        token,
        'token',
        'Must contain between 20 and 4096 characters',
      );
    }
    if (!_localePattern.hasMatch(normalizedLocale)) {
      throw ArgumentError.value(locale, 'locale', 'Must be a language tag');
    }
    final response = await _api.put(
      _api.baseUri.resolve('users/me/push-devices/$deviceId'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': normalizedToken,
        'platform': platform.apiValue,
        'locale': normalizedLocale,
      }),
    );
    _expectOk(response);
  }

  @override
  Future<void> unregister(String deviceId) async {
    _validateDeviceId(deviceId);
    final response = await _api.delete(
      _api.baseUri.resolve('users/me/push-devices/$deviceId'),
    );
    _expectOk(response);
  }

  void _expectOk(http.Response response) {
    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    if (decoded['ok'] != true) {
      throw const FormatException('Expected push-device response ok=true.');
    }
  }

  void _validateDeviceId(String deviceId) {
    if (!_deviceIdPattern.hasMatch(deviceId)) {
      throw ArgumentError.value(deviceId, 'deviceId', 'Must be a UUID');
    }
  }
}
