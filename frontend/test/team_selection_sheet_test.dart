import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/catalog/football_names.dart';
import 'package:onetouch/data/standings/api/api_standing_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/features/HomeScreenFeatures.dart';
import 'package:onetouch/l10n/app_localizations.dart';

import 'support/app_catalog.dart';

void main() {
  setUpAppCatalog();

  testWidgets(
      'following picker shows league ranks and keeps the favorite star separate from selection',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    const positions = {83: 1, 3468: 2, 9: 1, 503: 2};
    final standings = ApiStandingRepository(
        api: ApiClient(
      baseUri: Uri.parse('https://example.com/v1/'),
      requestHeaders: () => {},
      client: MockClient((request) async {
        requests.add(request);
        final competitionId = int.parse(request.url.pathSegments[2]);
        final seasonId = int.parse(request.url.queryParameters['season_id']!);
        final ids = positions.keys.where((id) {
          final league = teamCompetitionContextResolver.resolve(id)!;
          return league.competitionId == competitionId &&
              league.seasonId == seasonId;
        });
        expect(ids, isNotEmpty);
        return http.Response(
            jsonEncode({
              'competition_id': competitionId,
              'season_id': seasonId,
              'rows': [
                for (final id in ids)
                  {
                    'team_id': id,
                    'team_name': teamRepository.requireById(id).name,
                    'team_logo': null,
                    'position': positions[id],
                    'rank_delta': null,
                    'matches_played': 0,
                    'won': 0,
                    'draw': 0,
                    'lost': 0,
                    'goals_for': 0,
                    'goals_against': 0,
                    'goal_diff': 0,
                    'points': 0,
                    'last5_form': <String>[],
                  }
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    ));
    int? switchedTeamId;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ko'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      theme: app_style.darktheme,
      builder: (_, child) => FootballNamesScope(
        names: const FootballNames(
          teams: {
            83: 'FC 바르셀로나',
            3468: '레알 마드리드',
            9: '맨체스터 시티',
            503: '바이에른 뮌헨'
          },
          competitions: {564: '라리가', 8: '프리미어리그', 82: '분데스리가'},
        ),
        child: child!,
      ),
      home: Builder(
          builder: (context) => Scaffold(
                  body: TextButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  builder: (_) => TeamSelectionSheet(
                    initialTeamId: 9,
                    favoriteTeamId: 83,
                    followingTeams: [
                      for (final id in positions.keys)
                        teamRepository.requireById(id)
                    ],
                    standingsRepository: standings,
                    onSwitch: (teamId) {
                      switchedTeamId = teamId;
                    },
                  ),
                ),
                child: const Text('Open'),
              ))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('팔로잉 팀'), findsOneWidget);
    expect(find.text('선택한 팀으로 바꿔요'), findsOneWidget);
    expect(find.text('라리가 1위'), findsOneWidget);
    expect(find.text('라리가 2위'), findsOneWidget);
    expect(find.text('프리미어리그 1위'), findsOneWidget);
    expect(standings.findForTeam(82, 503, seasonId: 28321)?.position, 2);
    await tester.ensureVisible(find.byKey(const ValueKey('team-selection-503')));
    await tester.pumpAndSettle();
    expect(find.text('분데스리가 2위'), findsOneWidget);
    expect(requests, hasLength(3));

    final favorite = find.byKey(const ValueKey('team-selection-83'));
    await tester.ensureVisible(favorite);
    await tester.pumpAndSettle();
    final viewed = find.byKey(const ValueKey('team-selection-9'));
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.descendant(of: favorite, matching: find.byIcon(Icons.star)),
        findsOneWidget);
    expect(find.descendant(of: viewed, matching: find.byIcon(Icons.check)),
        findsOneWidget);
    final newlySelected = find.byKey(const ValueKey('team-selection-3468'));
    await tester.tap(newlySelected);
    await tester.pumpAndSettle();
    expect(
        find.descendant(of: newlySelected, matching: find.byIcon(Icons.check)),
        findsOneWidget);
    expect(find.descendant(of: favorite, matching: find.byIcon(Icons.star)),
        findsOneWidget);
    expect(requests, hasLength(3));
    await tester.tap(find.text('선택한 팀으로 바꿔요'));
    await tester.pumpAndSettle();
    expect(switchedTeamId, 3468);
    expect(currentUserPreferences.favoriteTeamId.value, 83);
    expect(find.byType(TeamSelectionSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
