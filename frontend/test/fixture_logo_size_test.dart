import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/features/competition/competition_label.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/overflow_scrolling_text.dart';
import 'package:onetouch/data/catalog/football_names.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/fixture.dart';

import 'support/app_catalog.dart';

void main() {
  setUpAppCatalog();
  setUpAll(() async {
    await (FontLoader('Archivo')
          ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf')))
        .load();
  });

  for (final width in [320.0, 375.0, 393.0, 430.0]) {
    testWidgets('fixture logos use the agreed sizes at ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: const [
                  MatchCard(
                    match: Fixture(
                      fixtureId: 1,
                      seasonId: 1,
                      competitionId: 8,
                      homeTeamId: 8,
                      awayTeamId: 19,
                      homeTeamLogo: 'https://example.test/home.png',
                      awayTeamLogo: 'https://example.test/away.png',
                      competitionType: CompetitionType.league,
                      roundName: '1',
                      status: FixtureStatus.upcoming,
                      startingAt: '2026-10-01T18:00:00Z',
                    ),
                  ),
                  MatchCard2(
                    date: 'Today',
                    venue: '',
                    team1shortname: 'AAA',
                    team1Logo: 'https://example.test/home.png',
                    team1Id: 8,
                    team2shortname: 'BBB',
                    team2Logo: 'https://example.test/away.png',
                    team2Id: 19,
                    competitionId: 8,
                    competitionName: 'Premier League',
                    fixture: Fixture(
                      fixtureId: 2,
                      seasonId: 1,
                      competitionId: 8,
                      homeTeamId: 8,
                      awayTeamId: 19,
                      competitionType: CompetitionType.league,
                      roundName: '1',
                      status: FixtureStatus.past,
                      startingAt: '2026-09-20T18:00:00Z',
                    ),
                    homeScore: 2,
                    awayScore: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      for (final key in ['next-match-home-logo', 'next-match-away-logo']) {
        expect(
            tester.getSize(find.byKey(ValueKey(key))), const Size.square(72));
      }
      for (final key in ['last-match-home-logo', 'last-match-away-logo']) {
        expect(tester.getSize(find.byKey(ValueKey(key))), const Size(48, 48));
      }
      expect(
        find.descendant(
          of: find.byType(MatchCard2),
          matching: find.byType(CompetitionLogo),
        ),
        findsOneWidget,
      );
      final lastMatchDate = find.byKey(const ValueKey('last-match-date-time'));
      final lastMatchInfo =
          find.byKey(const ValueKey('last-match-competition-info'));
      final lastMatchDivider = find.byKey(const ValueKey('last-match-divider'));
      final competition = find.descendant(
        of: lastMatchInfo,
        matching: find.byType(CompetitionLabel),
      );
      expect(competition, findsOneWidget);
      expect(tester.widget<CompetitionLabel>(competition).label,
          'Premier League Round 1');
      expect(tester.widget<CompetitionLabel>(competition).scrollOnOverflow,
          isTrue);
      expect(find.descendant(of: lastMatchInfo, matching: find.text('Round 1')),
          findsNothing);
      expect(lastMatchDivider, findsOneWidget);
      expect(tester.getRect(lastMatchDate).bottom,
          lessThan(tester.getRect(lastMatchDivider).top));
      expect(tester.getRect(lastMatchDivider).bottom,
          lessThan(tester.getRect(competition).top));
      final dateText = tester.widget<Text>(find.descendant(
        of: lastMatchDate,
        matching: find.text('Today'),
      ));
      expect(dateText.maxLines, 1);
      expect(dateText.softWrap, isFalse);
      expect(dateText.overflow, TextOverflow.visible);
      expect(
        find.descendant(of: lastMatchDate, matching: find.byType(FittedBox)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: lastMatchDate,
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      final surface =
          tester.getRect(find.byKey(const ValueKey('last-match-card-surface')));
      final homeLogo =
          tester.getRect(find.byKey(const ValueKey('last-match-home-logo')));
      final homeScore =
          tester.getRect(find.byKey(const ValueKey('last-match-home-score')));
      final middle = tester.getRect(lastMatchInfo);
      final date = tester.getRect(lastMatchDate);
      final awayScore =
          tester.getRect(find.byKey(const ValueKey('last-match-away-score')));
      final awayLogo =
          tester.getRect(find.byKey(const ValueKey('last-match-away-logo')));
      expect(homeLogo.left - surface.left, 16);
      expect(surface.right - awayLogo.right, 16);
      final gaps = [
        homeScore.left - homeLogo.right,
        middle.left - homeScore.right,
        awayScore.left - middle.right,
        awayLogo.left - awayScore.right,
      ];
      expect(gaps.every((gap) => gap >= 0 && gap <= 16), isTrue);
      expect(gaps[0], closeTo(gaps[3], 0.1));
      expect(gaps[1], closeTo(gaps[2], 0.1));
      expect(gaps[1], closeTo(12, 0.1));
      expect(date.center.dx, closeTo(surface.center.dx, 0.1));
      expect(date.left, greaterThanOrEqualTo(middle.left));
      expect(date.right, lessThanOrEqualTo(middle.right));
      expect(middle.center.dx, closeTo(surface.center.dx, 0.1));
      expect(
          middle.width,
          closeTo(
              surface.width -
                  32 -
                  2 * (homeLogo.width + homeScore.width) -
                  gaps.reduce((value, gap) => value + gap),
              0.1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('last-match competition uses the official name in every locale',
      (tester) async {
    const cases = [
      (Locale('en'), 2, 'UEFA Champions League', 'UEFA Champions League'),
      (Locale('ko'), 2, 'UEFA Champions League', 'UEFA 챔피언스리그'),
      (Locale('ja'), 2, 'UEFA Champions League', 'UEFAチャンピオンズリーグ'),
      (Locale('zh'), 2, 'UEFA Champions League', '欧洲冠军联赛'),
      (Locale('ko'), 27, 'Carabao Cup (EFL Cup)', '카라바오컵'),
      (Locale('ja'), 27, 'Carabao Cup (EFL Cup)', 'カラバオカップ'),
      (Locale('ko'), 8, 'Premier League', '프리미어리그'),
      (Locale('en'), 8, 'Premier League', 'Premier League'),
    ];
    for (final (locale, competitionId, originalName, expected) in cases) {
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        home: FootballNamesScope(
          names: FootballNames(competitions: {
            competitionId: expected,
          }),
          child: Scaffold(
            body: Builder(
              builder: (context) => MatchCard2(
                date: 'Yesterday',
                venue: '',
                team1shortname: 'AAA',
                team1Logo: '',
                team1Id: 8,
                team2shortname: 'BBB',
                team2Logo: '',
                team2Id: 19,
                competitionId: competitionId,
                competitionName:
                    competitionNameLabel(context, competitionId, originalName),
                homeScore: 2,
                awayScore: 1,
              ),
            ),
          ),
        ),
      ));
      expect(
          tester.widget<CompetitionLabel>(find.byType(CompetitionLabel)).label,
          expected);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('cup round scrolls when the last-match slot is narrow',
      (tester) async {
    final previousLocale = appLocaleController.value;
    appLocaleController.value = const Locale('ko');
    addTearDown(() => appLocaleController.value = previousLocale);
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ko'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: MatchCard2(
            date: '2일 전',
            venue: '',
            team1shortname: 'PSG',
            team1Logo: '',
            team1Id: 591,
            team2shortname: 'LEM',
            team2Logo: '',
            team2Id: 7758,
            competitionId: 569,
            competitionName: '쿠프 드 프랑스',
            fixture: Fixture(
              fixtureId: 1,
              seasonId: 1,
              competitionId: 569,
              homeTeamId: 591,
              awayTeamId: 7758,
              competitionType: CompetitionType.cup,
              roundName: 'Round of 16',
              status: FixtureStatus.past,
              startingAt: '2026-10-10T18:00:00Z',
            ),
            homeScore: 3,
            awayScore: 1,
          ),
        ),
      ),
    ));

    final competition = find.byType(CompetitionLabel);
    expect(tester.widget<CompetitionLabel>(competition).label, '쿠프 드 프랑스 16강');
    final scrolling = find.descendant(
      of: competition,
      matching: find.byType(Scrollable),
    );
    expect(scrolling, findsOneWidget);
    final position = tester.state<ScrollableState>(scrolling).position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
    expect(position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tottenham last-match round scrolls on a compact screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: MatchCard2(
            date: '2 days ago',
            venue: '',
            team1shortname: 'TOT',
            team1Logo: '',
            team1Id: 6,
            team2shortname: 'MCI',
            team2Logo: '',
            team2Id: 9,
            competitionId: 24,
            competitionName: 'FA Cup',
            fixture: Fixture(
              fixtureId: 2,
              seasonId: 1,
              competitionId: 24,
              homeTeamId: 6,
              awayTeamId: 9,
              competitionType: CompetitionType.cup,
              roundName: 'Semi-final',
              status: FixtureStatus.past,
              startingAt: '2026-10-10T18:00:00Z',
            ),
            homeScore: 1,
            awayScore: 2,
          ),
        ),
      ),
    ));

    final competition = find.byType(CompetitionLabel);
    expect(tester.widget<CompetitionLabel>(competition).label,
        'FA Cup Semi-final');
    final scrolling = find.descendant(
      of: competition,
      matching: find.byType(Scrollable),
    );
    expect(scrolling, findsOneWidget);
    final position = tester.state<ScrollableState>(scrolling).position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
    expect(position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('marquee corrects the estimate using rendered text width',
      (tester) async {
    Widget atWidth(double width) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: const DefaultTextStyle(
                  style: TextStyle(fontSize: 14, letterSpacing: 12),
                  child: OverflowScrollingText(
                    text: 'FA Cup SF',
                    style: TextStyle(fontSize: 14),
                    alignment: Alignment.center,
                  ),
                ),
              ),
            ),
          ),
        );
    await tester.pumpWidget(atWidth(100));

    // Text에는 상위 스타일의 자간이 상속되므로 최초 추정치보다 실제 폭이 넓어요.
    await tester.pump();
    final scrolling = find.descendant(
      of: find.byType(OverflowScrollingText),
      matching: find.byType(Scrollable),
    );
    expect(scrolling, findsOneWidget);
    final position = tester.state<ScrollableState>(scrolling).position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
    expect(position.pixels, greaterThan(0));

    await tester.pumpWidget(atWidth(240));
    await tester.pump();
    expect(scrolling, findsNothing);
    expect(tester.getCenter(find.text('FA Cup SF')).dx,
        closeTo(tester.getCenter(find.byType(OverflowScrollingText)).dx, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a fitting competition label stays centered and still',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 200,
            child: CompetitionLabel(
              competitionId: null,
              label: 'Cup',
              style: TextStyle(fontSize: 14),
              scrollOnOverflow: true,
            ),
          ),
        ),
      ),
    ));

    final competition = find.byType(CompetitionLabel);
    expect(find.descendant(of: competition, matching: find.byType(Scrollable)),
        findsNothing);
    expect(tester.getCenter(find.text('Cup')).dx,
        closeTo(tester.getCenter(competition).dx, 0.1));
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 430.0]) {
    testWidgets('last-match date keeps its font at ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: MatchCard2(
              date: '2 days ago',
              venue: '',
              team1shortname: 'FCB',
              team1Logo: '',
              team1Id: 8,
              team2shortname: 'FCU',
              team2Logo: '',
              team2Id: 19,
              competitionId: 8,
              competitionName: 'Premier League',
              homeScore: 7,
              awayScore: 0,
            ),
          ),
        ),
      ));

      final date = find.byKey(const ValueKey('last-match-date-time'));
      final dateText = tester.widget<Text>(
        find.descendant(of: date, matching: find.byType(Text)),
      );
      expect(dateText.data, '2 days ago');
      expect(dateText.style?.fontSize, 14);
      expect(dateText.maxLines, 1);
      expect(dateText.softWrap, isFalse);
      expect(dateText.overflow, TextOverflow.visible);
      expect(find.descendant(of: date, matching: find.byType(FittedBox)),
          findsNothing);
      final dateScroller =
          find.descendant(of: date, matching: find.byType(Scrollable));
      if (width == 320) {
        expect(dateScroller, findsOneWidget);
        final scrollable = tester.state<ScrollableState>(dateScroller);
        expect(scrollable.position.maxScrollExtent, greaterThan(0));
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump(const Duration(milliseconds: 800));
        expect(scrollable.position.pixels, greaterThan(0));
      } else {
        expect(dateScroller, findsNothing);
      }
      final dateRect = tester.getRect(date);
      final homeScoreRect =
          tester.getRect(find.byKey(const ValueKey('last-match-home-score')));
      final awayScoreRect =
          tester.getRect(find.byKey(const ValueKey('last-match-away-score')));
      expect(dateRect.left, greaterThanOrEqualTo(homeScoreRect.right));
      expect(dateRect.right, lessThanOrEqualTo(awayScoreRect.left));
      expect(dateRect.center.dx,
          closeTo(tester.getCenter(find.byType(MatchCard2)).dx, 0.1));
      expect(tester.takeException(), isNull);
    });
  }
}
