import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/notifications/push_device_id_store.dart';
import 'package:onetouch/data/notifications/push_device_repository.dart';
import 'package:onetouch/services/firebase_push_messaging_service.dart';
import 'package:onetouch/services/push_device_registration_service.dart';

const _deviceId = '123e4567-e89b-42d3-a456-426614174000';
const _token = 'firebase-device-token-long-enough';

void main() {
  test('registers an authorized token when an authenticated session starts',
      () async {
    final tokens = _FakeTokenProvider(currentToken: _token);
    final repository = _FakePushDeviceRepository();
    final service = _service(tokens: tokens, repository: repository);

    await service.start();

    expect(repository.registrations.single, (
      deviceId: _deviceId,
      token: _token,
      platform: PushDevicePlatform.ios,
      locale: 'ko-KR',
    ));
    await tokens.close();
  });

  test('registers after permission and whenever Firebase refreshes the token',
      () async {
    final tokens = _FakeTokenProvider(permissionToken: _token);
    final repository = _FakePushDeviceRepository();
    final service = _service(tokens: tokens, repository: repository);
    await service.start();

    await service.requestPermissionAndRegister();
    tokens.emit('refreshed-firebase-device-token');
    await Future<void>.delayed(Duration.zero);

    expect(repository.registrations.map((entry) => entry.token), [
      _token,
      'refreshed-firebase-device-token',
    ]);
    await tokens.close();
  });

  test('unregisters the existing device before session teardown', () async {
    final repository = _FakePushDeviceRepository();
    final service = _service(
      tokens: _FakeTokenProvider(),
      repository: repository,
    );

    await service.unregister();

    expect(repository.unregisteredDeviceIds, [_deviceId]);
  });
}

PushDeviceRegistrationService _service({
  required _FakeTokenProvider tokens,
  required _FakePushDeviceRepository repository,
}) =>
    PushDeviceRegistrationService(
      tokenProvider: tokens,
      repository: repository,
      deviceIdStore: _FakePushDeviceIdStore(),
      isAuthenticated: () => true,
      locale: () => 'ko-KR',
      platform: PushDevicePlatform.ios,
    );

class _FakeTokenProvider implements PushTokenProvider {
  _FakeTokenProvider({this.currentToken, this.permissionToken});

  final StreamController<String> _refreshes = StreamController.broadcast();

  @override
  String? currentToken;
  String? permissionToken;

  @override
  Stream<String> get onTokenRefresh => _refreshes.stream;

  @override
  Future<String?> requestPermissionAndGetToken() async => permissionToken;

  @override
  Future<String?> tokenIfAuthorized() async => currentToken;

  void emit(String token) => _refreshes.add(token);

  Future<void> close() => _refreshes.close();
}

class _FakePushDeviceIdStore implements PushDeviceIdStore {
  @override
  Future<String?> read() async => _deviceId;

  @override
  Future<String> readOrCreate() async => _deviceId;
}

class _FakePushDeviceRepository implements PushDeviceRepository {
  final List<
      ({
        String deviceId,
        String token,
        PushDevicePlatform platform,
        String locale,
      })> registrations = [];
  final List<String> unregisteredDeviceIds = [];

  @override
  Future<void> register({
    required String deviceId,
    required String token,
    required PushDevicePlatform platform,
    required String locale,
  }) async {
    registrations.add((
      deviceId: deviceId,
      token: token,
      platform: platform,
      locale: locale,
    ));
  }

  @override
  Future<void> unregister(String deviceId) async {
    unregisteredDeviceIds.add(deviceId);
  }
}
