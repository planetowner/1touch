import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

abstract final class MobileAdsService {
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

    await (_initialization ??= _initializeWithConsent());
  }

  static Future<void> _initializeWithConsent() async {
    try {
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
    if (!_isInitialized) {
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
}
