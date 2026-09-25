import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/catalog/football_names.dart';
import 'package:onetouch/features/home/screen/home_screen_features.dart';
import 'package:onetouch/features/match_info/match_info_features.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/football_names_loader.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team_overview.dart';
import 'support/app_catalog.dart';

const _translations = {
  'ko': ['FC 바르셀로나', '바르셀로나', '헤타페', '라리가', 'L. 메시'],
  'ja': ['FCバルセロナ', 'FCバルセロナ', 'ヘタフェ', 'ラ・リーガ', 'L・メッシ'],
  'zh': ['巴塞罗那足球俱乐部', '巴塞罗那足球俱乐部', '赫塔费', '西甲联赛', 'L·梅西'],
};

http.Response _response(String locale) {
  final values = _translations[locale]!;
  return http.Response(
      jsonEncode({
        'teams': {'83': values[0], '106': values[2]},
        'team_short_names': locale == 'ko' ? {'83': values[1]} : {},
        'players': {'184798': 'Full Messi'},
        'player_short_names': {'184798': values[4]},
        'competitions': {'564': values[3]},
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

ApiClient _client(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
        client: MockClient(handler),
        baseUri: Uri.parse('https://example.test/v1/'),
        requestHeaders: () => {});

void main() {
  setUpAppCatalog();

  testWidgets(
      'home names, competitions and scorers follow language; codes stay English',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final requests = <String>[];
    final api = _client((request) async {
      final locale = request.url.pathSegments[2];
      requests.add(locale);
      return _response(locale);
    });
    addTearDown(api.close);
    final repository = FootballNamesRepository(api);
    const next = Fixture(
        fixtureId: 1,
        seasonId: 1,
        competitionId: 564,
        homeTeamId: 83,
        awayTeamId: 106,
        competitionType: CompetitionType.league,
        status: FixtureStatus.upcoming,
        roundName: '8',
        startingAt: null);
    const last = Fixture(
        fixtureId: 2,
        seasonId: 1,
        competitionId: 564,
        homeTeamId: 676,
        awayTeamId: 83,
        competitionType: CompetitionType.league,
        status: FixtureStatus.past,
        roundName: '7',
        startingAt: null,
        homeScore: 1,
        awayScore: 3);
    for (final language in ['ko', 'ja', 'zh', 'ko']) {
      await tester.pumpWidget(MaterialApp(
        locale: Locale(language),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        builder: (context, child) => FootballNamesLoader(
            repository: repository, enabled: true, child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
          FavoriteTeamCard(
              team: TeamOverview(
                  id: 83,
                  name: 'FC Barcelona',
                  shortName: 'BAR',
                  imagePath: 'https://example.test/team.png',
                  nextMatch: next,
                  lastMatch: last)),
          const MatchEventsSection(events: [
            {
              'playerId': 184798,
              'player': 'Lionel Messi',
              'minute': "12'",
              'team': 'home',
              'type': 'goal'
            },
            {
              'playerId': 184798,
              'player': 'Lionel Messi',
              'minute': "24'",
              'team': 'home',
              'type': 'goal'
            },
          ]),
        ]))),
      ));
      await tester.pumpAndSettle();
      final values = _translations[language]!;
      expect(find.text(values[0]), findsWidgets);
      expect(find.text(values[1]), findsWidgets);
      expect(find.text(values[2]), findsOneWidget);
      expect(find.textContaining(values[3]), findsWidgets);
      expect(find.text(values[4]), findsOneWidget);
      expect(find.text("12',"), findsOneWidget);
      expect(find.text("24'"), findsOneWidget);
      expect(find.text('SEV'), findsOneWidget);
      expect(find.text('BAR'), findsOneWidget);
      expect(find.text('FC Barcelona'), findsNothing);
      expect(find.text('Getafe'), findsNothing);
      expect(tester.takeException(), isNull);
    }
    expect(requests, ['ko', 'ja', 'zh']);
  });

  testWidgets('waits for login, retains page state and retries an API failure',
      (tester) async {
    final session = AuthSession();
    addTearDown(session.dispose);
    final pending = Completer<http.Response>();
    var calls = 0;
    final api =
        _client((_) async => ++calls == 1 ? pending.future : _response('ko'));
    addTearDown(api.close);
    final repository = FootballNamesRepository(api);
    final pageKey = GlobalKey<_CounterState>();
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ko'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      builder: (context, child) => ListenableBuilder(
          listenable: session,
          builder: (context, _) => FootballNamesLoader(
              repository: repository,
              enabled: session.isAuthenticated,
              child: child!)),
      home: _Counter(key: pageKey),
    ));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('0'));
    await tester.pump();
    final originalState = pageKey.currentState;
    session.establish('session');
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(pageKey.currentState, same(originalState));
    pending.complete(http.Response('{}', 503));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-error-500-action')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-error-500-action')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('FC 바르셀로나'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(pageKey.currentState, same(originalState));
    expect(tester.takeException(), isNull);
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
          body: Column(children: [
        Text(teamNameLabel(context, 83, 'FC Barcelona')),
        TextButton(
            onPressed: () => setState(() => count++), child: Text('$count')),
      ]));
}
