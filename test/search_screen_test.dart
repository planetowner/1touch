import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/comm_pages/Search.dart';
import 'package:onetouch/core/style.dart' as app_style;

Color? _effectiveTextColor(WidgetTester tester, Finder finder) {
  final element = tester.element(finder);
  final text = tester.widget<Text>(finder);
  return DefaultTextStyle.of(element).style.merge(text.style).color;
}

void _useCompactPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('empty search shows mixed recents with black light-mode text',
      (tester) async {
    _useCompactPhone(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: const Search(),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<Scaffold>(
            find.byKey(const ValueKey('search-scaffold')),
          )
          .backgroundColor,
      app_style.AppPalette.lightModeDarkGrey,
    );
    expect(find.byKey(const ValueKey('search-recents')), findsOneWidget);
    expect(find.text('RECENTS'), findsOneWidget);
    expect(find.byKey(const ValueKey('search-player-lee-kang-in')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('search-team-83')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-event-83-231')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-category-tabs')), findsNothing);
    expect(
      _effectiveTextColor(tester, find.text('RECENTS')),
      app_style.AppPalette.black,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).gradient != null,
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'typing reveals working category filters and clear restores recents',
      (tester) async {
    _useCompactPhone(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: const Search(),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('global-search-field')),
      'bar',
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('search-results')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-category-tabs')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-recents')), findsNothing);
    expect(
      _effectiveTextColor(tester, find.text('ALL')),
      app_style.AppPalette.black,
    );

    await tester.drag(
      find.byKey(const ValueKey('search-category-tabs')),
      const Offset(-120, 0),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('search-tab-teams')));
    await tester.pump();
    expect(find.byKey(const ValueKey('search-team-83')), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.byKey(const ValueKey('search-recents')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-category-tabs')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('events filter matches either team name', (tester) async {
    _useCompactPhone(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: const Search(),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('global-search-field')),
      'girona',
    );
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('search-category-tabs')),
      const Offset(-240, 0),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('search-tab-events')));
    await tester.pump();

    expect(find.byKey(const ValueKey('search-event-83-231')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
