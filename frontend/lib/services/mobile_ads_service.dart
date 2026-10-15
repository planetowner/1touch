import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:onetouch/config/ad_config.dart';

abstract final class MobileAdsService {
  static bool _isInitialized = false;
  static Future<void>? _initialization;
  static bool _showingPrivacyOptions = false;
  static const _trackingChannel =
      MethodChannel('onetouch/tracking_authorization');
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
      // 디버그에서 공식 테스트 광고를 확인할 때만 동의 절차를 건너뛸 수 있어요.
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
    // 개인정보 선택을 나중에 바꿔도 최신 UMP 동의에 맞춰 ATT 필요 여부를 확인해요.
    // 기기 정보 접근 동의가 없으면 ATT를 건너뛰고, ATT 거절·제한도 존중해요.
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await _trackingChannel.invokeMethod<bool>('prepareForAds') != true) {
      _adRequestsAllowed.value = false;
      debugPrint('Advertising deferred: ATT authorization is unresolved.');
      return;
    }
    await _initializeAds();
  }

  static Future<void> _initializeAds() async {
    if (!_isInitialized) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // 현재 광고 운영 방침에 따라 ATT 허용 여부와 별개로 게시자 자체 식별자를 꺼요.
        // Flutter의 Same App Key는 iOS SDK의 Publisher first-party ID 설정이에요.
        await MobileAds.instance.setSameAppKeyEnabled(false);
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
