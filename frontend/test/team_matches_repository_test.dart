import 'support/app_catalog.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/screens/TeamScreen_tabs/Matches.dart';

void main() {
  setUpAppCatalog();
  testWidgets('loads each match status and centers labels responsively',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pending = {
      for (final status in [
        FixtureStatus.past,
        FixtureStatus.live,
        FixtureStatus.upcoming,
      ])
        status: Completer<List<Fixture>>(),
    };
    final requestedStatuses = <FixtureStatus?>[];
    final repository = _ControlledFixtureRepository(
      (teamId, status, limit) {
        expect(teamId, 9);
        expect(limit, 200);
        requestedStatuses.add(status);
        return pending[status]!.future;
      },
    );

    await tester.pumpWidget(_app(repository, teamId: 9));

    expect(find.byKey(const ValueKey('matches-loading')), findsOneWidget);
    expect(
      requestedStatuses,
      [FixtureStatus.past, FixtureStatus.live, FixtureStatus.upcoming],
    );

    pending[FixtureStatus.past]!.complete([_fixture(1, FixtureStatus.past)]);
    pending[FixtureStatus.live]!.complete([_fixture(2, FixtureStatus.live)]);
    pending[FixtureStatus.upcoming]!.complete([
      _fixture(
        3,
        FixtureStatus.upcoming,
        competitionType: CompetitionType.cup,
        roundName: null,
        stageName: 'Semi-finals',
        leg: '2/2',
      ),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('matches-upcoming-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('matches-inline-live-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('matches-inline-past-header')),
      findsOneWidget,
    );
    expect(find.text(':'), findsNothing);
    expect(
      find.textContaining('Premier League · Semi-final · Leg 2 of 2'),
      findsOneWidget,
    );
    final competitionAndRound = find.byKey(
      const ValueKey('match-competition-round-3'),
    );
    expect(tester.widget<SizedBox>(competitionAndRound).width, double.infinity);
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: competitionAndRound,
              matching: find.byType(Text),
            ),
          )
          .textAlign,
      TextAlign.center,
    );
    final fixtureCard = tester.widget<Container>(
      find.byKey(const ValueKey('team-fixture-card-3')),
    );
    expect(
      (fixtureCard.decoration as BoxDecoration).boxShadow,
      app_style.lightModeCardShadows,
    );

    tester.view.physicalSize = const Size(430, 932);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final hasLive in [false, true]) {
    testWidgets(
        'opens at the nearest two upcoming matches, with live=$hasLive and past matches below',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = MockFixtureRepository(fixtures: [
        for (var index = 1; index <= 200; index++)
          _fixture(index, FixtureStatus.past,
              kickoff: DateTime(2026, 1, index)),
        if (hasLive)
          _fixture(201, FixtureStatus.live, kickoff: DateTime(2026, 1, 201)),
        for (var index = 202; index <= 401; index++)
          _fixture(index, FixtureStatus.upcoming,
              kickoff: DateTime(2026, 1, index)),
      ]);

      await tester.pumpWidget(_app(repository, teamId: 9));
      await tester.pumpAndSettle();

      final scroll = find.byKey(const ValueKey('matches-scroll'));
      final controller = tester.widget<CustomScrollView>(scroll).controller!;
      final secondUpcoming =
          find.byKey(const ValueKey('team-fixture-card-203'));
      final nextUpcoming = find.byKey(const ValueKey('team-fixture-card-202'));
      final next =
          find.byKey(ValueKey('team-fixture-card-${hasLive ? 201 : 200}'));
      expect(tester.getTopLeft(secondUpcoming).dy,
          closeTo(tester.getTopLeft(scroll).dy, 0.1));
      expect(tester.getBottomLeft(secondUpcoming).dy,
          lessThanOrEqualTo(tester.getTopLeft(nextUpcoming).dy));
      expect(tester.getBottomLeft(nextUpcoming).dy,
          lessThan(tester.getTopLeft(next).dy));
      expect(
        tester.getTopLeft(_cardSurface(202)).dy -
            tester.getBottomLeft(_cardSurface(203)).dy,
        closeTo(16, 0.1),
      );
      expect(next.hitTestable(), findsOneWidget);
      final nextSection = hasLive ? 'live' : 'past';
      final divider = find.byKey(ValueKey('matches-$nextSection-divider'));
      final title = find.descendant(
        of: find.byKey(ValueKey('matches-inline-$nextSection-header')),
        matching: find.byType(Text),
      );
      // Figma처럼 마지막 카드 → divider는 24px을 유지해요.
      expect(
          tester.getTopLeft(divider).dy -
              tester.getBottomLeft(_cardSurface(202)).dy,
          closeTo(24, 0.1));
      expect(tester.getTopLeft(title).dy - tester.getBottomLeft(divider).dy,
          closeTo(16, 0.1));
      expect(
          tester.getTopLeft(_cardSurface(hasLive ? 201 : 200)).dy -
              tester.getBottomLeft(title).dy,
          closeTo(16, 0.1));
      expect(tester.getSize(divider), const Size(345, 1));
      expect(
          find.byKey(const ValueKey('matches-upcoming-divider')), findsNothing);
      expect(
          find.descendant(
            of: find.byKey(const ValueKey('matches-header-stack')),
            matching: find.byKey(ValueKey('matches-$nextSection-divider')),
          ),
          findsNothing);
      expect(
          tester
              .getTopLeft(find.byKey(const ValueKey('team-fixture-card-200')))
              .dy,
          lessThan(tester
              .getTopLeft(find.byKey(const ValueKey('team-fixture-card-199')))
              .dy));

      final fade = find.byKey(const ValueKey('matches-top-fade'));
      expect(tester.getSize(fade).height, 56);
      expect(tester.getTopLeft(fade).dy,
          closeTo(tester.getTopLeft(scroll).dy, 0.1));
      expect(controller.position.minScrollExtent, lessThan(0));
      expect(controller.offset, 0);

      controller.jumpTo(controller.position.minScrollExtent);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('matches-top-fade')),
        findsNothing,
      );
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('matches-top-fade')),
        findsOneWidget,
      );

      // 카드를 중간까지 스크롤해도 페이드 앞에 밝은 띠가 생기지 않아야 해요.
      controller.jumpTo(40);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(fade).dy,
          closeTo(tester.getTopLeft(scroll).dy, 0.1));
      controller.jumpTo(0);
      await tester.pumpAndSettle();

      await tester.drag(scroll, const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(controller.offset, lessThan(0));
      expect(find.byKey(const ValueKey('team-fixture-card-204')).hitTestable(),
          findsOneWidget);
      expect(
          tester
              .getTopLeft(find.byKey(const ValueKey('team-fixture-card-204')))
              .dy,
          lessThan(tester.getTopLeft(secondUpcoming).dy));

      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(secondUpcoming).dy,
          closeTo(tester.getTopLeft(scroll).dy, 0.1));

      await tester.drag(scroll, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('team-fixture-card-198')).hitTestable(),
          findsOneWidget);
      expect(
          tester
              .getTopLeft(find.byKey(const ValueKey('team-fixture-card-199')))
              .dy,
          lessThan(tester
              .getTopLeft(find.byKey(const ValueKey('team-fixture-card-198')))
              .dy));
      expect(tester.takeException(), isNull);
    });
  }

  for (final upcomingCount in [0, 1]) {
    testWidgets(
        'opens with $upcomingCount upcoming matches without fading a sole match',
        (tester) async {
      final repository = MockFixtureRepository(fixtures: [
        _fixture(1, FixtureStatus.past),
        if (upcomingCount == 1) _fixture(2, FixtureStatus.upcoming),
      ]);
      await tester.pumpWidget(_app(repository, teamId: 9));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('matches-top-fade')), findsNothing);
      final first = find
          .byKey(ValueKey('team-fixture-card-${upcomingCount == 1 ? 2 : 1}'));
      expect(first.hitTestable(), findsOneWidget);
      expect(
          tester.getTopLeft(first).dy,
          closeTo(
              tester
                  .getTopLeft(find.byKey(const ValueKey('matches-scroll')))
                  .dy,
              0.1));
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in [const Locale('ko'), const Locale('en')]) {
    for (final width in [320.0, 393.0]) {
      testWidgets('upcoming uses shared date lines for $locale at $width',
          (tester) async {
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = MockFixtureRepository(fixtures: [
          _fixture(1, FixtureStatus.past),
          _fixture(2, FixtureStatus.live),
          _fixture(3, FixtureStatus.upcoming,
              kickoff: DateTime(2026, 10, 11, 11, 30)),
        ]);
        await tester.pumpWidget(_app(repository, teamId: 9, locale: locale));
        await tester.pumpAndSettle();

        final korean = locale.languageCode == 'ko';
        expect(find.text(korean ? '지난 경기' : 'PAST'), findsOneWidget);
        expect(find.text(korean ? '● 진행 중인 경기' : '• LIVE'), findsOneWidget);
        expect(find.text(korean ? '다가오는 경기' : 'UPCOMING'), findsOneWidget);
        final dateTime = find.descendant(
          of: find.byKey(const ValueKey('team-fixture-card-3')),
          matching: find.byType(FixtureDateTime),
        );
        final labels = tester
            .widgetList<Text>(find.descendant(
              of: dateTime,
              matching: find.byType(Text),
            ))
            .toList();
        expect(
            labels.map((text) => text.data),
            korean
                ? ['10월 11일 (일)', '오전 11:30']
                : ['Sun, Oct 11', '11:30\u202fAM']);
        expect(
            labels
                .every((text) => text.maxLines == 1 && text.softWrap == false),
            isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('shows an error and retries the complete request set',
      (tester) async {
    var shouldFail = true;
    var requestCount = 0;
    final repository = _ControlledFixtureRepository(
      (_, __, ___) async {
        requestCount++;
        if (shouldFail) throw StateError('network failed');
        return const [];
      },
    );

    await tester.pumpWidget(_app(repository, teamId: 9));
    await tester.pump();

    expect(find.text('Unable to load matches'), findsOneWidget);
    expect(find.byKey(const ValueKey('matches-retry')), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.byKey(const ValueKey('matches-retry')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('matches-empty')), findsOneWidget);
    expect(requestCount, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'shows API team identity for an opponent outside the mock catalog',
      (tester) async {
    final repository = _ControlledFixtureRepository(
      (_, status, __) async => status == FixtureStatus.upcoming
          ? [
              Fixture(
                fixtureId: 33,
                competitionId: 24,
                seasonId: 25583,
                competitionType: CompetitionType.cup,
                homeTeamId: 9,
                awayTeamId: 33,
                homeTeamName: 'Manchester City',
                awayTeamName: 'Norwich City',
                awayTeamLogo: 'https://cdn.example/norwich.png',
                status: FixtureStatus.upcoming,
                roundName: 'Third Round',
                startingAt: '2026-09-17 18:30:00',
              ),
            ]
          : const [],
    );

    await tester.pumpWidget(_app(repository, teamId: 9));
    await tester.pump();
    await tester.pump();

    expect(find.text('Norwich City'), findsOneWidget);
    expect(find.text('Unknown Team'), findsNothing);
  });

  testWidgets('ignores an old response after switching teams', (tester) async {
    final pending = <(int, FixtureStatus), Completer<List<Fixture>>>{};
    final repository = _ControlledFixtureRepository(
      (teamId, status, _) {
        final key = (teamId, status!);
        return pending.putIfAbsent(key, Completer.new).future;
      },
    );

    await tester.pumpWidget(_app(repository, teamId: 9));
    await tester.pumpWidget(_app(repository, teamId: 8));

    for (final status in [
      FixtureStatus.past,
      FixtureStatus.live,
      FixtureStatus.upcoming,
    ]) {
      pending[(9, status)]!.complete([_fixture(9, status)]);
    }
    await tester.pump();

    expect(find.byKey(const ValueKey('matches-loading')), findsOneWidget);

    for (final status in [
      FixtureStatus.past,
      FixtureStatus.live,
      FixtureStatus.upcoming,
    ]) {
      pending[(8, status)]!.complete(const []);
    }
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('matches-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stacks section headers without delayed entrance animations',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _ControlledFixtureRepository(
      (_, status, __) async => List.generate(
        6,
        (index) => _fixture(status!.index * 100 + index + 1, status),
      ),
    );

    await tester.pumpWidget(_app(repository, teamId: 9));
    await tester.pump();
    await tester.pump();

    final scroll = tester.widget<CustomScrollView>(
      find.byKey(const ValueKey('matches-scroll')),
    );
    final controller = scroll.controller!;

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('matches-upcoming-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('matches-live-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('matches-past-header')),
      findsOneWidget,
    );
    final fade = find.byKey(const ValueKey('matches-top-fade'));
    expect(fade, findsOneWidget);
    expect(tester.getSize(fade).height, 56);
    expect(
      tester.getTopLeft(fade).dy,
      closeTo(
        tester.getTopLeft(find.byKey(const ValueKey('matches-scroll'))).dy,
        0.1,
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('matches-header-stack')),
        matching: find.byType(AnimatedSlide),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('matches-header-stack')),
        matching: find.byType(AnimatedOpacity),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports a downward pull after reaching the first upcoming match',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var topPulls = 0;
    final repository = MockFixtureRepository(
      fixtures: [
        for (var index = 1; index <= 8; index++)
          _fixture(
            index,
            FixtureStatus.upcoming,
            kickoff: DateTime(2026, 1, index),
          ),
      ],
    );

    await tester.pumpWidget(
      _app(
        repository,
        teamId: 9,
        onTopOverscroll: () => topPulls++,
      ),
    );
    await tester.pumpAndSettle();

    final scrollFinder = find.byKey(const ValueKey('matches-scroll'));
    final controller =
        tester.widget<CustomScrollView>(scrollFinder).controller!;
    expect(controller.position.minScrollExtent, lessThan(0));

    controller.jumpTo(controller.position.minScrollExtent);
    await tester.pump();
    await tester.drag(scrollFinder, const Offset(0, 120));
    await tester.pump();

    expect(topPulls, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}

Finder _cardSurface(int fixtureId) => find
    .descendant(
      of: find.byKey(ValueKey('team-fixture-card-$fixtureId')),
      matching: find.byType(DecoratedBox),
    )
    .first;

Widget _app(MockFixtureRepository repository,
    {required int teamId,
    Locale locale = const Locale('en'),
    VoidCallback? onTopOverscroll}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationDelegates,
    home: Scaffold(
      body: MatchesTab(
        team: {'id': teamId},
        fixtureRepository: repository,
        onTopOverscroll: onTopOverscroll,
      ),
    ),
  );
}

Fixture _fixture(
  int fixtureId,
  FixtureStatus status, {
  CompetitionType competitionType = CompetitionType.league,
  String? roundName = '1',
  String? stageName,
  String? leg,
  DateTime? kickoff,
}) {
  return Fixture(
    fixtureId: fixtureId,
    competitionId: 8,
    seasonId: 25583,
    competitionType: competitionType,
    homeTeamId: 9,
    awayTeamId: 8,
    status: status,
    roundName: roundName,
    stageName: stageName,
    leg: leg,
    startingAt: kickoff?.toIso8601String() ?? '2026-09-12 15:00:00',
  );
}

class _ControlledFixtureRepository extends MockFixtureRepository {
  _ControlledFixtureRepository(this._loader) : super(fixtures: const []);

  final Future<List<Fixture>> Function(
    int teamId,
    FixtureStatus? status,
    int limit,
  ) _loader;

  @override
  Future<List<Fixture>> loadForTeam(
    int teamId, {
    FixtureStatus? status,
    DateTime? start,
    DateTime? end,
    int limit = 50,
    int offset = 0,
  }) {
    return _loader(teamId, status, limit);
  }
}
