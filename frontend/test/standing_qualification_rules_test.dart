import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/features/StandingFeatures.dart';

void main() {
  group('2025/26 Big Five standing rules', () {
    test('Premier League uses five UCL and three relegation places', () {
      final rules = rulesForLeague(8)!;

      expect(rules.uclPositions, {1, 2, 3, 4, 5});
      expect(rules.relegationPlayoffPositions, isEmpty);
      expect(rules.relegationPositions, {18, 19, 20});
    });

    test('La Liga uses five UCL and three relegation places', () {
      final rules = rulesForLeague(564)!;

      expect(rules.uclPositions, {1, 2, 3, 4, 5});
      expect(rules.relegationPlayoffPositions, isEmpty);
      expect(rules.relegationPositions, {18, 19, 20});
    });

    test('Bundesliga uses four UCL places and a relegation play-off', () {
      final rules = rulesForLeague(82)!;

      expect(rules.uclPositions, {1, 2, 3, 4});
      expect(rules.relegationPlayoffPositions, {16});
      expect(rules.relegationPositions, {17, 18});
    });

    test('Serie A uses four UCL and three relegation places', () {
      final rules = rulesForLeague(384)!;

      expect(rules.uclPositions, {1, 2, 3, 4});
      expect(rules.relegationPlayoffPositions, isEmpty);
      expect(rules.relegationPositions, {18, 19, 20});
      expect(rules.markerFor(17), isNull);
    });

    test('Ligue 1 distinguishes UCL qualifying and relegation play-off', () {
      final rules = rulesForLeague(301)!;

      expect(rules.uclPositions, {1, 2, 3});
      expect(rules.uclQualifyingPositions, {4});
      expect(rules.relegationPlayoffPositions, {16});
      expect(rules.relegationPositions, {17, 18});
    });
  });

  test('qualifying and play-off routes keep labels but use light colors', () {
    final ligue1Rules = rulesForLeague(301)!;
    final directUcl = ligue1Rules.markerFor(1)!;
    final qualifyingUcl = ligue1Rules.markerFor(4)!;
    final relegationPlayoff = ligue1Rules.markerFor(16)!;
    final automaticRelegation = ligue1Rules.markerFor(17)!;

    expect(directUcl.tier.label, 'UCL');
    expect(qualifyingUcl.tier.label, 'UCL');
    expect(directUcl.color, QualificationTier.ucl.color);
    expect(qualifyingUcl.color, QualificationTier.ucl.lightColor);
    expect(qualifyingUcl.color, isNot(directUcl.color));

    expect(relegationPlayoff.tier.label, 'REL');
    expect(automaticRelegation.tier.label, 'REL');
    expect(relegationPlayoff.color, QualificationTier.relegation.lightColor);
    expect(automaticRelegation.color, QualificationTier.relegation.color);
    expect(relegationPlayoff.color, isNot(automaticRelegation.color));

    expect(
      ligue1Rules.availableTiers,
      [
        QualificationTier.ucl,
        QualificationTier.uel,
        QualificationTier.conference,
        QualificationTier.relegation,
      ],
    );
  });

  for (final size in [const Size(320, 568), const Size(393, 852)]) {
    testWidgets(
        'legend keeps one UCL and REL label at ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: app_style.darktheme,
          home: const Scaffold(body: StandingsLegend(leagueId: 301)),
        ),
      );

      expect(find.text('UCL'), findsOneWidget);
      expect(find.text('REL'), findsOneWidget);
      expect(find.text('UCL Q'), findsNothing);
      expect(find.text('REL PO'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
