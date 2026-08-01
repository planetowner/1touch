import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/screens/PlayerComparisonScreen.dart';

void main() {
  testWidgets('comparison radar fills the 345 by 238 reference frame',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: PlayerComparisonScreen()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Mohamed Salah'));
    await tester.tap(find.text('Mohamed Salah'));
    await tester.pumpAndSettle();

    expect(find.byType(RadarChart), findsOneWidget);
    expect(tester.getSize(find.byType(RadarChart)), const Size(345, 238));
    expect(tester.takeException(), isNull);
  });
}
