import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/notifications/api/api_push_device_repository.dart';
import 'package:onetouch/data/notifications/push_device_repository.dart';

const _deviceId = '123e4567-e89b-42d3-a456-426614174000';
const _token = 'firebase-device-token-long-enough';

void main() {
  test('registers an iOS device against the authenticated session', () async {
    final repository = _repository((request) async {
      expect(request.method, 'PUT');
      expect(
        request.url.path,
        '/v1/users/me/push-devices/$_deviceId',
      );
      expect(request.headers['Authorization'], 'Bearer session');
      expect(jsonDecode(request.body), {
        'token': _token,
        'platform': 'ios',
        'locale': 'ko-KR',
      });
      return http.Response('{"ok":true}', 200);
    });

    await repository.register(
      deviceId: _deviceId,
      token: _token,
      platform: PushDevicePlatform.ios,
      locale: 'ko-KR',
    );
  });

  test('unregisters the same persistent device ID', () async {
    final repository = _repository((request) async {
      expect(request.method, 'DELETE');
      expect(request.url.path.endsWith(_deviceId), isTrue);
      return http.Response('{"ok":true}', 200);
    });

    await repository.unregister(_deviceId);
  });

  test('rejects invalid values before making a request', () async {
    var requestCount = 0;
    final repository = _repository((_) async {
      requestCount++;
      return http.Response('{"ok":true}', 200);
    });

    await expectLater(
      repository.register(
        deviceId: 'not-a-uuid',
        token: _token,
        platform: PushDevicePlatform.android,
        locale: 'en',
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.register(
        deviceId: _deviceId,
        token: 'short',
        platform: PushDevicePlatform.android,
        locale: 'en',
      ),
      throwsArgumentError,
    );
    expect(requestCount, 0);
  });
}

ApiPushDeviceRepository _repository(
  Future<http.Response> Function(http.Request request) handler,
) =>
    ApiPushDeviceRepository(
      api: ApiClient(
        client: MockClient(handler),
        baseUri: Uri.parse('https://api.example.com/v1/'),
        requestHeaders: () => const {'Authorization': 'Bearer session'},
      ),
    );
