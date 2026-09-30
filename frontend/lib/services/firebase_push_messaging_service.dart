import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

abstract interface class PushTokenProvider {
  String? get currentToken;
  Stream<String> get onTokenRefresh;
  Future<String?> tokenIfAuthorized();
  Future<String?> requestPermissionAndGetToken();
}

class FirebasePushMessagingService implements PushTokenProvider {
  FirebasePushMessagingService({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _currentToken;

  @override
  String? get currentToken => _currentToken;

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (!_isSupported || _tokenRefreshSubscription != null) return;
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      (token) => _currentToken = token,
      onError: (Object error) {
        debugPrint('Unable to refresh the FCM token: $error');
      },
    );

    _currentToken = await tokenIfAuthorized();
  }

  @override
  Future<String?> tokenIfAuthorized() async {
    if (!_isSupported) return null;
    final settings = await _messaging.getNotificationSettings();
    if (!_canReceiveNotifications(settings.authorizationStatus)) return null;
    return _currentToken = await _readToken(waitForApns: false);
  }

  @override
  Future<String?> requestPermissionAndGetToken() async {
    if (!_isSupported) return null;
    await initialize();
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    if (!_canReceiveNotifications(settings.authorizationStatus)) return null;
    return _currentToken = await _readToken(waitForApns: true);
  }

  bool _canReceiveNotifications(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  Future<String?> _readToken({required bool waitForApns}) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      var apnsToken = await _messaging.getAPNSToken();
      if (waitForApns) {
        for (var attempt = 0; attempt < 10 && apnsToken == null; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          apnsToken = await _messaging.getAPNSToken();
        }
      }
      if (apnsToken == null) return null;
    }
    return _messaging.getToken();
  }
}

final firebasePushMessagingService = FirebasePushMessagingService();
