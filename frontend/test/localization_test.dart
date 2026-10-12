import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/onboarding.dart';
import 'package:onetouch/SignComps/other_login_methods.dart';
import 'package:onetouch/SignComps/sign_in.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/probability_display.dart';
import 'package:onetouch/data/auth/api/api_login_options_repository.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/features/community/community_identity.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/date_labels.dart';
import 'package:onetouch/l10n/messages.dart';

void main() {
  test('APP_LOCALE overrides supported languages and allows system fallback',
      () {
    expect(appLocaleOverride(''), isNull);
    expect(appLocaleOverride('system'), isNull);
    expect(appLocaleOverride('ko'), const Locale('ko'));
    expect(appLocaleOverride('ja-JP'), const Locale('ja'));
    expect(appLocaleOverride('zh_Hant'), appSupportedLocales.last);
    expect(() => appLocaleOverride('fr'), throwsFormatException);
  });

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

  test('betting copy reuses dynamic team and point translations', () {
    expect(
      translateMessage(const Locale('ko'), '{team} Win', {'team': 'CAS'}),
      'CAS 승',
    );
    expect(
      translateMessage(const Locale('ja'), '{team} Win', {'team': 'CEU'}),
      'CEU 勝利',
    );
    expect(
      translateMessage(const Locale('zh'), '{team} Win', {'team': 'CEU'}),
      'CEU 胜',
    );
    for (final locale in appSupportedLocales) {
      expect(
          translateMessage(locale, '{points} pts', {'points': 120}), '120 pts');
      expect(
          translateMessage(
              locale,
              'You used {stake} pts · {return} pts if correct',
              {'stake': 100, 'return': 400}),
          allOf(contains('100 pts'), contains('400 pts')));
      expect(
        translateMessage(locale, '{points} points returned.', {'points': 100}),
        contains('100'),
      );
    }
    expect(
      translateMessage(const Locale('ko'), 'You can use up to {points} pts!',
          {'points': '1,200'}),
      '최대 1,200 pts를 쓸 수 있어요',
    );
    for (final key in ['PTS', 'Pts']) {
      expect(
        appSupportedLocales.map((locale) => translateMessage(locale, key)),
        [key, '승점', '勝点', '积分'],
      );
    }
    expect(
      appSupportedLocales.map((locale) =>
          translateMessage(locale, '{points} Pts', {'points': 120})),
      ['120 Pts', '승점 120', '勝点120', '120积分'],
    );
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
    withClock(Clock.fixed(DateTime(2026, 9, 20)), () {
      expect(fixtureDateLabel(kickoff, locale: const Locale('ko')),
          '9월 23일 (수)\n오후 3:30');
    });
    expect(fixtureDateLabel(null, locale: const Locale('ja')), '日程未定');
    expect(fixtureDateLabel(null, locale: const Locale('zh')), '日期待定');
  });

  test('fixture dates use today and tomorrow in all supported languages', () {
    withClock(Clock.fixed(DateTime(2026, 10, 10, 12)), () {
      for (final (day, expected) in [
        (10, ['Today', '오늘', '今日', '今天']),
        (11, ['Tomorrow', '내일', '明日', '明天']),
      ]) {
        expect(
          appSupportedLocales.map((locale) =>
              fixtureDateLabel(DateTime(2026, 10, day, 11, 30), locale: locale)
                  .split('\n')
                  .first),
          expected,
        );
      }
      for (final (day, label) in [
        (9, '10월 9일 (금)'),
        (10, '오늘'),
        (11, '내일'),
        (12, '10월 12일 (월)'),
        (17, '10월 17일 (토)'),
      ]) {
        expect(
          fixtureDateLabel(DateTime(2026, 10, day, 11, 30),
              locale: const Locale('ko')),
          '$label\n오전 11:30',
        );
      }
    });
  });

  test('fixture dates use local calendar days across midnight and DST', () {
    for (final (now, kickoff, expected) in [
      (DateTime(2026, 10, 10, 0, 1), DateTime(2026, 10, 10, 23, 59), '오늘'),
      (DateTime(2026, 10, 10, 23, 59), DateTime(2026, 10, 11, 0, 1), '내일'),
      (DateTime(2026, 10, 10, 23, 59), DateTime(2026, 10, 12), '10월 12일 (월)'),
      (DateTime(2026, 12, 31, 23, 59), DateTime(2027, 1, 1), '내일'),
      (DateTime(2026, 3, 8), DateTime(2026, 3, 9), '내일'),
      (DateTime(2026, 11, 1), DateTime(2026, 11, 2), '내일'),
    ]) {
      withClock(Clock.fixed(now.toUtc()), () {
        expect(
          fixtureDateLabel(kickoff.toUtc(), locale: const Locale('ko'))
              .split('\n')
              .first,
          expected,
        );
      });
    }
  });

  test('all Korean probability titles stay on one line', () {
    const expected = {
      'Chances to Win\nLeague Trophy': '리그 우승 확률',
      'Chances to Win\nUCL Trophy': 'UCL 우승 확률',
      'Chances to Win\nUEL Trophy': 'UEL 우승 확률',
      'Chances to Win\nUECL Trophy': 'UECL 우승 확률',
      'Chances to Finish\nTop 4': '4위 이내 진입 확률',
      'Chances to Finish\nTop 6': '6위 이내 진입 확률',
      'Chances of\nRelegation': '강등 확률',
      'Chances to\nRelegation Playoff': '강등 플레이오프 확률',
    };
    expect(probabilityEventTitle('relegation_playoff'),
        'Chances to\nRelegation Playoff');
    expect(
        translateMessage(const Locale('ko'), 'relegation playoff probability'),
        '강등 플레이오프 확률');
    for (final entry in expected.entries) {
      final translated = translateMessage(const Locale('ko'), entry.key);
      expect(translated, entry.value);
      expect(translated, isNot(contains('\n')));
    }
  });

  testWidgets(
      'English display casing shares keys without changing translations',
      (tester) async {
    for (final locale in appSupportedLocales) {
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: Builder(builder: (context) {
          final english = locale.languageCode == 'en';
          expect(tr(context, 'Following Teams'),
              translateMessage(locale, 'Following Teams'));
          expect(
            trUpper(context, 'Following Teams'),
            english
                ? 'FOLLOWING TEAMS'
                : translateMessage(locale, 'Following Teams'),
          );
          expect(
            trTitle(context, 'See all'),
            english ? 'See All' : translateMessage(locale, 'See all'),
          );
          expect(
            trUpper(context, 'XG TABLE'),
            translateMessage(locale, 'XG TABLE'),
          );
          expect(
            appStatLabel(context, 'Key passes'),
            english ? 'Key Passes' : translateMessage(locale, 'Key passes'),
          );
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpAndSettle();
    }
  });

  test('past fixtures switch from days to weeks in all supported languages',
      () {
    final now = DateTime(2026, 9, 24, 12);
    final cases = <int, List<String>>{
      0: ['Today', '오늘', '今日', '今天'],
      1: ['Yesterday', '어제', '昨日', '昨天'],
      2: ['2 days ago', '2일 전', '2日前', '2天前'],
      6: ['6 days ago', '6일 전', '6日前', '6天前'],
      7: ['Last week', '지난주', '先週', '上周'],
      13: ['Last week', '지난주', '先週', '上周'],
      14: ['2 weeks ago', '2주 전', '2週間前', '2周前'],
      35: ['5 weeks ago', '5주 전', '5週間前', '5周前'],
      365: ['52 weeks ago', '52주 전', '52週間前', '52周前'],
    };
    for (final entry in cases.entries) {
      final kickoff = DateTime(now.year, now.month, now.day - entry.key, 9);
      expect(
        appSupportedLocales.map(
            (locale) => relativeDateLabel(kickoff, locale: locale, now: now)),
        entry.value,
        reason: '${entry.key} calendar days ago',
      );
    }
  });

  test('content uses minutes and hours today, then calendar days and weeks',
      () {
    final now = DateTime(2026, 9, 24, 12);
    final cases = <DateTime, List<String>>{
      DateTime(2026, 9, 24, 11, 59): ['1m ago', '1분 전', '1分前', '1分钟前'],
      DateTime(2026, 9, 24, 11, 1): ['59m ago', '59분 전', '59分前', '59分钟前'],
      DateTime(2026, 9, 24, 11): ['1h ago', '1시간 전', '1時間前', '1小时前'],
      DateTime(2026, 9, 24, 10): ['2h ago', '2시간 전', '2時間前', '2小时前'],
      DateTime(2026, 9, 23, 23, 59): ['Yesterday', '어제', '昨日', '昨天'],
      DateTime(2026, 9, 22): ['2 days ago', '2일 전', '2日前', '2天前'],
      DateTime(2026, 9, 17): ['Last week', '지난주', '先週', '上周'],
      DateTime(2026, 8, 20): ['5 weeks ago', '5주 전', '5週間前', '5周前'],
    };
    for (final entry in cases.entries) {
      expect(
        appSupportedLocales.map((locale) => relativeDateLabel(entry.key,
            locale: locale, now: now, showTimeToday: true)),
        entry.value,
      );
    }
  });

  test('past fixtures use local calendar dates across midnight and DST', () {
    final cases = [
      (DateTime(2026, 1, 1, 0, 1), DateTime(2025, 12, 31, 23, 59)),
      (DateTime(2026, 3, 9), DateTime(2026, 3, 8)),
    ];
    for (final (now, kickoff) in cases) {
      expect(
          relativeDateLabel(kickoff.toUtc(),
              locale: const Locale('en'), now: now.toUtc()),
          'Yesterday');
    }
    expect(relativeDateLabel(null, locale: const Locale('ko')), '날짜 미정');
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

  test('signup guides and errors use the requested copy with all translations',
      () {
    const messages = {
      'Use 1–30 characters with English letters, numbers, _ or .':
          '영문, 숫자, _, .으로 1~30자를 입력해 주세요.',
      'Use 4–12 characters with Korean syllables, English letters, or numbers. Korean syllables count as 2.':
          '한글, 영문, 숫자로 4~12자를 입력해 주세요. 한글은 2자로 세요.',
      'Use 8–128 characters with at least one uppercase letter, one lowercase letter, and one number.':
          '영문 대문자·소문자·숫자를 모두 포함해 8~128자로 입력해 주세요.',
      'Use only English letters, numbers, _ or .': '영문, 숫자, _, .만 사용할 수 있어요.',
      'Use 1–30 characters.': '1~30자로 입력해 주세요.',
      "Periods can't be first, last, or consecutive.":
          '점(.)은 맨 앞·뒤나 연속해서 쓸 수 없어요.',
      'Use only Korean syllables, English letters, and numbers.':
          '한글, 영문, 숫자만 사용할 수 있어요.',
      'Use 4–12 characters. Korean syllables count as 2 each.':
          '4~12자로 입력해 주세요. 한글은 2자로 세요.',
      'Use complete Korean syllables, like 가.': "한글은 '가'처럼 완성된 글자로 입력해 주세요.",
      'Use 8–128 characters.': '8~128자로 입력해 주세요.',
      'Include at least one uppercase letter, one lowercase letter, and one number.':
          '영문 대문자·소문자·숫자를 모두 포함해 주세요.',
      'That ID is already taken. Try another one.':
          '이미 사용 중인 아이디예요. 다른 아이디를 입력해 주세요.',
      'That nickname is already taken. Try another one.':
          '이미 사용 중인 닉네임이에요. 다른 닉네임을 입력해 주세요.',
      "The passwords don't match. Please check again.":
          '비밀번호가 서로 달라요. 다시 확인해 주세요.',
    };
    for (final entry in messages.entries) {
      expect(translateMessage(const Locale('ko'), entry.key), entry.value);
      expect(translateMessage(const Locale('en'), entry.key), entry.key);
      for (final language in ['ja', 'zh']) {
        expect(translateMessage(Locale(language), entry.key), isNot(entry.key));
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
          communityAuthorLabel(
              username: 'Goals',
              authorDeleted: false,
              locale: Locale(entry.key)),
          '@Goals');
    }
    expect(
        communityAuthorLabel(
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
      final router = _loginRouter(() async => const LoginOptions(
            recommended: [
              LoginProvider.kakao,
              LoginProvider.apple,
              LoginProvider.google,
              LoginProvider.email
            ],
            other: [LoginProvider.line],
          ));
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
        locale: locale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
      ));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('kakao-sign-in-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('line-sign-in-button')), findsNothing);
      final otherMethods = find.byKey(const ValueKey('other-login-methods'));
      expect(otherMethods, findsOneWidget);
      await tester.ensureVisible(otherMethods);
      await tester.tap(otherMethods);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('line-sign-in-button')), findsOneWidget);
      await tester
          .ensureVisible(find.byKey(const ValueKey('line-sign-in-button')));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('other-login-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('line-sign-in-button')), findsNothing);
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
    testWidgets(
        'English UI uses server login choices for $region without sending a country',
        (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      final first =
          switch (region) { 'KR' => 'kakao', 'JP' => 'line', _ => 'google' };
      final recommended = [
        if (region != 'US') first,
        'google',
        'apple',
        'email',
      ];
      final other = switch (region) {
        'KR' => ['line'],
        'JP' => ['kakao'],
        _ => ['kakao', 'line'],
      };
      final repository = ApiLoginOptionsRepository(
          api: ApiClient(
        baseUri: Uri.parse('https://api.example.test/v1/'),
        requestHeaders: () => {},
        client: MockClient((request) async {
          expect(request.url.path, '/v1/auth/providers');
          expect(request.url.queryParameters, {'platform': 'ios'});
          return http.Response(
              jsonEncode({
                'providers': recommended,
                'other_providers': other,
              }),
              200);
        }),
      ));
      final router = _loginRouter(() async => repository.load(platform: 'ios'));
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        localeListResolutionCallback: resolveAppLocale,
      ));
      await tester.pumpAndSettle();
      final provider = LoginProvider.values.byName(first);
      expect(find.byKey(ValueKey('${provider.name}-sign-in-button')),
          findsOneWidget);
      for (final name in other) {
        expect(find.byKey(ValueKey('$name-sign-in-button')), findsNothing);
      }
      final otherMethods = find.byKey(const ValueKey('other-login-methods'));
      await tester.ensureVisible(otherMethods);
      await tester.tap(otherMethods);
      await tester.pumpAndSettle();
      for (final name in other) {
        expect(find.byKey(ValueKey('$name-sign-in-button')), findsOneWidget);
      }
      expect(find.byKey(ValueKey('$first-sign-in-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('email-sign-in-button')), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('Android US login keeps Apple hidden and offers regional methods',
      (tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final repository = ApiLoginOptionsRepository(
      api: ApiClient(
        baseUri: Uri.parse('https://api.example.test/v1/'),
        requestHeaders: () => {},
        client: MockClient((request) async {
          expect(request.url.queryParameters, {'platform': 'android'});
          return http.Response(
              jsonEncode({
                'providers': ['google', 'email'],
                'other_providers': ['kakao', 'line'],
              }),
              200);
        }),
      ),
    );
    final router = _loginRouter(() async => repository.load(
          platform: 'android',
        ));
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('apple-sign-in-button')), findsNothing);
    final otherMethods = find.byKey(const ValueKey('other-login-methods'));
    await tester.ensureVisible(otherMethods);
    await tester.tap(otherMethods);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kakao-sign-in-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('line-sign-in-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

GoRouter _loginRouter(Future<LoginOptions> Function() loadOptions) => GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => OnboardingScreen(loadOptions: loadOptions),
        ),
        GoRoute(
          path: '/auth/other-methods',
          builder: (_, state) => OtherLoginMethodsScreen(
            initialOptions: state.extra as LoginOptions?,
          ),
        ),
      ],
    );
