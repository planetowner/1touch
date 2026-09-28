import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/app_info_button.dart';

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

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-info-popup')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
