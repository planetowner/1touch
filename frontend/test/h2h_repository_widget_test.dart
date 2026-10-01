import 'support/app_catalog.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'support/fake_betting_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/core/team_comparison_colors.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/features/betting_widgets.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/screens/MatchScreen_tabs/H2H.dart';

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
  testWidgets('uses the participating favorite team as the H2H perspective',
      (tester) async {
    await _setSize(tester, const Size(430, 932));
    final originalFavorite = currentUserPreferences.favoriteTeamId.value;
    currentUserPreferences.favoriteTeamId.value = 19;
    addTearDown(
      () => currentUserPreferences.favoriteTeamId.value = originalFavorite,
    );
    final repository = _RecordingFixtureRepository(
      loader: (_, __) async => const [
        Fixture(
          fixtureId: 901,
          seasonId: 25583,
          competitionId: 8,
          homeTeamId: 8,
          awayTeamId: 19,
          competitionType: CompetitionType.league,
          roundName: '9',
          status: FixtureStatus.past,
          startingAt: '2026-01-10 15:00:00',
          homeScore: 0,
          awayScore: 2,
        ),
        Fixture(
          fixtureId: 902,
          seasonId: 25583,
          competitionId: 8,
          homeTeamId: 19,
          awayTeamId: 8,
          competitionType: CompetitionType.league,
          roundName: '8',
          status: FixtureStatus.past,
          startingAt: '2025-08-10 15:00:00',
          homeScore: 3,
          awayScore: 1,
        ),
        Fixture(
          fixtureId: 903,
          seasonId: 25583,
          competitionId: 8,
          homeTeamId: 8,
          awayTeamId: 19,
          competitionType: CompetitionType.league,
          roundName: '7',
          status: FixtureStatus.past,
          startingAt: '2025-01-10 15:00:00',
          homeScore: 1,
          awayScore: 1,
        ),
      ],
    );

    await tester.pumpWidget(_testApp(repository: repository));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('match-h2h-against-team-8')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('match-h2h-win-value')),
          )
          .data,
      '2',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('match-h2h-draw-value')),
          )
          .data,
      '1',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('match-h2h-loss-value')),
          )
          .data,
      '0',
    );
    final expectedColors = TeamComparisonColorResolver.resolve(
      anchorTeamName: 'Arsenal',
      opponentTeamName: 'Liverpool',
      background: Colors.white,
    );
    final betCard = tester.widget<BettingParticipationCard>(
      find.byType(BettingParticipationCard),
    );
    expect(
      betCard.barColors![0],
      expectedColors.opponent,
    );
    expect(
      betCard.barColors![2],
      expectedColors.anchor,
    );
    final firstPastMatch = find.byKey(
      const ValueKey('match-h2h-fixture-901'),
    );
    expect(
      find.descendant(of: firstPastMatch, matching: find.byType(ClipOval)),
      findsNothing,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('match-h2h-past-home-logo-8')).first,
      ),
      const Size.square(32),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('match-h2h-past-away-logo-19')).first,
      ),
      const Size.square(32),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('upcoming H2H keeps the Match Preview betting colors',
      (tester) async {
    await _setSize(tester, const Size(430, 932));
    final originalFavorite = currentUserPreferences.favoriteTeamId.value;
    currentUserPreferences.favoriteTeamId.value = 83;
    addTearDown(
      () => currentUserPreferences.favoriteTeamId.value = originalFavorite,
    );
    final repository = _RecordingFixtureRepository(
      loader: (_, __) async => const [],
    );
    final betting = fakeBettingController(_rayoGetafeFixture.fixtureId);
    await betting.load();

    Future<void> pumpH2H(ThemeData theme) => tester.pumpWidget(
          MaterialApp(
            theme: theme,
            darkTheme: theme,
            themeMode: theme.brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: Scaffold(
              body: H2HTab(
                fixture: _rayoGetafeFixture,
                fixtureRepository: repository,
                bettingController: betting,
              ),
            ),
          ),
        );

    await pumpH2H(ThemeData.light());
    await tester.pump();

    var renderedBar = tester.widget<BettingProbabilityBar>(
      find.descendant(
        of: find.byKey(const ValueKey('match-h2h-bets-card')),
        matching: find.byType(BettingProbabilityBar),
      ),
    );
    expect(renderedBar.colors!.first, const Color(0xFFCDA23F));
    expect(renderedBar.colors!.last, const Color(0xFF0D6BCB));
    expect(
      renderedBar.colors![1],
      Color.lerp(renderedBar.colors!.first, renderedBar.colors!.last, 0.5),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpH2H(ThemeData.dark());
    await tester.pump();

    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('match-h2h-bets-card'))),
      ).brightness,
      Brightness.dark,
    );
    renderedBar = tester.widget<BettingProbabilityBar>(
      find.descendant(
        of: find.byKey(const ValueKey('match-h2h-bets-card')),
        matching: find.byType(BettingProbabilityBar),
      ),
    );
    expect(renderedBar.colors!.first, const Color(0xFFCDA23F));
    expect(renderedBar.colors!.last, const Color(0xFF0D6BCB));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    betting.dispose();
  });

  testWidgets('falls back to the selected match home team perspective',
      (tester) async {
    await _setSize(tester, const Size(430, 932));
    final originalFavorite = currentUserPreferences.favoriteTeamId.value;
    currentUserPreferences.favoriteTeamId.value = 83;
    addTearDown(
      () => currentUserPreferences.favoriteTeamId.value = originalFavorite,
    );
    final repository = _RecordingFixtureRepository(
      loader: (_, __) async => [_pastFixture(homeScore: 2)],
    );

    await tester.pumpWidget(_testApp(repository: repository));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('match-h2h-against-team-19')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('match-h2h-win-value')),
          )
          .data,
      '1',
    );
    expect(tester.takeException(), isNull);
  });

  for (final locale in appSupportedLocales) {
    for (final size in [const Size(320, 568), const Size(430, 932)]) {
      testWidgets('spaces H2H controls evenly in $locale at $size',
          (tester) async {
        await _setSize(tester, size);
        final repository = _RecordingFixtureRepository(
          loader: (_, __) async => [_pastFixture()],
        );

        await tester.pumpWidget(
          _testApp(
            repository: repository,
            locale: locale,
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          ),
        );
        await tester.pump();

        final logo = find.byKey(const ValueKey('match-h2h-against-team-19'));
        final label = find.byKey(const ValueKey('match-h2h-against-label'));
        final dropdown = find.byKey(const ValueKey('match-h2h-limit-dropdown'));
        final isEnglish = locale.languageCode == 'en';
        final first = tester.getRect(isEnglish ? dropdown : logo);
        final middle = tester.getRect(label);
        final last = tester.getRect(isEnglish ? logo : dropdown);

        expect(first.left, closeTo(24, 0.1));
        expect(last.right, closeTo(size.width - 24, 0.1));
        expect(middle.left - first.right, closeTo(last.left - middle.right, 1));
        expect(first.right, lessThanOrEqualTo(middle.left));
        expect(middle.right, lessThanOrEqualTo(last.left));
        if (isEnglish) {
          final selectedLabel = tester.widget<Text>(
            find.descendant(
              of: dropdown,
              matching: find.text('LAST 5 MATCHES'),
            ),
          );
          final labelWidth = (TextPainter(
            text: TextSpan(
              text: selectedLabel.data,
              style: selectedLabel.style,
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout())
              .width;
          expect(labelWidth, lessThanOrEqualTo(first.width - 56));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('loads the selected H2H limit on a compact screen',
      (tester) async {
    await _setSize(tester, const Size(320, 568));
    final second = Completer<List<Fixture>>();
    final repository = _RecordingFixtureRepository(
      loader: (_, limit) => limit == 10
          ? second.future
          : Future.value([_pastFixture(homeScore: limit)]),
    );

    await tester.pumpWidget(
        _testApp(repository: repository, locale: const Locale('en')));
    await tester.pump();

    expect(repository.requests, [(fixtureId: 1001, limit: 5)]);
    expect(find.byKey(const ValueKey('match-h2h-wdl-card')), findsOneWidget);
    final dropdownSize = tester.getSize(
      find.byKey(const ValueKey('match-h2h-limit-dropdown')),
    );
    expect(dropdownSize.width, greaterThan(152));
    expect(dropdownSize.height, 40);
    final selectedLabel = tester.widget<Text>(
      find
          .descendant(
            of: find.byKey(const ValueKey('match-h2h-limit-dropdown')),
            matching: find.text('LAST 5 MATCHES'),
          )
          .first,
    );
    expect(selectedLabel.maxLines, 1);
    expect(selectedLabel.softWrap, isFalse);
    final labelPainter = TextPainter(
      text: TextSpan(
        text: selectedLabel.data,
        style: selectedLabel.style,
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    expect(labelPainter.width, lessThanOrEqualTo(dropdownSize.width - 56));

    final dropdown = tester.widget<AppDropdown<int>>(
      find.byKey(const ValueKey('match-h2h-limit-dropdown')),
    );
    dropdown.onChanged(10);
    await tester.pump();
    expect(find.byKey(const ValueKey('match-h2h-loading')), findsOneWidget);
    second.complete([_pastFixture(homeScore: 10)]);
    await tester.pump();

    expect(repository.requests, [
      (fixtureId: 1001, limit: 5),
      (fixtureId: 1001, limit: 10),
    ]);
    expect(find.text('10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an error and retries on a taller screen', (tester) async {
    await _setSize(tester, const Size(430, 932));
    var shouldFail = true;
    final repository = _RecordingFixtureRepository(
      loader: (_, __) async {
        if (shouldFail) throw StateError('Unavailable');
        return [_pastFixture()];
      },
    );

    await tester.pumpWidget(_testApp(repository: repository));
    await tester.pump();

    expect(find.byKey(const ValueKey('match-h2h-error')), findsOneWidget);
    expect(find.text('Unable to load head-to-head matches.'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.text('RETRY'));
    await tester.pump();
    await tester.pump();

    expect(repository.requests, hasLength(2));
    expect(find.byKey(const ValueKey('match-h2h-wdl-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores a stale result after the selected limit changes', (
    tester,
  ) async {
    await _setSize(tester, const Size(320, 568));
    final first = Completer<List<Fixture>>();
    final second = Completer<List<Fixture>>();
    final repository = _RecordingFixtureRepository(
      loader: (_, limit) => limit == 5 ? first.future : second.future,
    );

    await tester.pumpWidget(_testApp(repository: repository));

    final dropdown = tester.widget<AppDropdown<int>>(
      find.byKey(const ValueKey('match-h2h-limit-dropdown')),
    );
    dropdown.onChanged(10);
    await tester.pump();

    second.complete([_pastFixture(homeScore: 10)]);
    await tester.pump();
    expect(find.text('10'), findsOneWidget);

    first.complete([_pastFixture(homeScore: 5)]);
    await tester.pump();
    expect(find.text('10'), findsOneWidget);
    expect(find.text('5'), findsNothing);
  });

  testWidgets('opens the selected head-to-head fixture', (tester) async {
    await _setSize(tester, const Size(430, 932));
    final repository = _RecordingFixtureRepository(
      loader: (_, __) async => [_pastFixture()],
    );
    final betting = fakeBettingController(_selectedFixture.fixtureId);
    addTearDown(betting.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: H2HTab(
              bettingController: betting,
              fixture: _selectedFixture,
              fixtureRepository: repository,
            ),
          ),
        ),
        GoRoute(
          path: '/match/:matchId',
          builder: (_, state) {
            final fixture = state.extra! as Fixture;
            return Text(
              'match-${state.pathParameters['matchId']}-'
              '${state.uri.queryParameters['status']}-'
              '${fixture.fixtureId}',
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    final card = find.byKey(const ValueKey('match-h2h-fixture-900'));
    await tester.ensureVisible(card);
    await tester.pump();
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.text('match-900-past-900'), findsOneWidget);
  });
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _testApp({
  required _RecordingFixtureRepository repository,
  Locale? locale,
  EdgeInsetsGeometry contentPadding = EdgeInsets.zero,
}) {
  final betting = fakeBettingController(_selectedFixture.fixtureId);
  addTearDown(betting.dispose);
  return MaterialApp(
    locale: locale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationDelegates,
    home: Scaffold(
      body: Padding(
        padding: contentPadding,
        child: H2HTab(
          bettingController: betting,
          fixture: _selectedFixture,
          fixtureRepository: repository,
        ),
      ),
    ),
  );
}

const _selectedFixture = Fixture(
  fixtureId: 1001,
  seasonId: 25583,
  competitionId: 8,
  homeTeamId: 8,
  awayTeamId: 19,
  competitionType: CompetitionType.league,
  roundName: '10',
  status: FixtureStatus.upcoming,
  startingAt: '2026-09-20 15:00:00',
);

const _rayoGetafeFixture = Fixture(
  fixtureId: 1002,
  seasonId: 25583,
  competitionId: 8,
  homeTeamId: 377,
  awayTeamId: 106,
  competitionType: CompetitionType.league,
  roundName: '11',
  status: FixtureStatus.upcoming,
  startingAt: '2026-09-27 15:00:00',
);

Fixture _pastFixture({int homeScore = 2}) {
  return Fixture(
    fixtureId: 900,
    seasonId: 25583,
    competitionId: 8,
    homeTeamId: 8,
    awayTeamId: 19,
    competitionType: CompetitionType.league,
    roundName: '5',
    status: FixtureStatus.past,
    startingAt: '2026-01-10 15:00:00',
    homeScore: homeScore,
    awayScore: 1,
  );
}

typedef _HeadToHeadLoader = Future<List<Fixture>> Function(
    int fixtureId, int limit);

class _RecordingFixtureRepository extends MockFixtureRepository {
  _RecordingFixtureRepository({required this.loader})
      : super(fixtures: const [_selectedFixture]);

  final _HeadToHeadLoader loader;
  final List<({int fixtureId, int limit})> requests = [];

  @override
  Future<List<Fixture>> loadHeadToHead(int fixtureId, {int limit = 10}) {
    requests.add((fixtureId: fixtureId, limit: limit));
    return loader(fixtureId, limit);
  }
}
