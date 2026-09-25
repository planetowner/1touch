import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/injuries/team_injury_repository.dart';
import 'package:onetouch/data/teams/team_feature_unavailable_exception.dart';
import 'package:onetouch/features/TeamScreenFeatures.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/team_injury_report.dart';

void main() {
  Widget buildSubject({
    required int teamId,
    required TeamInjuryRepository repository,
    VoidCallback? onUnavailable,
    Locale? locale,
    ThemeData? theme,
  }) {
    return MaterialApp(
      theme: theme ?? whitetheme,
      locale: locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: InjuryStatus(
            teams: <String, dynamic>{'id': teamId},
            repository: repository,
            onUnavailable: onUnavailable,
          ),
        ),
      ),
    );
  }

  testWidgets(
      'renders the return estimate and unknown date for each injury',
      (tester) => withClock(Clock.fixed(DateTime(2026, 9, 24)), () async {
            final result = Completer<TeamInjuryReport>();
            final repository = _TestTeamInjuryRepository((_) => result.future);
            addTearDown(repository.dispose);

            await tester
                .pumpWidget(buildSubject(teamId: 83, repository: repository));

            expect(
                find.byKey(const ValueKey('injury-loading')), findsOneWidget);

            result.complete(_report(teamId: 83));
            await tester.pumpAndSettle();

            expect(find.text('Injured Player'), findsOneWidget);
            final jersey = find.byKey(const ValueKey('injury-jersey-1001'));
            final playerName = find.text('Injured Player');
            expect(find.text('10'), findsOneWidget);
            expect(
              tester.widget<Text>(jersey).style,
              Heading5.style.copyWith(fontWeight: FontWeight.w400),
            );
            expect(tester.widget<Text>(playerName).style, Heading5.style);
            expect(
              tester.getTopLeft(jersey).dx,
              lessThan(tester.getTopLeft(playerName).dx),
            );
            expect(find.text('Hamstring · Expected back in 6 weeks'),
                findsOneWidget);
            expect(find.text('Knock · No return date yet'), findsOneWidget);
            expect(find.byKey(const ValueKey('injury-5001')), findsOneWidget);
            expect(find.byKey(const ValueKey('injury-5002')), findsOneWidget);
          }));

  testWidgets('player picture circle uses light grey in dark mode',
      (tester) async {
    final repository = _TestTeamInjuryRepository(
      (teamId) async => _report(teamId: teamId),
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      buildSubject(
        teamId: 83,
        repository: repository,
        theme: darktheme,
      ),
    );
    await tester.pumpAndSettle();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(avatar.backgroundColor, AppPalette.lightGrey);
    expect(tester.takeException(), isNull);
  });

  for (final translation in [
    (
      locale: const Locale('en'),
      name: 'Hamstring injury',
      expected: 'Expected back in 6 weeks',
      unknown: 'No return date yet',
    ),
    (
      locale: const Locale('ko'),
      name: '햄스트링 부상',
      expected: '6주 뒤 복귀할 예정이에요',
      unknown: '언제 복귀할지 아직 몰라요',
    ),
    (
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      name: '腿后肌受伤',
      expected: '预计6周后复出',
      unknown: '暂时还不知道什么时候复出',
    ),
    (
      locale: const Locale('ja'),
      name: 'ハムストリングの負傷',
      expected: '6週間後に復帰する予定です',
      unknown: 'いつ復帰できるかはまだわかりません',
    ),
  ]) {
    testWidgets(
        'shows the ${translation.locale.languageCode} injury and return labels',
        (tester) => withClock(Clock.fixed(DateTime(2026, 9, 24)), () async {
              final repository = _TestTeamInjuryRepository(
                (teamId) async => TeamInjuryReport(
                  teamId: teamId,
                  seasonId: 25659,
                  players: [
                    InjuredTeamPlayer(
                      playerId: 1001,
                      playerName: 'Injured Player',
                      injuries: [
                        TeamPlayerInjury(
                          sidelineId: 5001,
                          typeId: 535,
                          typeName: 'Hamstring injury',
                          startDate: DateTime.utc(2026, 9, 1),
                          endDate: DateTime.utc(2026, 11, 5),
                        ),
                        const TeamPlayerInjury(
                          sidelineId: 5002,
                          typeId: 535,
                          typeName: 'Hamstring injury',
                        ),
                        const TeamPlayerInjury(
                          sidelineId: 5003,
                          typeId: 999999,
                          typeName: 'New Injury',
                        ),
                      ],
                    ),
                  ],
                ),
              );
              addTearDown(repository.dispose);

              await tester.pumpWidget(
                buildSubject(
                  teamId: 83,
                  repository: repository,
                  locale: translation.locale,
                ),
              );
              await tester.pumpAndSettle();

              expect(find.text('${translation.name} · ${translation.expected}'),
                  findsOneWidget);
              expect(find.text('${translation.name} · ${translation.unknown}'),
                  findsOneWidget);
              expect(find.text('New Injury · ${translation.unknown}'),
                  findsOneWidget);
              expect(tester.takeException(), isNull);
            }));
  }

  testWidgets(
      'keeps reported injuries and players after their end dates pass',
      (tester) => withClock(Clock.fixed(DateTime(2026, 9, 24)), () async {
            final expired = TeamPlayerInjury(
              sidelineId: 6001,
              typeId: 535,
              typeName: 'Hamstring injury',
              endDate: DateTime.utc(2026, 9, 23),
            );
            final report = TeamInjuryReport(
              teamId: 83,
              seasonId: 25659,
              players: [
                InjuredTeamPlayer(
                  playerId: 1001,
                  playerName: 'Expired Player',
                  injuries: [expired],
                ),
                InjuredTeamPlayer(
                  playerId: 1002,
                  playerName: 'Still Listed',
                  injuries: [
                    expired,
                    TeamPlayerInjury(
                      sidelineId: 6002,
                      typeId: 531,
                      typeName: 'Knock',
                      endDate: DateTime.utc(2026, 9, 24),
                    ),
                    const TeamPlayerInjury(
                      sidelineId: 6003,
                      typeId: 535,
                      typeName: 'Hamstring injury',
                    ),
                  ],
                ),
              ],
            );
            final repository = _TestTeamInjuryRepository((_) async => report);
            addTearDown(repository.dispose);

            await tester
                .pumpWidget(buildSubject(teamId: 83, repository: repository));
            await tester.pumpAndSettle();

            expect(find.text('Expired Player'), findsOneWidget);
            expect(find.byKey(const ValueKey('injury-6001')), findsNWidgets(2));
            expect(find.text('Still Listed'), findsOneWidget);
            expect(find.text('Knock · Expected back today'), findsOneWidget);
            expect(find.text('Hamstring injury · No return date yet'),
                findsNWidgets(3));
            expect(report.players, hasLength(2));
            expect(report.players.last.injuries, hasLength(3));
          }));

  testWidgets(
      'removes players only when a refreshed report no longer lists them',
      (tester) async {
    var today = DateTime(2026, 9, 24);
    await withClock(Clock(() => today), () async {
      final repository = _TestTeamInjuryRepository((teamId) async =>
          TeamInjuryReport(teamId: teamId, seasonId: 25659, players: [
            InjuredTeamPlayer(
              playerId: 1001,
              playerName: 'Injured Player',
              injuries: [
                TeamPlayerInjury(
                  sidelineId: 7001,
                  typeId: 535,
                  typeName: 'Hamstring injury',
                  endDate: DateTime.utc(2026, 9, 24),
                ),
              ],
            ),
          ]));
      addTearDown(repository.dispose);

      await tester.pumpWidget(buildSubject(teamId: 83, repository: repository));
      await tester.pumpAndSettle();
      expect(find.text('Injured Player'), findsOneWidget);

      today = DateTime(2026, 9, 25);
      await tester.pumpWidget(buildSubject(teamId: 83, repository: repository));
      await tester.pumpAndSettle();
      expect(find.text('Injured Player'), findsOneWidget);
      expect(
          find.text('Hamstring injury · No return date yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('injury-empty')), findsNothing);

      final refreshedRepository = _TestTeamInjuryRepository((teamId) async =>
          TeamInjuryReport(teamId: teamId, seasonId: 25659, players: const []));
      addTearDown(refreshedRepository.dispose);
      await tester.pumpWidget(
          buildSubject(teamId: 83, repository: refreshedRepository));
      await tester.pumpAndSettle();
      expect(find.text('Injured Player'), findsNothing);
      expect(find.byKey(const ValueKey('injury-empty')), findsOneWidget);
    });
  });

  testWidgets('injured player opens the player page', (tester) async {
    final repository = _TestTeamInjuryRepository(
      (teamId) async => _report(teamId: teamId),
    );
    addTearDown(repository.dispose);
    final router = GoRouter(
      initialLocation: '/team',
      routes: [
        GoRoute(
          path: '/team',
          builder: (_, __) => Scaffold(
            body: InjuryStatus(
              teams: const <String, dynamic>{'id': 83},
              repository: repository,
            ),
          ),
        ),
        GoRoute(
          path: '/players/:id',
          builder: (_, state) => Text('Player ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('injured-player-1001')));
    await tester.pumpAndSettle();

    expect(find.text('Player 1001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the API empty state', (tester) async {
    final repository = _TestTeamInjuryRepository(
      (teamId) async => TeamInjuryReport(
        teamId: teamId,
        seasonId: 25659,
        players: const [],
      ),
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 83, repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('injury-empty')), findsOneWidget);
    expect(find.text('No current injuries'), findsOneWidget);
  });

  testWidgets('reports and hides an unavailable feature', (tester) async {
    var unavailableCalls = 0;
    final repository = _TestTeamInjuryRepository(
      (teamId) async => throw TeamFeatureUnavailableException(
        teamId: teamId,
        feature: 'Injuries',
      ),
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      buildSubject(
        teamId: 83,
        repository: repository,
        onUnavailable: () => unavailableCalls += 1,
      ),
    );
    await tester.pump();

    expect(unavailableCalls, 1);
    expect(find.byKey(const ValueKey('injury-unavailable')), findsOneWidget);
    expect(find.byKey(const ValueKey('injury-error')), findsNothing);
  });

  testWidgets('shows an error and retries the repository request',
      (tester) async {
    var attempt = 0;
    final repository = _TestTeamInjuryRepository((teamId) async {
      attempt += 1;
      if (attempt == 1) throw StateError('temporary failure');
      return TeamInjuryReport(
        teamId: teamId,
        seasonId: 25659,
        players: const [],
      );
    });
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 83, repository: repository));
    await tester.pump();

    expect(find.byKey(const ValueKey('injury-error')), findsOneWidget);

    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();

    expect(attempt, 2);
    expect(find.byKey(const ValueKey('injury-empty')), findsOneWidget);
  });

  testWidgets('ignores a stale result after the selected team changes',
      (tester) async {
    final firstResult = Completer<TeamInjuryReport>();
    final secondResult = Completer<TeamInjuryReport>();
    final repository = _TestTeamInjuryRepository(
      (teamId) => teamId == 83 ? firstResult.future : secondResult.future,
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 83, repository: repository));
    await tester.pumpWidget(buildSubject(teamId: 19, repository: repository));

    firstResult.complete(_report(teamId: 83, playerName: 'Stale Player'));
    await tester.pump();

    expect(find.text('Stale Player'), findsNothing);
    expect(find.byKey(const ValueKey('injury-loading')), findsOneWidget);

    secondResult.complete(_report(teamId: 19, playerName: 'Current Player'));
    await tester.pumpAndSettle();

    expect(find.text('Stale Player'), findsNothing);
    expect(find.text('Current Player'), findsOneWidget);
  });
}

TeamInjuryReport _report({
  required int teamId,
  String playerName = 'Injured Player',
}) {
  return TeamInjuryReport(
    teamId: teamId,
    seasonId: 25659,
    players: [
      InjuredTeamPlayer(
        playerId: 1001,
        playerName: playerName,
        jerseyNumber: 10,
        injuries: [
          TeamPlayerInjury(
            sidelineId: 5001,
            typeId: 2,
            typeName: 'Hamstring',
            startDate: DateTime.utc(2026, 9, 1),
            endDate: DateTime.utc(2026, 11, 5),
          ),
          const TeamPlayerInjury(
            sidelineId: 5002,
            typeId: 3,
            typeName: 'Knock',
          ),
        ],
      ),
    ],
  );
}

class _TestTeamInjuryRepository implements TeamInjuryRepository {
  _TestTeamInjuryRepository(this._loader);

  final Future<TeamInjuryReport> Function(int teamId) _loader;
  final ValueNotifier<Map<int, TeamInjuryReport>> _cachedReports =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<int, TeamInjuryReport>> get cachedReports =>
      _cachedReports;

  @override
  TeamInjuryReport? cachedForTeam(int teamId) => _cachedReports.value[teamId];

  @override
  Future<TeamInjuryReport> loadForTeam(int teamId) async {
    final cached = cachedForTeam(teamId);
    if (cached != null) return cached;

    final report = await _loader(teamId);
    _cachedReports.value = Map.unmodifiable({
      ..._cachedReports.value,
      teamId: report,
    });
    return report;
  }

  void dispose() => _cachedReports.dispose();
}
