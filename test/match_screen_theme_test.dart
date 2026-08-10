import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/screens/MatchScreen.dart';

void main() {
  Future<void> pumpMatch(
    WidgetTester tester, {
    required ThemeData theme,
    required Size size,
    required String matchId,
    required String matchStatus,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: MatchScreen(matchId: matchId, matchStatus: matchStatus),
      ),
    );
    await tester.pump();
  }

  Color decorationColor(WidgetTester tester, Key key) {
    final container = tester.widget<Container>(find.byKey(key));
    return (container.decoration! as BoxDecoration).color!;
  }

  testWidgets('upcoming match uses responsive light surfaces', (tester) async {
    await pumpMatch(
      tester,
      theme: app_style.whitetheme,
      size: const Size(320, 568),
      matchId: '20100001',
      matchStatus: 'upcoming',
    );

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('match-screen-scaffold')),
    );
    final backIcon = tester.widget<Icon>(find.byIcon(Icons.arrow_back_ios_new));

    expect(scaffold.backgroundColor, app_style.AppPalette.lightModeDarkGrey);
    expect(backIcon.color, app_style.AppPalette.black);
    expect(
      decorationColor(tester, const ValueKey('match-betting-card')),
      app_style.AppPalette.white,
    );
    expect(
      decorationColor(tester, const ValueKey('match-preview-standing-header')),
      app_style.AppPalette.white,
    );

    await tester.ensureVisible(find.text('PLACE A BET'));
    await tester.pump();
    await tester.tap(find.text('PLACE A BET'));
    await tester.pumpAndSettle();
    expect(
      decorationColor(tester, const ValueKey('match-betting-modal')),
      app_style.AppPalette.white,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('match-nested-scroll')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('match-tab-scroll')),
      const Offset(-120, 0),
    );
    await tester.pump();
    await tester.tap(find.text('HEAD TO HEAD'));
    await tester.pump();
    expect(
      decorationColor(tester, const ValueKey('match-h2h-wdl-card')),
      app_style.AppPalette.white,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('past match tabs use light cards on a tall phone',
      (tester) async {
    await pumpMatch(
      tester,
      theme: app_style.whitetheme,
      size: const Size(430, 932),
      matchId: '19200001',
      matchStatus: 'past',
    );

    expect(
      decorationColor(tester, const ValueKey('match-momentum-card')),
      app_style.AppPalette.white,
    );

    await tester.tap(find.text('HEAD TO HEAD'));
    await tester.pump();
    expect(
      decorationColor(tester, const ValueKey('match-h2h-wdl-card')),
      app_style.AppPalette.white,
    );
    expect(
      decorationColor(tester, const ValueKey('match-h2h-bets-card')),
      app_style.AppPalette.white,
    );

    await tester.drag(
      find.byKey(const ValueKey('match-tab-scroll')),
      const Offset(-180, 0),
    );
    await tester.pump();
    await tester.tap(find.text('ANALYSIS'));
    await tester.pump();
    expect(
      decorationColor(tester, const ValueKey('match-analysis-attack-card')),
      app_style.AppPalette.white,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark match surfaces retain their existing palette',
      (tester) async {
    await pumpMatch(
      tester,
      theme: app_style.darktheme,
      size: const Size(430, 932),
      matchId: '20100001',
      matchStatus: 'upcoming',
    );

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('match-screen-scaffold')),
    );
    expect(scaffold.backgroundColor, Colors.black);
    expect(
      decorationColor(tester, const ValueKey('match-betting-card')),
      app_style.AppPalette.darkGrey,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('live match shell fits a compact viewport', (tester) async {
    await pumpMatch(
      tester,
      theme: app_style.whitetheme,
      size: const Size(320, 568),
      matchId: '19200003',
      matchStatus: 'live',
    );

    expect(find.text('MATCH INFO'), findsOneWidget);
    expect(find.text('LIVE CHAT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
