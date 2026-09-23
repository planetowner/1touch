import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/Onboarding.dart';
import 'package:onetouch/SignComps/SignIn.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/device_region.dart';
import 'package:onetouch/data/auth/api/api_login_options_repository.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/features/community/community_identity.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/date_labels.dart';
import 'package:onetouch/l10n/messages.dart';

void main() {
  test('onboarding copy matches the approved four-language wording', () {
    final expected = <String, List<String>>{
      'Continue with Kakao': [
        'Continue with Kakao',
        '카카오로 계속하기',
        'Kakaoで続ける',
        '使用 Kakao 继续'
      ],
      'Email or username': [
        'Email or username',
        '이메일 또는 아이디',
        'メールアドレスまたはユーザー名',
        '邮箱或用户名'
      ],
      'Forgot password?': [
        'Forgot password?',
        '비밀번호를 잊으셨나요?',
        'パスワードをお忘れですか？',
        '忘记密码？'
      ],
      'Sign in': ['Sign in', '로그인', 'ログイン', '登录'],
      'Sign up': ['Sign up', '회원가입', '新規登録', '注册'],
      "Don't have an account?": [
        "Don't have an account?",
        '계정이 없으신가요?',
        'アカウントをお持ちでないですか？',
        '还没有账号？'
      ],
    };
    for (final entry in expected.entries) {
      expect(
          ['en', 'ko', 'ja', 'zh']
              .map((language) => translateMessage(Locale(language), entry.key)),
          entry.value);
    }
  });

  test('preferred language resolves separately from country, including Chinese',
      () {
    for (final entry in {
      const Locale('en', 'KR'): const Locale('en'),
      const Locale('ko', 'US'): const Locale('ko'),
      const Locale('ja', 'KR'): const Locale('ja'),
      const Locale('zh', 'CN'): appSupportedLocales.last,
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'):
          appSupportedLocales.last,
      const Locale('fr', 'KR'): const Locale('en'),
    }.entries) {
      expect(resolveAppLocale([entry.key], appSupportedLocales), entry.value);
    }
    expect(
        resolveAppLocale(
            [const Locale('fr'), const Locale('ja')], appSupportedLocales),
        const Locale('ja'));
  });

  test('fixture dates share locale-aware formatting and missing-date labels',
      () {
    final kickoff = DateTime(2026, 9, 23, 15, 30);
    expect(
        fixtureDateLabel(kickoff, locale: const Locale('ko')), contains('9월'));
    expect(fixtureDateLabel(null, locale: const Locale('ja')), '日程未定');
    expect(fixtureDateLabel(null, locale: const Locale('zh')), '日期待定');
  });

  test('all translations preserve placeholders and contain nonempty text', () {
    Set<String> placeholders(String text) =>
        RegExp(r'\{\w+\}').allMatches(text).map((m) => m[0]!).toSet();
    for (final entry in appMessages.entries) {
      for (final value in [entry.value.ko, entry.value.ja, entry.value.zh]) {
        expect(value.trim(), isNotEmpty, reason: entry.key);
        expect(placeholders(value), placeholders(entry.key), reason: entry.key);
      }
    }
  });

  test(
      'relative times and deleted identities use UI language while usernames stay intact',
      () {
    final now = DateTime.utc(2026, 9, 23, 12);
    for (final entry in {
      'en': '2h ago',
      'ko': '2시간 전',
      'ja': '2時間前',
      'zh': '2小时前'
    }.entries) {
      expect(
          relativeTimeLabel(now.subtract(const Duration(hours: 2)),
              now: now, locale: Locale(entry.key)),
          entry.value);
      expect(
          communityUsernameLabel(
              username: 'Goals',
              authorDeleted: false,
              locale: Locale(entry.key)),
          '@Goals');
    }
    expect(
        communityUsernameLabel(
            username: null, authorDeleted: true, locale: const Locale('ko')),
        '탈퇴한 사용자');
  });

  for (final language in ['en', 'ko', 'ja', 'zh']) {
    testWidgets(
        '$language renders login choices and email form at 320px without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final locale = resolveAppLocale([Locale(language)], appSupportedLocales);
      Widget app(Widget child) => MaterialApp(
            locale: locale,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationDelegates,
            home: child,
          );
      await tester.pumpWidget(app(OnboardingScreen(
          loadOptions: () async => const LoginOptions(
                recommended: [
                  LoginProvider.kakao,
                  LoginProvider.apple,
                  LoginProvider.google,
                  LoginProvider.email
                ],
                other: [LoginProvider.line],
              ))));
      await tester.pumpAndSettle();
      expect(find.text(translateMessage(locale, 'Continue with Kakao')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('line-sign-in-button')), findsNothing);
      expect(find.byKey(const ValueKey('other-login-methods')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app(const EmailSignInScreen()));
      await tester.pumpAndSettle();
      expect(find.text(translateMessage(locale, 'Email or username')),
          findsNWidgets(2));
      expect(find.text(translateMessage(locale, 'Password')), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  for (final region in ['KR', 'JP', 'US']) {
    testWidgets('English UI sends actual $region device region to login API',
        (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceRegion.channel, (_) async => region);
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceRegion.channel, null));
      final first =
          switch (region) { 'KR' => 'kakao', 'JP' => 'line', _ => 'apple' };
      final repository = ApiLoginOptionsRepository(
          api: ApiClient(
        baseUri: Uri.parse('https://api.example.test/v1/'),
        requestHeaders: () => {},
        client: MockClient((request) async {
          expect(request.url.path, '/v1/auth/providers');
          expect(request.url.queryParameters,
              {'platform': 'ios', 'country_code': region});
          return http.Response(
              jsonEncode({
                'providers': [first, 'email'],
                'other_providers': []
              }),
              200);
        }),
      ));
      await tester.pumpWidget(MaterialApp(
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        localeListResolutionCallback: resolveAppLocale,
        home: OnboardingScreen(
            loadOptions: () async => repository.load(
                platform: 'ios',
                country: await const DeviceRegion().readCountryCode())),
      ));
      await tester.pumpAndSettle();
      final provider = LoginProvider.values.byName(first);
      expect(find.text(provider.label), findsOneWidget);
      expect(
          tester.getTopLeft(find.byKey(ValueKey('$first-sign-in-button'))).dy,
          lessThan(tester
              .getTopLeft(find.byKey(const ValueKey('email-sign-in-button')))
              .dy));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
}
