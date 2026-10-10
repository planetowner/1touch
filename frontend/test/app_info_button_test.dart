import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/app_info_button.dart';
import 'package:onetouch/core/app_close_header.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/l10n/app_localizations.dart';

void main() {
  testWidgets('explanation opens in a rounded box and closes outside',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: AppInfoButton(
            title: 'BEST XI',
            message: 'Example explanation',
            layoutSize: 14,
          ),
        ),
      ),
    ));

    expect(tester.getSize(find.byType(AppInfoButton)), const Size(14, 14));
    expect(tester.getSize(find.byIcon(Icons.help_outline)), const Size(20, 20));

    await tester.tap(find.byType(AppInfoButton));
    await tester.pumpAndSettle();

    final dialog = tester.widget<Dialog>(
      find.byKey(const ValueKey('app-info-popup')),
    );
    expect(find.text('Example explanation'), findsOneWidget);
    expect(find.text('BEST XI'), findsOneWidget);
    expect(
      (dialog.shape as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(16),
    );
    expect(dialog.backgroundColor, AppPalette.lightModeDarkGrey);
    expect(dialog.insetPadding,
        const EdgeInsets.symmetric(horizontal: 24, vertical: 24));
    expect(find.byKey(const ValueKey('app-info-close')), findsOneWidget);
    expect(find.text('I understand'), findsNothing);
    final contentRect =
        tester.getRect(find.byKey(const ValueKey('app-info-content')));
    final messageRect = tester.getRect(find.text('Example explanation'));
    final headerRect = tester.getRect(find.byType(AppCloseHeader));
    final titleRect = tester.getRect(find.text('BEST XI'));
    final closeRect =
        tester.getRect(find.byKey(const ValueKey('app-info-close')));
    expect(messageRect.left - contentRect.left, 24);
    expect(headerRect.top - contentRect.top, 24);
    expect(titleRect.left, messageRect.left);
    expect(titleRect.center.dy, closeRect.center.dy);
    expect(closeRect.size, const Size.square(24));
    expect(messageRect.top - headerRect.bottom, 8);
    expect(messageRect.width, contentRect.width - 48);
    expect(contentRect.bottom - messageRect.bottom, 24);
    expect(contentRect.right - closeRect.right, 24);

    await tester.tap(find.byKey(const ValueKey('app-info-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-info-popup')), findsNothing);

    await tester.tap(find.byType(AppInfoButton));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-info-popup')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark popup uses the reference grey surface', (tester) async {
    appLocaleController.value = const Locale('ko');
    addTearDown(() => appLocaleController.value = const Locale('en'));
    await tester.pumpWidget(MaterialApp(
      theme: darktheme,
      locale: const Locale('ko'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      home: const Scaffold(
        body: Center(
            child: AppInfoButton(title: 'BEST XI', message: 'Explanation')),
      ),
    ));
    await tester.tap(find.byType(AppInfoButton));
    await tester.pumpAndSettle();
    final dialog = tester.widget<Dialog>(
      find.byKey(const ValueKey('app-info-popup')),
    );
    expect(dialog.backgroundColor, AppPalette.lightGrey);
    final title = tester.widget<Text>(find.text('베스트 11'));
    expect(title.style!.fontSize, 16);
    expect(title.style!.fontWeight, FontWeight.w700);
    final headerRect = tester.getRect(find.byType(AppCloseHeader));
    final titleRect = tester.getRect(find.text('베스트 11'));
    final contentRect =
        tester.getRect(find.byKey(const ValueKey('app-info-content')));
    expect(titleRect.left - contentRect.left, 24);
    expect(headerRect.height, titleRect.height);
    expect(headerRect.height, greaterThan(24));
    expect(tester.takeException(), isNull);
  });
}
