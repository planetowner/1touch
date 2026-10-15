import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:onetouch/config/ad_config.dart';

abstract final class MobileAdsService {
  static const _trackingChannel =
      MethodChannel('onetouch/tracking_authorization');
  static bool _isInitialized = false;
  static Future<void>? _initialization;
  static bool _showingPrivacyOptions = false;
  static final _adRequestsAllowed = ValueNotifier(false);
  static final _privacyOptionsRequired = ValueNotifier(false);

  static ValueListenable<bool> get adRequestsAllowed => _adRequestsAllowed;
  static ValueListenable<bool> get privacyOptionsRequired =>
      _privacyOptionsRequired;

  static Future<void> initialize() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    await (_initialization ??= _initialize());
  }

  static Future<void> _initialize() async {
    try {
      // 디버그에서는 공식 테스트 광고로 UMP 동의 양식만 건너뛸 수 있어요.
      if (kDebugMode && const bool.fromEnvironment('SKIP_AD_CONSENT')) {
        await _initializeAds();
        return;
      }

      final update = Completer<FormError?>();
      // 앱을 시작할 때마다 UMP가 동의의 유효성을 확인해요. 별도 동의 캐시는 두지 않아요.
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => update.complete(null),
        update.complete,
      );
      final error = await update.future;
      if (error == null) {
        await ConsentForm.loadAndShowConsentFormIfRequired(_logFormError);
      } else {
        _logFormError(error);
      }
      // 갱신이 실패해도 이전 동의를 사용할 수 있는지는 UMP가 판단해요.
      await _refreshConsentState();
    } on MissingPluginException catch (error) {
      debugPrint('Advertising privacy plugin is not registered: $error');
    } on PlatformException catch (error) {
      debugPrint('Advertising privacy initialization failed: $error');
    }
  }

  static Future<void> _refreshConsentState() async {
    final information = ConsentInformation.instance;
    _privacyOptionsRequired.value =
        await information.getPrivacyOptionsRequirementStatus() ==
            PrivacyOptionsRequirementStatus.required;
    if (!await information.canRequestAds()) {
      _adRequestsAllowed.value = false;
      return;
    }
    await _initializeAds();
  }

  static Future<void> _initializeAds() async {
    if (!_isInitialized) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // UMP 동의와 ATT는 별개예요. OS의 응답이 끝나기 전에는 SDK도 시작하지 않아요.
        final status =
            await _trackingChannel.invokeMethod<int>('requestAuthorization');
        // iOS 상태값: 0 미결정, 1 제한, 2 거부, 3 허용. 미결정은 동의 완료가 아니에요.
        if (status != 1 && status != 2 && status != 3) {
          debugPrint('Advertising deferred: ATT authorization is unresolved.');
          return;
        }
        // 제한·거부 시에도 앱은 이용할 수 있고, Google SDK는 IDFA 없이 광고를 요청해요.
      }
      // 첫 광고 요청부터 테스트 모드가 적용되도록 SDK 초기화 전에 등록해요.
      if (AdConfig.testDeviceId.isNotEmpty) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: [AdConfig.testDeviceId]),
        );
      }
      await MobileAds.instance.initialize();
      _isInitialized = true;
    }
    _adRequestsAllowed.value = true;
  }

  static Future<bool> showPrivacyOptions() async {
    if (_showingPrivacyOptions || !_privacyOptionsRequired.value) return false;
    _showingPrivacyOptions = true;
    // 변경 전 동의로 불러온 광고를 지우고, 닫은 뒤 새 선택에 맞춰 다시 요청해요.
    _adRequestsAllowed.value = false;
    try {
      FormError? formError;
      await ConsentForm.showPrivacyOptionsForm((error) {
        formError = error;
        _logFormError(error);
      });
      await _refreshConsentState();
      return formError == null;
    } on MissingPluginException catch (error) {
      debugPrint('Advertising privacy plugin is not registered: $error');
      return false;
    } on PlatformException catch (error) {
      debugPrint('Unable to update advertising privacy choices: $error');
      return false;
    } finally {
      _showingPrivacyOptions = false;
    }
  }

  static void _logFormError(FormError? error) {
    if (error != null) {
      debugPrint(
          'Advertising privacy error ${error.errorCode}: ${error.message}');
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _isInitialized = false;
    _initialization = null;
    _showingPrivacyOptions = false;
    _adRequestsAllowed.value = false;
    _privacyOptionsRequired.value = false;
  }
}
