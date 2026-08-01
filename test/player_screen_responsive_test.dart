import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/players/mock_player_repository.dart';
import 'package:onetouch/screens/AllPlayersScreen.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/Overview.dart';

void main() {
  const phoneSizes = [
    Size(320, 568),
    Size(375, 667),
    Size(430, 932),
  ];
  final salah = playerRepository.findById('mohamed-salah')!;

  for (final size in phoneSizes) {
    testWidgets('player screen fits a ${size.width}x${size.height} viewport',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final horizontalPadding = (size.width * 0.05).clamp(16.0, 24.0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  height: 100,
                  child: PlayerScreenHeader(
                    player: salah,
                    horizontalPadding: horizontalPadding,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: PlayerBioStatsBlock(player: salah),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Mohamed Salah'), findsOneWidget);
      expect(find.text('Cost-Effectiveness'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
