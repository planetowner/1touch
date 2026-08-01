import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/Select_Favorite_Teams.dart';

void main() {
  const phoneSizes = [
    Size(320, 568),
    Size(375, 667),
    Size(393, 852),
  ];

  for (final size in phoneSizes) {
    testWidgets('fits a ${size.width}x${size.height} viewport', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: SelectFavoriteTeamsScreen()),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();

      expect(find.byIcon(Icons.keyboard_arrow_up), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
