import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/app_info_button.dart';
import 'package:onetouch/core/style.dart';

void main() {
  testWidgets('explanation opens in a rounded box and closes outside',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: AppInfoButton(
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
    expect(
      (dialog.shape as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(16),
    );
    expect(dialog.backgroundColor, AppPalette.lightModeDarkGrey);
    expect(dialog.insetPadding,
        const EdgeInsets.symmetric(horizontal: 24, vertical: 24));
    expect(find.byKey(const ValueKey('app-info-close')), findsOneWidget);
    expect(find.text('I understand'), findsNothing);
    final contentRect = tester.getRect(find.byKey(const ValueKey('app-info-content')));
    final messageRect = tester.getRect(find.text('Example explanation'));
    final closeRect = tester.getRect(find.byKey(const ValueKey('app-info-close')));
    expect(messageRect.left - contentRect.left, 24);
    expect(closeRect.top - contentRect.top, 24);
    expect(messageRect.top - closeRect.bottom, 16);
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
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: const Scaffold(
        body: Center(child: AppInfoButton(message: 'Explanation')),
      ),
    ));
    await tester.tap(find.byType(AppInfoButton));
    await tester.pumpAndSettle();
    final dialog = tester.widget<Dialog>(
      find.byKey(const ValueKey('app-info-popup')),
    );
    expect(dialog.backgroundColor, AppPalette.lightGrey);
  });
}
