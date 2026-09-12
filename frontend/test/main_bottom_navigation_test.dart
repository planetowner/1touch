import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/main.dart';

void main() {
  const testCases = [
    (size: Size(320, 568), bottomInset: 0.0),
    (size: Size(430, 932), bottomInset: 34.0),
  ];

  for (final testCase in testCases) {
    final size = testCase.size;
    testWidgets('bottom navigation fits ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(bottom: testCase.bottomInset);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      var selectedIndex = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: app_style.darktheme,
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: OneTouchBottomNavigationBar(
                currentIndex: selectedIndex,
                onTap: (index) => setState(() => selectedIndex = index),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Players'), findsOneWidget);
      expect(find.text('Team'), findsOneWidget);
      expect(find.text('Community'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(
          const ValueKey('main-bottom-navigation-content'),
        )),
        Size(size.width, 68),
      );
      expect(
        tester.getSize(find.byType(OneTouchBottomNavigationBar)).height,
        68 + testCase.bottomInset,
      );

      final itemWidths = List.generate(
        4,
        (index) => tester
            .getSize(find.byKey(ValueKey('main-bottom-navigation-$index')))
            .width,
      );
      for (final width in itemWidths) {
        expect(width, moreOrLessEquals(size.width / 4));
      }

      await tester.tap(
        find.byKey(const ValueKey('main-bottom-navigation-3')),
      );
      await tester.pump();
      expect(selectedIndex, 3);
      expect(tester.takeException(), isNull);
    });
  }
}
