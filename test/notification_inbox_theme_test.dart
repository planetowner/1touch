import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/comm_pages/NotificationInbox.dart';
import 'package:onetouch/core/style.dart' as app_style;

void main() {
  Future<void> pumpInbox(
    WidgetTester tester, {
    required ThemeData theme,
    required Size size,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const NotificationInboxPage(),
      ),
    );
    await tester.pump();
  }

  Color filterColor(WidgetTester tester, String name) {
    final filter = tester.widget<AnimatedContainer>(
      find.byKey(ValueKey('notification-filter-$name')),
    );
    return (filter.decoration! as BoxDecoration).color!;
  }

  testWidgets('notification inbox follows the compact light design',
      (tester) async {
    await pumpInbox(
      tester,
      theme: app_style.whitetheme,
      size: const Size(320, 568),
    );

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('notification-inbox-scaffold')),
    );
    final backIcon = tester.widget<Icon>(find.byIcon(Icons.arrow_back_ios_new));
    final searchIcon = tester.widget<Icon>(find.byIcon(Icons.search));

    expect(scaffold.backgroundColor, app_style.AppPalette.lightModeDarkGrey);
    expect(backIcon.color, app_style.AppPalette.black);
    expect(searchIcon.color, app_style.AppPalette.black);
    expect(filterColor(tester, 'all'), app_style.AppPalette.black);
    expect(filterColor(tester, 'team'), app_style.AppPalette.white);

    await tester.tap(find.text('TEAM'));
    await tester.pumpAndSettle();
    expect(filterColor(tester, 'team'), app_style.AppPalette.black);
    expect(find.text('FC Barcelona'), findsOneWidget);
    expect(find.text('Bayern Munich'), findsOneWidget);
    expect(find.text('Reaction'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification inbox retains its tall dark design',
      (tester) async {
    await pumpInbox(
      tester,
      theme: app_style.darktheme,
      size: const Size(430, 932),
    );

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('notification-inbox-scaffold')),
    );
    expect(scaffold.backgroundColor, Colors.black);
    expect(filterColor(tester, 'all'), app_style.AppPalette.white);
    expect(filterColor(tester, 'team'), const Color(0xFF2B2B2B));
    expect(tester.takeException(), isNull);
  });
}
