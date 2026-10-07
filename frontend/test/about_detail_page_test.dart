import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/SignComps/sign_up.dart';
import 'package:onetouch/comm_pages/Profile_settings/about_detail_page.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/main.dart' show profileAboutRoute;

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final locale in [const Locale('en'), const Locale('ko')]) {
      for (final isDark in [false, true]) {
        testWidgets('About detail fits $size, $locale, dark=$isDark',
            (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(MaterialApp(
            locale: locale,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationDelegates,
            theme: lightThemeForLocale(locale),
            darkTheme: darkThemeForLocale(locale),
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            home: const AboutDetailPage(section: AboutSection.terms),
          ));

          expect(
              find.text(
                  locale.languageCode == 'ko' ? '이용약관' : 'Terms of Service'),
              findsOneWidget);
          expect(find.text(locale.languageCode == 'ko' ? '목차' : 'Contents'),
              findsOneWidget);
          expect(
              find.byKey(const ValueKey('about-detail-search')), findsNothing);
          expect(find.byType(BottomNavigationBar), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('About list opens each placeholder page', (tester) async {
    final router = _router('/profile/about');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    for (final section in AboutSection.values) {
      await tester.tap(find.text(section.titleKey));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('about-detail-page')), findsOneWidget);
      expect(find.text(section.titleKey), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/profile/about');
      expect(
          tester.widget<AboutDetailPage>(find.byType(AboutDetailPage)).section,
          section);
      expect(find.byKey(const ValueKey('about-detail-search')), findsOneWidget);
      expect(find.byKey(const ValueKey('main-bottom-navigation-content')),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('about-detail-back')));
      await tester.pumpAndSettle();
      expect(find.text(section.titleKey), findsOneWidget);
    }
  });

  testWidgets('signed-in detail search and bottom tabs navigate',
      (tester) async {
    final router = _router('/profile/about');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Legal'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('about-detail-search')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-page')), findsOneWidget);
    router.go('/profile/about');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Legal'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-page')), findsOneWidget);
  });

  testWidgets('contents link scrolls to its section', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(
      home: AboutDetailPage(section: AboutSection.terms),
    ));
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, 0);

    await tester.tap(find.byKey(const ValueKey('about-content-link-1')));
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign up links open documents and keep consent on return',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = _router('/auth/signup');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      theme: whitetheme,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
    ));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    for (final section in [AboutSection.terms, AboutSection.privacy]) {
      await _tapConsentLink(tester, section.titleKey);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('about-detail-page')), findsOneWidget);
      expect(find.byKey(const ValueKey('about-detail-search')), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byKey(const ValueKey('main-bottom-navigation-content')),
          findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    }
    expect(tester.takeException(), isNull);
  });
}

GoRouter _router(String initialLocation) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  return GoRouter(
    initialLocation: initialLocation,
    navigatorKey: rootNavigatorKey,
    routes: [
      GoRoute(
        path: '/auth/signup',
        builder: (context, state) => const EmailSignUpScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const Scaffold(),
      ),
      profileAboutRoute(navigatorKey: rootNavigatorKey),
      GoRoute(
        path: '/about/:section',
        builder: (context, state) => AboutDetailPage(
          section: AboutSection.fromPath(state.pathParameters['section'])!,
        ),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) =>
            const Scaffold(key: ValueKey('search-page')),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(key: ValueKey('home-page')),
      ),
    ],
  );
}

Future<void> _tapConsentLink(WidgetTester tester, String label) async {
  final consent = find.byKey(const ValueKey('signup-consent-text'));
  await tester.ensureVisible(consent);
  final text = tester.widget<Text>(consent).textSpan!.toPlainText();
  final start = text.indexOf(label);
  expect(start, greaterThanOrEqualTo(0));
  final richText =
      find.descendant(of: consent, matching: find.byType(RichText));
  final paragraph = tester.renderObject<RenderParagraph>(richText);
  final box = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + label.length),
      )
      .first;
  await tester.tapAt(tester.getTopLeft(richText) + box.toRect().center);
}
