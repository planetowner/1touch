import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/app_section_tab_bar.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('last section label keeps 24px at the right edge on $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(MaterialApp(
        home: DefaultTabController(
          length: 5,
          child: Builder(builder: (context) {
            return Scaffold(
              body: appSectionTabBar(
                context,
                controller: DefaultTabController.of(context),
                labels: const [
                  'Overview',
                  'Matches',
                  'Standing',
                  'Squad',
                  'Analysis',
                ],
                endPadding: 10,
              ),
            );
          }),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(TabBar), const Offset(-1000, 0));
      await tester.pumpAndSettle();

      final bar = tester.getRect(find.byType(TabBar));
      final lastLabel = tester.getRect(find.text('Analysis'));
      expect(bar.right - lastLabel.right, closeTo(24, 0.1));
      expect(tester.takeException(), isNull);
    });
  }
}
