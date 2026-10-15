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
  const testDeviceId = String.fromEnvironment('ADMOB_TEST_DEVICE_ID');
  late _ConsentInformation information;
  late Completer<FormError?> initialForm;
  late Completer<FormError?> privacyForm;
  late List<MethodCall> adCalls;
  late Completer<void> firstPartyIdDisabled;
  late Completer<bool?> trackingPreparation;
  var privacyFormsShown = 0;
  var trackingPreparations = 0;
  // 플랫폼 응답 Future도 각 위젯 테스트의 가상 시계 안에서 만들어요.
  void installMocks() {
    MobileAdsService.resetForTesting();
    final originalInformation = ConsentInformation.instance;
    information = _ConsentInformation();
    ConsentInformation.instance = information;
    addTearDown(() => ConsentInformation.instance = originalInformation);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final umpChannel = MethodChannel('plugins.flutter.io/google_mobile_ads/ump',
        StandardMethodCodec(UserMessagingCodec()));
    const trackingChannel = MethodChannel('onetouch/tracking_authorization');
    initialForm = Completer<FormError?>();
    privacyForm = Completer<FormError?>();
    adCalls = <MethodCall>[];
    firstPartyIdDisabled = Completer<void>();
    trackingPreparation = Completer<bool?>();
    privacyFormsShown = 0;
    trackingPreparations = 0;
    messenger.setMockMethodCallHandler(trackingChannel, (call) async {
      expectSync(call.method, 'prepareForAds');
      trackingPreparations++;
      return trackingPreparation.future;
    });
    messenger.setMockMethodCallHandler(umpChannel, (call) async {
      switch (call.method) {
        case 'UserMessagingPlatform#loadAndShowConsentFormIfRequired':
          return initialForm.future;
        case 'UserMessagingPlatform#showPrivacyOptionsForm':
          privacyFormsShown++;
          return privacyForm.future;
        default:
          throw StateError('Unexpected UMP call ${call.method}');
      }
    });
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      adCalls.add(call);
      if (call.method == 'MobileAds#setSameAppKeyEnabled') {
        expectSync(call.arguments, {'isEnabled': false});
        await firstPartyIdDisabled.future;
        return null;
      }
      if (call.method == 'MobileAds#initialize') {
        // 실제 광고가 먼저 요청되거나 정식 빌드에 테스트 설정이 섞이지 않는지 확인해요.
        // 플랫폼 콜백에서는 pump()와 충돌하지 않도록 동기 검증을 써요.
        final configurations = adCalls
            .where(
                (call) => call.method == 'MobileAds#updateRequestConfiguration')
            .toList();
        if (testDeviceId.isEmpty) {
          expectSync(configurations, isEmpty);
        } else {
          expectSync(configurations, hasLength(1));
          expectSync(
              configurations.single.arguments['testDeviceIds'], [testDeviceId]);
        }
        expectSync(
            adCalls.where((call) => call.method == 'loadBannerAd'), isEmpty);
        return InitializationStatus({});
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(umpChannel, null);
      messenger.setMockMethodCallHandler(instanceManager.channel, null);
      messenger.setMockMethodCallHandler(trackingChannel, null);
    });
  }

  testWidgets(
      skipConsent
          ? 'debug option loads test ads without requesting consent'
          : 'consent gates ads and privacy changes replace previous requests',
      (tester) async {
    installMocks();
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
      expect(trackingPreparations, 0);
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
    expect(trackingPreparations, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
      'iOS waits for UMP and ATT handling then disables publisher ID before NPA',
      (tester) async {
    installMocks();
    await tester.pumpWidget(const MaterialApp(home: BannerAdWidget()));
    final initialization = MobileAdsService.initialize();
    final concurrentInitialization = MobileAdsService.initialize();
    await tester.pump();
    if (!skipConsent) {
      expect(information.updates, 1);
      expect(adCalls, isEmpty);
      information.allowed = true;
      initialForm.complete(null);
      await tester.pump();
      expect(trackingPreparations, 1);
      expect(adCalls, isEmpty);
      expect(MobileAdsService.adRequestsAllowed.value, isFalse);
      trackingPreparation.complete(true);
      await tester.pump();
    } else {
      expect(information.updates, 0);
    }
    expect(trackingPreparations, skipConsent ? 0 : 1);
    expect(
        adCalls.map((call) => call.method), ['MobileAds#setSameAppKeyEnabled']);
    expect(MobileAdsService.adRequestsAllowed.value, isFalse);

    firstPartyIdDisabled.complete();
    await tester.pumpAndSettle();
    await Future.wait([initialization, concurrentInitialization]);
    expect(MobileAdsService.adRequestsAllowed.value, isTrue);
    expect(adCalls.where((call) => call.method == 'MobileAds#initialize'),
        hasLength(1));
    final loads =
        adCalls.where((call) => call.method == 'loadBannerAd').toList();
    expect(loads, hasLength(1));
    expect(loads.single.arguments['adUnitId'],
        'ca-app-pub-3940256099942544/2435281174');
    expect((loads.single.arguments['request'] as AdRequest).nonPersonalizedAds,
        isTrue);
    await MobileAdsService.initialize();
    expect(trackingPreparations, skipConsent ? 0 : 1);
    expect(
        adCalls
            .where((call) => call.method == 'MobileAds#setSameAppKeyEnabled'),
        hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS does not request ATT or ads without UMP clearance',
      (tester) async {
    installMocks();
    final initialization = MobileAdsService.initialize();
    await tester.pump();
    initialForm
        .complete(FormError(errorCode: 2, message: 'Network unavailable'));
    await tester.pumpAndSettle();
    await initialization;
    expect(trackingPreparations, 0);
    expect(adCalls, isEmpty);
    expect(MobileAdsService.adRequestsAllowed.value, isFalse);
  },
      skip: skipConsent,
      variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final result in ['unresolved', 'missing result', 'platform error']) {
    testWidgets('iOS keeps app usable without ads on ATT $result',
        (tester) async {
      installMocks();
      await tester.pumpWidget(const MaterialApp(
        home: Column(children: [Text('App content'), BannerAdWidget()]),
      ));
      final initialization = MobileAdsService.initialize();
      await tester.pump();
      information.allowed = true;
      initialForm.complete(null);
      await tester.pump();
      expect(trackingPreparations, 1);
      if (result == 'platform error') {
        trackingPreparation.completeError(PlatformException(code: 'failed'));
      } else {
        trackingPreparation.complete(result == 'unresolved' ? false : null);
      }
      await tester.pumpAndSettle();
      await initialization;
      expect(adCalls, isEmpty);
      expect(MobileAdsService.adRequestsAllowed.value, isFalse);
      expect(find.text('App content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        skip: skipConsent,
        variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets(
      'iOS rechecks ATT after privacy changes even with SDK initialized',
      (tester) async {
    installMocks();
    await tester.pumpWidget(const MaterialApp(home: BannerAdWidget()));
    final initialization = MobileAdsService.initialize();
    information.allowed = true;
    initialForm.complete(null);
    // 네이티브의 ATT 건너뛰기·허용·거절·제한은 모두 광고 준비 완료로 전달돼요.
    trackingPreparation.complete(true);
    firstPartyIdDisabled.complete();
    await tester.pumpAndSettle();
    await initialization;
    final firstLoad =
        adCalls.singleWhere((call) => call.method == 'loadBannerAd');

    trackingPreparation = Completer<bool?>();
    final change = MobileAdsService.showPrivacyOptions();
    await tester.pump();
    expect(MobileAdsService.adRequestsAllowed.value, isFalse);
    expect(adCalls.where((call) => call.method == 'disposeAd').last.arguments,
        {'adId': firstLoad.arguments['adId']});
    privacyForm.complete(null);
    await tester.pump();
    expect(trackingPreparations, 2);
    expect(
        adCalls.where((call) => call.method == 'loadBannerAd'), hasLength(1));
    trackingPreparation.complete(true);
    await tester.pumpAndSettle();
    expect(await change, isTrue);
    expect(adCalls.where((call) => call.method == 'MobileAds#initialize'),
        hasLength(1));
    expect(
        adCalls
            .where((call) => call.method == 'MobileAds#setSameAppKeyEnabled'),
        hasLength(1));
    final loads =
        adCalls.where((call) => call.method == 'loadBannerAd').toList();
    expect(loads, hasLength(2));
    expect((loads.last.arguments['request'] as AdRequest).nonPersonalizedAds,
        isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  },
      skip: skipConsent,
      variant: TargetPlatformVariant.only(TargetPlatform.iOS));
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
