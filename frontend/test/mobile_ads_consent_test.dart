// SDK의 실제 메시지 형식으로 초기화·광고 요청 순서를 확인해요.
// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';
import 'package:onetouch/comm_pages/Profile_settings/about.dart';
import 'package:onetouch/services/mobile_ads_service.dart';
import 'package:onetouch/widgets/ads/banner_ad_widget.dart';

void main() {
  const skipConsent = bool.fromEnvironment('SKIP_AD_CONSENT');
  testWidgets(
      skipConsent
          ? 'debug option loads test ads without requesting consent'
          : 'consent gates ads and privacy changes replace previous requests',
      (tester) async {
    final originalInformation = ConsentInformation.instance;
    final information = _ConsentInformation();
    ConsentInformation.instance = information;
    addTearDown(() => ConsentInformation.instance = originalInformation);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final umpChannel = MethodChannel('plugins.flutter.io/google_mobile_ads/ump',
        StandardMethodCodec(UserMessagingCodec()));
    final initialForm = Completer<FormError?>();
    Completer<FormError?>? privacyForm;
    final adCalls = <MethodCall>[];
    var privacyFormsShown = 0;
    messenger.setMockMethodCallHandler(umpChannel, (call) async {
      switch (call.method) {
        case 'UserMessagingPlatform#loadAndShowConsentFormIfRequired':
          return initialForm.future;
        case 'UserMessagingPlatform#showPrivacyOptionsForm':
          privacyFormsShown++;
          return privacyForm!.future;
        default:
          throw StateError('Unexpected UMP call ${call.method}');
      }
    });
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      adCalls.add(call);
      if (call.method == 'MobileAds#initialize') {
        return InitializationStatus({});
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(umpChannel, null);
      messenger.setMockMethodCallHandler(instanceManager.channel, null);
    });

    await tester.pumpWidget(const MaterialApp(
      home: Column(children: [Expanded(child: AboutPage()), BannerAdWidget()]),
    ));
    expect(find.text('Ad privacy choices'), findsNothing);
    final initialization = MobileAdsService.initialize();
    await tester.pump();
    if (skipConsent) {
      expect(information.updates, 0);
      await initialization;
      await MobileAdsService.initialize();
      expect(MobileAdsService.adRequestsAllowed.value, isTrue);
      expect(MobileAdsService.privacyOptionsRequired.value, isFalse);
      expect(find.text('Ad privacy choices'), findsNothing);
      expect(await MobileAdsService.showPrivacyOptions(), isFalse);
      expect(privacyFormsShown, 0);
      expect(adCalls.where((call) => call.method == 'MobileAds#initialize'),
          hasLength(1));
      final loads =
          adCalls.where((call) => call.method == 'loadBannerAd').toList();
      expect(loads, hasLength(1));
      expect(loads.single.arguments['adUnitId'],
          'ca-app-pub-3940256099942544/9214589741');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
      return;
    }
    expect(information.updates, 1);
    expect(adCalls, isEmpty);
    expect(MobileAdsService.adRequestsAllowed.value, isFalse);

    initialForm
        .complete(FormError(errorCode: 2, message: 'Network unavailable'));
    await tester.pumpAndSettle();
    await initialization;
    expect(adCalls, isEmpty);
    expect(find.text('Ad privacy choices'), findsOneWidget);
    await MobileAdsService.initialize();
    expect(information.updates, 1);

    privacyForm = Completer<FormError?>();
    final options = find.text('Ad privacy choices');
    await tester.ensureVisible(options);
    await tester.tap(options);
    await tester.pump();
    expect(privacyFormsShown, 1);
    expect(adCalls, isEmpty);
    expect(await MobileAdsService.showPrivacyOptions(), isFalse);
    expect(privacyFormsShown, 1);

    information.allowed = true;
    privacyForm.complete(null);
    await tester.pumpAndSettle();
    expect(MobileAdsService.adRequestsAllowed.value, isTrue);
    expect(adCalls.where((call) => call.method == 'MobileAds#initialize'),
        hasLength(1));
    var loads = adCalls.where((call) => call.method == 'loadBannerAd').toList();
    expect(loads, hasLength(1));
    expect((loads.single.arguments['request'] as AdRequest).nonPersonalizedAds,
        isTrue);
    final firstAdId = loads.single.arguments['adId'];

    privacyForm = Completer<FormError?>();
    await tester.tap(options);
    await tester.pump();
    expect(MobileAdsService.adRequestsAllowed.value, isFalse);
    expect(adCalls.where((call) => call.method == 'disposeAd').last.arguments,
        {'adId': firstAdId});
    information.allowed = false;
    privacyForm.complete(null);
    await tester.pumpAndSettle();
    expect(MobileAdsService.adRequestsAllowed.value, isFalse);
    expect(
        adCalls.where((call) => call.method == 'loadBannerAd'), hasLength(1));

    privacyForm = Completer<FormError?>();
    await tester.tap(options);
    await tester.pump();
    privacyForm
        .complete(FormError(errorCode: 2, message: 'Network unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to open ad privacy choices. Please try again.'),
        findsOneWidget);
    expect(MobileAdsService.adRequestsAllowed.value, isFalse);

    privacyForm = Completer<FormError?>();
    await tester.tap(options);
    await tester.pump();
    information.allowed = true;
    information.optionsRequired = false;
    privacyForm.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Ad privacy choices'), findsNothing);
    expect(adCalls.where((call) => call.method == 'MobileAds#initialize'),
        hasLength(1));
    loads = adCalls.where((call) => call.method == 'loadBannerAd').toList();
    expect(loads, hasLength(2));
    expect(loads.last.arguments['adId'], isNot(firstAdId));
    expect((loads.last.arguments['request'] as AdRequest).nonPersonalizedAds,
        isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

class _ConsentInformation implements ConsentInformation {
  bool allowed = false;
  bool optionsRequired = true;
  int updates = 0;

  @override
  void requestConsentInfoUpdate(
      ConsentRequestParameters params,
      OnConsentInfoUpdateSuccessListener successListener,
      OnConsentInfoUpdateFailureListener failureListener) {
    updates++;
    // 이용자의 나이를 확인한 것처럼 SDK에 전달하지 않아요.
    expect(params.tagForUnderAgeOfConsent, isNull);
    successListener();
  }

  @override
  Future<bool> canRequestAds() async => allowed;

  @override
  Future<PrivacyOptionsRequirementStatus>
      getPrivacyOptionsRequirementStatus() async => optionsRequired
          ? PrivacyOptionsRequirementStatus.required
          : PrivacyOptionsRequirementStatus.notRequired;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
