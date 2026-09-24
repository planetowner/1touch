import 'support/app_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/catalog/football_names.dart';
import 'package:onetouch/features/HomeScreenFeatures.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/date_labels.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team_overview.dart';

void main() {
  setUpAppCatalog();
  setUpAll(() async {
    await (FontLoader('Archivo')
          ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf')))
        .load();
    await (FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf')))
        .load();
  });

  test('home card date format puts localized time on its own line', () {
    expect(
        fixtureDateLabel(DateTime(2026, 9, 20, 9), locale: const Locale('ko')),
        "9월 20일 (일)\n오전 9:00");
    expect(
        fixtureDateLabel(DateTime(2026, 10, 11, 23, 30),
            locale: const Locale('ko')),
        "10월 11일 (일)\n오후 11:30");
  });

  for (final width in [320.0, 393.0, 430.0]) {
    testWidgets('keeps league on one line and kickoff on two at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpCard(tester, position: 2, delta: 3);

      expect(find.text('프리미어리그 2위'), findsOneWidget);
      final movement = find.byKey(const ValueKey('home-team-rank-movement'));
      final icon =
          find.descendant(of: movement, matching: find.byType(SvgPicture));
      expect(tester.getSize(icon), const Size(24, 24));
      expect(find.descendant(of: movement, matching: find.text('3')),
          findsOneWidget);

      for (final label in [
        '프리미어리그 6R',
        '10월 11일 (일)',
        '오전 11:30',
        '9월 20일 (일)',
        '오전 9:00',
      ]) {
        final finder = find.text(label);
        expect(finder, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(finder);
        expect(paragraph.maxLines, 1);
        expect(paragraph.didExceedMaxLines, isFalse);
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(24));
        expect(rect.right, lessThanOrEqualTo(width - 24));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('changes ranking with team data and omits unavailable movement',
      (tester) async {
    await _pumpCard(tester, position: 2, delta: 3);
    await _pumpCard(tester, position: 5, delta: -2);
    expect(find.text('프리미어리그 5위'), findsOneWidget);
    final movement = find.byKey(const ValueKey('home-team-rank-movement'));
    final icon = tester.widget<SvgPicture>(
        find.descendant(of: movement, matching: find.byType(SvgPicture)));
    expect((icon.bytesLoader as SvgAssetLoader).assetName,
        'assets/standings/rank_down.svg');
    expect(find.descendant(of: movement, matching: find.text('2')),
        findsOneWidget);

    for (final delta in [0, null]) {
      await _pumpCard(tester, position: 5, delta: delta);
      expect(find.text('프리미어리그 5위'), findsOneWidget);
      expect(movement, findsNothing);
    }
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCard(WidgetTester tester,
    {required int position, required int? delta}) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('ko'),
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationDelegates,
    theme: app_style.darktheme.copyWith(
      textTheme: app_style.darktheme.textTheme
          .apply(fontFamilyFallback: const ['Pretendard']),
    ),
    home: FootballNamesScope(
      names: const FootballNames(
        teams: {9: '맨체스터 시티', 8: '리버풀'},
        teamShortNames: {9: '맨시티', 8: '리버풀'},
        competitions: {8: '프리미어리그'},
      ),
      child: Scaffold(
        body: DefaultTextStyle.merge(
          style: const TextStyle(fontFamilyFallback: ['Pretendard']),
          child: SingleChildScrollView(
            child: FavoriteTeamCard(
                team: TeamOverview(
              id: 9,
              name: 'Manchester City',
              shortName: 'MCI',
              imagePath: 'https://example.test/city.png',
              standing: {'position': position, 'rank_delta': delta},
              nextMatch: _fixture(1, DateTime(2026, 10, 11, 11, 30), false),
              lastMatch: _fixture(2, DateTime(2026, 9, 20, 9), true),
            )),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Fixture _fixture(int id, DateTime kickoff, bool past) => Fixture(
      fixtureId: id,
      seasonId: 1,
      competitionId: 8,
      homeTeamId: 8,
      awayTeamId: 9,
      competitionType: CompetitionType.league,
      roundName: '6',
      startingAt: kickoff.toUtc().toIso8601String(),
      status: past ? FixtureStatus.past : FixtureStatus.upcoming,
      homeScore: past ? 5 : null,
      awayScore: past ? 3 : null,
    );
