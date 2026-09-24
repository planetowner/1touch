import 'support/app_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/features/match_info/match_info_features.dart';

void main() {
  setUpAppCatalog();
  setUpAll(() async {
    await (FontLoader('Archivo')
          ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf')))
        .load();
  });

  testWidgets('matches the Figma header coordinates at 393px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHeader(tester, 'Round of 16',
        home: 'Team Name', away: 'Team Name');

    // Figma 1360:31154의 실제 측정값에 화면 좌우 여백 24px를 더했어요.
    expect(tester.getRect(_teamLogo('home')),
        const Rect.fromLTWH(28.5, 24, 72, 72));
    expect(tester.getRect(_teamLogo('away')),
        const Rect.fromLTWH(295, 24, 72, 72));
    expect(tester.getRect(find.byKey(const ValueKey('match-score-values'))),
        const Rect.fromLTWH(134, 34, 130, 65));
    expect(tester.getTopLeft(find.text('Team Name').first).dy, 104);
    expect(tester.getTopLeft(find.text('Team Name').last).dy, 104);
    expect(tester.getTopLeft(find.text('Full Time')).dy, 115);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 393.0, 420.0, 430.0]) {
    testWidgets('keeps teams and scores fixed when title changes at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      List<Rect>? initialGeometry;
      for (final title in [
        'UCL · Final',
        'UEFA 챔피언스리그 16강 1차전',
        'Copa Del Rey · Semi-final · Leg 1 of 2',
        null,
      ]) {
        await _pumpHeader(tester, title);
        final geometry = [
          tester.getRect(_teamLogo('home')),
          tester.getRect(_teamLogo('away')),
          tester.getRect(find.text('레알 마드리드')),
          tester.getRect(find.text('맨체스터 시티')),
          tester.getRect(find.byKey(const ValueKey('match-score-values'))),
          tester.getRect(find.text('Full Time')),
          tester.getRect(find.byType(MatchScoreHeader)),
        ];
        initialGeometry ??= geometry;
        expect(geometry, initialGeometry, reason: title ?? 'no title');
        expect(tester.takeException(), isNull);
      }
    });
  }
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
              status: Text('Scheduled'),
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

    for (final label in [
      'UEFA 챔피언스리그 16강 1차전',
      'Copa Del Rey · Semi-final · Leg 1 of 2'
    ]) {
      testWidgets('fits $label at ${size.width}', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MatchScoreHeader(
                homeLogoAsset: '',
                awayLogoAsset: '',
                homeTeamId: 1,
                awayTeamId: 2,
                homeTeamName: '레알 마드리드',
                awayTeamName: '맨체스터 시티',
                homeScore: '3',
                awayScore: '0',
                status: const Text('Final'),
                roundLabel: label,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text(label), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Finder _teamLogo(String side) => find.descendant(
      of: find.byKey(ValueKey('match-score-$side-team')),
      matching: find.byType(Image),
    );

Future<void> _pumpHeader(WidgetTester tester, String? title,
    {String home = '레알 마드리드', String away = '맨체스터 시티'}) async {
  await tester.pumpWidget(MaterialApp(
    theme: app_style.darktheme,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: MatchScoreHeader(
          homeLogoAsset: '',
          awayLogoAsset: '',
          homeTeamId: 1,
          awayTeamId: 2,
          homeTeamName: home,
          awayTeamName: away,
          homeScore: '3',
          awayScore: '0',
          status: const Text('Full Time'),
          roundLabel: title,
        ),
      ),
    ),
  ));
  await tester.pump();
}
