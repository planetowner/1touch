import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onetouch/data/notifications/push_device_id_store.dart';
import 'package:onetouch/data/notifications/push_device_repository.dart';
import 'package:onetouch/services/firebase_push_messaging_service.dart';

class PushDeviceRegistrationService {
  PushDeviceRegistrationService({
    required PushTokenProvider tokenProvider,
    required PushDeviceRepository repository,
    required PushDeviceIdStore deviceIdStore,
    required bool Function() isAuthenticated,
    required String Function() locale,
    required PushDevicePlatform? platform,
    Listenable? localeChanges,
  })  : _tokenProvider = tokenProvider,
        _repository = repository,
        _deviceIdStore = deviceIdStore,
        _isAuthenticated = isAuthenticated,
        _locale = locale,
        _platform = platform,
        _localeChanges = localeChanges;

  final PushTokenProvider _tokenProvider;
  final PushDeviceRepository _repository;
  final PushDeviceIdStore _deviceIdStore;
  final bool Function() _isAuthenticated;
  final String Function() _locale;
  final PushDevicePlatform? _platform;
  final Listenable? _localeChanges;

  StreamSubscription<String>? _tokenSubscription;

  Future<void> start() async {
    if (_platform == null || _tokenSubscription != null) return;
    _tokenSubscription = _tokenProvider.onTokenRefresh.listen(
      (token) => unawaited(_registerSafely(token)),
      onError: (Object error) {
        debugPrint('Unable to observe FCM token updates: $error');
      },
    );
    _localeChanges?.addListener(_handleLocaleChanged);
    await _synchronizeSafely();
  }

  Future<void> requestPermissionAndRegister() async {
    final token = await _tokenProvider.requestPermissionAndGetToken();
    if (token != null) await registerToken(token);
  }

  Future<void> synchronize() async {
    if (!_isAuthenticated() || _platform == null) return;
    final token =
        _tokenProvider.currentToken ?? await _tokenProvider.tokenIfAuthorized();
    if (token != null) await registerToken(token);
  }

  Future<void> registerToken(String token) async {
    final platform = _platform;
    if (!_isAuthenticated() || platform == null) return;
    await _repository.register(
      deviceId: await _deviceIdStore.readOrCreate(),
      token: token,
      platform: platform,
      locale: _locale(),
    );
  }

  Future<void> unregister() async {
    if (!_isAuthenticated()) return;
    final deviceId = await _deviceIdStore.read();
    if (deviceId != null) await _repository.unregister(deviceId);
  }

  void _handleLocaleChanged() => unawaited(_synchronizeSafely());

  Future<void> _synchronizeSafely() async {
    try {
      await synchronize();
    } on Object catch (error) {
      debugPrint('Unable to synchronize the push device: $error');
    }
  }

  Future<void> _registerSafely(String token) async {
    try {
      await registerToken(token);
    } on Object catch (error) {
      debugPrint('Unable to register the refreshed FCM token: $error');
    }
  }
}
