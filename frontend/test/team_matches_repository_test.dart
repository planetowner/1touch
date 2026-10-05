import 'support/app_catalog.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team_overview.dart';
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
      find.byKey(const ValueKey('matches-past-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('matches-live-header')),
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
    expect(fixtureCard.padding, const EdgeInsets.all(16));
    expect(
      (fixtureCard.decoration as BoxDecoration).boxShadow,
      app_style.lightModeCardShadows,
    );

    tester.view.physicalSize = const Size(430, 932);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sorts unsorted API pages by kickoff then fixture ID',
      (tester) async {
    final repository = _ControlledFixtureRepository(
      (_, status, __) async => switch (status) {
        FixtureStatus.past => [
            _fixture(12, FixtureStatus.past, kickoff: DateTime(2026, 1, 2)),
            _fixture(11, FixtureStatus.past, kickoff: DateTime(2026, 1, 2)),
            _fixture(10, FixtureStatus.past, kickoff: DateTime(2026, 1, 1)),
          ],
        FixtureStatus.live => [
            _fixture(13, FixtureStatus.live, kickoff: DateTime(2026, 1, 3)),
          ],
        FixtureStatus.upcoming => [
            _fixture(22, FixtureStatus.upcoming, kickoff: DateTime(2026, 1, 5)),
            _fixture(21, FixtureStatus.upcoming, kickoff: DateTime(2026, 1, 4)),
            _fixture(20, FixtureStatus.upcoming, kickoff: DateTime(2026, 1, 4)),
          ],
        _ => const <Fixture>[],
      },
    );

    await tester.pumpWidget(_app(repository, teamId: 9));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<CustomScrollView>(find.byKey(const ValueKey('matches-scroll')))
        .controller!;

    controller.jumpTo(controller.position.minScrollExtent);
    await tester.pumpAndSettle();
    for (final (earlier, later) in [(10, 11), (11, 12)]) {
      expect(
          tester
              .getTopLeft(find.byKey(ValueKey('team-fixture-card-$earlier')))
              .dy,
          lessThan(tester
              .getTopLeft(find.byKey(ValueKey('team-fixture-card-$later')))
              .dy));
    }

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    for (final (earlier, later) in [(20, 21), (21, 22)]) {
      expect(
          tester
              .getTopLeft(find.byKey(ValueKey('team-fixture-card-$earlier')))
              .dy,
          lessThan(tester
              .getTopLeft(find.byKey(ValueKey('team-fixture-card-$later')))
              .dy));
    }
    expect(tester.takeException(), isNull);
  });

  for (final hasLive in [false, true]) {
    testWidgets(
        'opens near the current match and scrolls from oldest to newest, live=$hasLive',
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
      final entryId = hasLive ? 201 : 202;
      if (hasLive) {
        expect(
            tester
                .getTopLeft(find.byKey(ValueKey('team-fixture-card-$entryId')))
                .dy,
            closeTo(tester.getTopLeft(scroll).dy, 0.1));
        expect(controller.offset, 0);
      } else {
        final boundary = find.byKey(const ValueKey('matches-upcoming-divider'));
        expect(tester.getCenter(boundary).dy,
            closeTo(tester.getCenter(scroll).dy, 1));
        for (final id in [199, 200, 202, 203]) {
          expect(find.byKey(ValueKey('team-fixture-card-$id')).hitTestable(),
              findsOneWidget);
        }
        expect(controller.offset, 0);
      }
      expect(
          tester
              .widget<ShaderMask>(
                  find.byKey(const ValueKey('matches-top-fade')))
              .blendMode,
          BlendMode.dstIn);
      expect(controller.position.minScrollExtent, lessThan(0));

      controller.jumpTo(-300);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('team-fixture-card-200')).hitTestable(),
          findsOneWidget);

      controller.jumpTo(controller.position.minScrollExtent);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('team-fixture-card-1')).hitTestable(),
          findsOneWidget);
      expect(
          tester
              .widget<ShaderMask>(
                  find.byKey(const ValueKey('matches-top-fade')))
              .blendMode,
          BlendMode.dst);

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      // Sticky headers grow after the jump, changing the viewport extent.
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('team-fixture-card-401')).hitTestable(),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('centers two past and two upcoming matches at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = MockFixtureRepository(fixtures: [
        for (var index = 1; index <= 10; index++)
          _fixture(index, FixtureStatus.past,
              kickoff: DateTime(2026, 1, index)),
        for (var index = 11; index <= 20; index++)
          _fixture(index, FixtureStatus.upcoming,
              kickoff: DateTime(2026, 1, index)),
      ]);

      await tester.pumpWidget(_app(repository, teamId: 9));
      await tester.pumpAndSettle();

      final scroll = find.byKey(const ValueKey('matches-scroll'));
      final boundary = find.byKey(const ValueKey('matches-upcoming-divider'));
      expect(tester.getCenter(boundary).dy,
          closeTo(tester.getCenter(scroll).dy, 1));
      for (final id in [9, 10, 11, 12]) {
        expect(find.byKey(ValueKey('team-fixture-card-$id')).hitTestable(),
            findsOneWidget);
      }
      final controller = tester.widget<CustomScrollView>(scroll).controller!;
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final pastLabel = find.descendant(
        of: find.byKey(const ValueKey('matches-past-header')),
        matching: find.text('PAST'),
      );
      final upcomingLabel = find.descendant(
        of: find.byKey(const ValueKey('matches-upcoming-header')),
        matching: find.text('UPCOMING'),
      );
      expect(
        tester.getTopLeft(upcomingLabel).dy -
            tester.getBottomLeft(pastLabel).dy,
        closeTo(24, 0.1),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no-live boundary is centered on the first loaded frame',
      (tester) async {
    final pending = {
      for (final status in [
        FixtureStatus.past,
        FixtureStatus.live,
        FixtureStatus.upcoming,
      ])
        status: Completer<List<Fixture>>(),
    };
    final repository = _ControlledFixtureRepository(
      (_, status, __) => pending[status]!.future,
    );

    await tester.pumpWidget(_app(repository, teamId: 9));
    pending[FixtureStatus.past]!.complete([
      for (var index = 1; index <= 10; index++)
        _fixture(index, FixtureStatus.past, kickoff: DateTime(2026, 1, index)),
    ]);
    pending[FixtureStatus.live]!.complete(const []);
    pending[FixtureStatus.upcoming]!.complete([
      for (var index = 11; index <= 20; index++)
        _fixture(index, FixtureStatus.upcoming,
            kickoff: DateTime(2026, 1, index)),
    ]);
    await tester.pump();

    final scroll = find.byKey(const ValueKey('matches-scroll'));
    final boundary = find.byKey(const ValueKey('matches-upcoming-divider'));
    expect(scroll, findsOneWidget);
    expect(
        tester.getCenter(boundary).dy, closeTo(tester.getCenter(scroll).dy, 1));
    expect(tester.widget<CustomScrollView>(scroll).controller!.offset, 0);
    for (final id in [9, 10, 11, 12]) {
      expect(find.byKey(ValueKey('team-fixture-card-$id')).hitTestable(),
          findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  for (final upcomingCount in [0, 1]) {
    testWidgets(
        'opens with $upcomingCount upcoming matches near the latest available match',
        (tester) async {
      final repository = MockFixtureRepository(fixtures: [
        _fixture(1, FixtureStatus.past),
        if (upcomingCount == 1) _fixture(2, FixtureStatus.upcoming),
      ]);
      await tester.pumpWidget(_app(repository, teamId: 9));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ShaderMask>(find.byKey(const ValueKey('matches-top-fade')))
            .blendMode,
        BlendMode.dst,
      );
      final first = find
          .byKey(ValueKey('team-fixture-card-${upcomingCount == 1 ? 2 : 1}'));
      expect(first.hitTestable(), findsOneWidget);
      if (upcomingCount == 0) {
        expect(
            tester.getTopLeft(first).dy,
            closeTo(
                tester
                    .getTopLeft(find.byKey(const ValueKey('matches-scroll')))
                    .dy,
                0.1));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('past-only schedule opens at the newest past match',
      (tester) async {
    final repository = MockFixtureRepository(fixtures: [
      for (var index = 1; index <= 8; index++)
        _fixture(index, FixtureStatus.past, kickoff: DateTime(2026, 1, index)),
    ]);
    await tester.pumpWidget(_app(repository, teamId: 9));
    await tester.pumpAndSettle();

    final scroll = find.byKey(const ValueKey('matches-scroll'));
    final controller = tester.widget<CustomScrollView>(scroll).controller!;
    expect(
        tester.getTopLeft(find.byKey(const ValueKey('team-fixture-card-8'))).dy,
        closeTo(tester.getTopLeft(scroll).dy, 0.1));
    expect(controller.position.minScrollExtent, lessThan(0));

    controller.jumpTo(controller.position.minScrollExtent);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('team-fixture-card-1')).hitTestable(),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
        expect(labels.every((text) => text.overflow == TextOverflow.visible),
            isTrue);
        expect(
          find.ancestor(of: dateTime, matching: find.byType(FittedBox)),
          findsOneWidget,
        );
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

  testWidgets('stacks section headers with a smooth entrance animation',
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
      find.byKey(const ValueKey('matches-past-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('matches-live-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('matches-upcoming-header')),
      findsOneWidget,
    );
    final upcomingTransition = find.byKey(
      const ValueKey('matches-upcoming-header-transition'),
    );
    Finder upcomingFade() => find
        .ancestor(
          of: find.byKey(const ValueKey('matches-upcoming-header')),
          matching: find.byType(FadeTransition),
        )
        .first;
    expect(upcomingTransition, findsOneWidget);
    expect(
      tester.widget<FadeTransition>(upcomingFade()).opacity.value,
      lessThan(1),
    );
    expect(
      tester.widget<FadeTransition>(upcomingFade()).opacity.value,
      greaterThanOrEqualTo(.72),
    );

    await tester.pump(const Duration(milliseconds: 220));
    expect(tester.widget<FadeTransition>(upcomingFade()).opacity.value, 1);
    Finder headerLabel(String section, String label) => find.descendant(
          of: find.byKey(ValueKey('matches-$section-header')),
          matching: find.text(label),
        );
    expect(
      tester.getTopLeft(headerLabel('live', 'LIVE')).dy -
          tester.getBottomLeft(headerLabel('past', 'PAST')).dy,
      closeTo(24, 0.1),
    );
    expect(
      tester.getTopLeft(headerLabel('upcoming', 'UPCOMING')).dy -
          tester.getBottomLeft(headerLabel('live', 'LIVE')).dy,
      closeTo(24, 0.1),
    );

    controller.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('matches-upcoming-header')),
      findsOneWidget,
    );
    expect(
      tester.widget<FadeTransition>(upcomingFade()).opacity.value,
      inExclusiveRange(.72, 1),
    );
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('matches-upcoming-header')),
      findsNothing,
    );

    final fade = find.byKey(const ValueKey('matches-top-fade'));
    expect(fade, findsOneWidget);
    expect(tester.widget<ShaderMask>(fade).blendMode, BlendMode.dstIn);
    expect(tester.getRect(fade),
        tester.getRect(find.byKey(const ValueKey('matches-scroll'))));
    expect(
      tester.getTopLeft(fade).dy,
      closeTo(
        tester.getTopLeft(find.byKey(const ValueKey('matches-scroll'))).dy,
        0.1,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports a downward pull after reaching the oldest match',
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
    expect(controller.position.minScrollExtent, 0);

    controller.jumpTo(controller.position.minScrollExtent);
    await tester.pump();
    await tester.drag(scrollFinder, const Offset(0, 120));
    await tester.pump();

    expect(topPulls, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('header requests use direction threshold and bottom hysteresis',
      (tester) async {
    final requests = <bool>[];
    final repository = MockFixtureRepository(fixtures: [
      for (var index = 1; index <= 40; index++)
        _fixture(index, FixtureStatus.upcoming,
            kickoff: DateTime(2026, 1, index)),
    ]);
    await tester.pumpWidget(_app(
      repository,
      teamId: 9,
      onHeaderVisibilityChanged: requests.add,
    ));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<CustomScrollView>(find.byKey(const ValueKey('matches-scroll')))
        .controller!;
    expect(controller.position.maxScrollExtent, greaterThan(500));
    expect(requests, isEmpty);

    controller.jumpTo(20);
    await tester.pump();
    expect(requests, isEmpty);
    controller.jumpTo(40);
    await tester.pump();
    expect(requests, [false]);

    controller.jumpTo(38);
    await tester.pump();
    expect(requests, [false]);
    controller.jumpTo(5);
    await tester.pump();
    expect(requests, [false, true]);

    final bottom = controller.position.maxScrollExtent;
    controller.jumpTo(bottom - 200);
    await tester.pump();
    expect(requests.last, isFalse);
    controller.jumpTo(bottom - 120);
    await tester.pump();
    expect(requests.last, isTrue);
    final countAtBottom = requests.length;
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(requests.length, countAtBottom);
    controller.jumpTo(controller.position.maxScrollExtent - 300);
    await tester.pump();
    expect(requests.length, countAtBottom);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(MockFixtureRepository repository,
    {required int teamId,
    Locale locale = const Locale('en'),
    VoidCallback? onTopOverscroll,
    ValueChanged<bool>? onHeaderVisibilityChanged}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(
      body: MatchesTab(
        team: TeamOverview(
          id: teamId,
          name: 'Team $teamId',
          shortName: 'T$teamId',
          imagePath: '',
        ),
        fixtureRepository: repository,
        onTopOverscroll: onTopOverscroll,
        onHeaderVisibilityChanged: onHeaderVisibilityChanged,
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
