import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/app_rule_notice.dart';
import 'package:onetouch/core/app_snack_bar.dart';
import 'package:onetouch/core/style.dart' as app_style;

void main() {
  setUpAll(() async {
    await (FontLoader('Archivo')
          ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf')))
        .load();
  });

  for (final width in [320.0, 430.0]) {
    for (final theme in [app_style.whitetheme, app_style.darktheme]) {
      testWidgets(
          'snack bar matches the rule notice at $width in ${theme.brightness}',
          (tester) async {
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(bottom: 34);
        tester.view.viewPadding = const FakeViewPadding(bottom: 34);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);

        final heights = <double>[];
        for (final message in ['Short notice.', 'First line.\nSecond line.']) {
          late BuildContext context;
          await tester.pumpWidget(MaterialApp(
            theme: theme,
            home: Builder(builder: (value) {
              context = value;
              return Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: AppRuleNotice(
                    key: const ValueKey('reference-notice'),
                    message: message,
                    onClose: () {},
                  ),
                ),
              );
            }),
          ));
          showAppSnackBar(context, message);
          await tester.pumpAndSettle();

          final snackBar = find.byType(SnackBar);
          final notice = find.descendant(
              of: snackBar, matching: find.byType(AppRuleNotice));
          final text =
              find.descendant(of: notice, matching: find.text(message));
          final close = find.descendant(
              of: notice,
              matching: find.byKey(const ValueKey('app-rule-notice-close')));
          final rect = tester.getRect(notice);
          heights.add(rect.height);
          expect(tester.getSize(notice),
              tester.getSize(find.byKey(const ValueKey('reference-notice'))));
          final snackBarRect = tester.getRect(snackBar);
          expect(snackBarRect.height, closeTo(rect.height + 34, .01));
          expect(snackBarRect.bottom, closeTo(640, .01));
          expect(rect.bottom, closeTo(snackBarRect.bottom - 34, .01));
          expect(
              MediaQuery.paddingOf(tester
                      .element(find.byKey(const ValueKey('reference-notice'))))
                  .bottom,
              34);
          expect(tester.getRect(text).center.dy, closeTo(rect.center.dy, .01));
          expect(tester.getRect(close).center.dy, closeTo(rect.center.dy, .01));
          expect(tester.getSize(close), const Size(40, 40));
          final surface =
              find.ancestor(of: notice, matching: find.byType(Material)).first;
          expect(
              tester.widget<Material>(surface).color,
              theme.brightness == Brightness.dark
                  ? app_style.AppPalette.white
                  : app_style.AppPalette.black);
          expect(tester.takeException(), isNull);

          await tester.tapAt(tester.getTopLeft(close) + const Offset(4, 4));
          await tester.pumpAndSettle();
          expect(snackBar, findsNothing);
          expect(
              find.byKey(const ValueKey('reference-notice')), findsOneWidget);
        }
        expect(heights.first, lessThan(heights.last));
      });
    }
  }

  for (final safeBottom in [0.0, 34.0]) {
    testWidgets(
        'photo saved notice keeps 8 top padding and safe bottom $safeBottom',
        (tester) async {
      tester.view.physicalSize = const Size(393, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(bottom: safeBottom);
      tester.view.viewPadding = FakeViewPadding(bottom: safeBottom);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);

      late BuildContext context;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (value) {
          context = value;
          return const Scaffold();
        }),
      ));
      showAppSnackBar(context, 'Saved to photos.',
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 54, 8),
          alignCloseIconWithText: true);
      await tester.pumpAndSettle();

      final notice = find.byType(AppRuleNotice);
      final noticeRect = tester.getRect(notice);
      final snackBarRect = tester.getRect(find.byType(SnackBar));
      final textRect = tester.getRect(find.text('Saved to photos.'));
      final closeRect =
          tester.getRect(find.byKey(const ValueKey('app-rule-notice-close')));
      final iconRect = tester.getRect(
          find.descendant(of: notice, matching: find.byIcon(Icons.close)));
      final textStyle =
          tester.widget<Text>(find.text('Saved to photos.')).style!;
      expect(textRect.top - noticeRect.top, closeTo(8, .01));
      expect(
          iconRect.center.dy,
          closeTo(
              textRect.top + textStyle.fontSize! * textStyle.height! / 2, .01));
      expect(closeRect.center.dy, closeTo(noticeRect.center.dy, .01));
      expect(snackBarRect.height - noticeRect.height, closeTo(safeBottom, .01));
      expect(closeRect.size, const Size(40, 40));
      expect(tester.takeException(), isNull);
    });
  }

  for (final scenario in [
    (name: 'screen edge', safeBottom: 0.0, keyboard: 0.0, navigation: false),
    (
      name: 'bottom navigation',
      safeBottom: 34.0,
      keyboard: 0.0,
      navigation: true
    ),
    (name: 'keyboard', safeBottom: 34.0, keyboard: 240.0, navigation: false),
  ]) {
    testWidgets('snack bar stays above the ${scenario.name}', (tester) async {
      tester.view.physicalSize = const Size(393, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = FakeViewPadding(bottom: scenario.safeBottom);
      tester.view.padding = FakeViewPadding(
          bottom: scenario.keyboard == 0 ? scenario.safeBottom : 0);
      tester.view.viewInsets = FakeViewPadding(bottom: scenario.keyboard);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewInsets);

      late BuildContext context;
      await tester.pumpWidget(MaterialApp(
        theme: app_style.whitetheme,
        home: Builder(builder: (value) {
          context = value;
          return Scaffold(
            bottomNavigationBar: scenario.navigation
                ? const SafeArea(
                    key: ValueKey('bottom-navigation'),
                    top: false,
                    child: SizedBox(height: 46),
                  )
                : null,
          );
        }),
      ));
      showAppSnackBar(context, 'Saved.');
      await tester.pumpAndSettle();

      final snackBar = find.byType(SnackBar);
      final rect = tester.getRect(snackBar);
      expect(rect, tester.getRect(find.byType(AppRuleNotice)));
      if (scenario.navigation) {
        final navigation =
            tester.getRect(find.byKey(const ValueKey('bottom-navigation')));
        expect(navigation.height, 46 + scenario.safeBottom);
        expect(rect.bottom, navigation.top);
      } else {
        expect(rect.bottom, 640 - scenario.keyboard);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final duration in [null, const Duration(seconds: 2)]) {
    testWidgets('snack bar expires with duration $duration', (tester) async {
      final context = await _pumpHost(tester);
      if (duration == null) {
        showAppSnackBar(context, 'Saved.');
      } else {
        showAppSnackBar(context, 'Saved.', duration: duration);
      }
      await tester.pumpAndSettle();
      await tester.pump((duration ?? const Duration(seconds: 4)) -
          const Duration(seconds: 1));
      expect(find.text('Saved.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });
  }

  testWidgets('closing a snack bar shows the next queued message',
      (tester) async {
    final context = await _pumpHost(tester);
    showAppSnackBar(context, 'First message.');
    await tester.pumpAndSettle();
    showAppSnackBar(context, 'Second message.');
    await tester.pumpAndSettle();
    expect(find.text('First message.'), findsOneWidget);
    expect(find.text('Second message.'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('app-rule-notice-close')));
    await tester.pumpAndSettle();
    expect(find.text('First message.'), findsNothing);
    expect(find.text('Second message.'), findsOneWidget);
  });

  testWidgets('replaceCurrent shows a new message immediately', (tester) async {
    final context = await _pumpHost(tester);
    showAppSnackBar(context, 'First message.');
    await tester.pumpAndSettle();
    showAppSnackBar(context, 'Second message.', replaceCurrent: true);
    await tester.pumpAndSettle();
    expect(find.text('First message.'), findsNothing);
    expect(find.text('Second message.'), findsOneWidget);
  });

  testWidgets('swiping down dismisses the snack bar', (tester) async {
    final context = await _pumpHost(tester);
    showAppSnackBar(context, 'Saved.');
    await tester.pumpAndSettle();
    await tester.fling(find.byType(SnackBar), const Offset(0, 60), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
}

Future<BuildContext> _pumpHost(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(MaterialApp(
    theme: app_style.whitetheme,
    home: Builder(builder: (value) {
      context = value;
      return const Scaffold();
    }),
  ));
  return context;
}
