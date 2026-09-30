import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/data/notifications/push_device_repository.dart';
import 'package:onetouch/data/notifications/push_device_repository_provider.dart';
import 'package:onetouch/services/firebase_push_messaging_service.dart';
import 'package:onetouch/services/push_device_registration_service.dart';

final PushDeviceRegistrationService pushDeviceRegistrationService =
    PushDeviceRegistrationService(
  tokenProvider: firebasePushMessagingService,
  repository: pushDeviceRepository,
  deviceIdStore: pushDeviceIdStore,
  isAuthenticated: () => authSession.isAuthenticated,
  locale: () => appLocaleController.value.toLanguageTag(),
  platform: switch (defaultTargetPlatform) {
    TargetPlatform.android => PushDevicePlatform.android,
    TargetPlatform.iOS => PushDevicePlatform.ios,
    _ => null,
  },
  localeChanges: appLocaleController,
);
