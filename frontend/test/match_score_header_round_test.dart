import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/MatchInfoFeatures.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('omits a missing round label at ${size.width}x${size.height}',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MatchScoreHeader(
              homeLogoAsset: '',
              awayLogoAsset: '',
              homeTeamId: 1,
              awayTeamId: 2,
              homeTeamName: 'Home',
              awayTeamName: 'Away',
              homeScore: '-',
              awayScore: '-',
              statusLabel: 'Scheduled',
              roundLabel: null,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('null'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
