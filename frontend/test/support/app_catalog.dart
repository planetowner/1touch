import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/competitions/mock/competition_catalog.dart';
import 'package:onetouch/data/competitions/mock/season_catalog.dart';
import 'package:onetouch/data/teams/mock/team_catalog.dart';
import 'package:onetouch/data/matches/mock/fixture_catalog.dart';
import 'package:onetouch/data/teams/mock/team_season_catalog.dart';

// 위젯 단위 테스트는 인증 후의 상태에서 시작해요. 제품의 HTTP 클라이언트만 대체해요.
void setUpAppCatalog({int favoriteTeamId = 83}) {
  setUpAll(() async {
    await http.runWithClient(
        () => footballCatalog.initialize(),
        () => MockClient((request) async {
              if (request.url.path.endsWith('/catalog')) {
                return http.Response(
                    jsonEncode({
                      'teams': [
                        for (final t in mockTeams)
                          {
                            'team_id': t.teamId,
                            'name': t.name,
                            'short_name': t.shortName,
                            'short_code': t.shortCode,
                            'image_path': t.imagePath,
                          }
                      ],
                      'competitions': [
                        for (final c in mockCompetitions)
                          {
                            'competition_id': c.competitionId,
                            'name': c.name,
                            'short_code': c.shortCode,
                            'image_path': c.imagePath,
                          }
                      ],
                      'seasons': [
                        for (final s in mockSeasons)
                          {
                            'season_id': s.seasonId,
                            'competition_id': s.competitionId,
                            'name': s.name,
                            'is_current': s.isCurrent,
                          }
                      ],
                      'memberships': [
                        for (final entry in {
                          for (final f in mockFixtures)
                            if ([2, 5, 2286, 24, 27, 390, 570]
                                .contains(f.competitionId)) ...[
                              (f.homeTeamId, f.seasonId, f.competitionId),
                              (f.awayTeamId, f.seasonId, f.competitionId)
                            ]
                        })
                          {
                            'team_id': entry.$1,
                            'season_id': entry.$2,
                            'competition_id': entry.$3
                          },
                        for (final m in mockTeamSeasonMemberships)
                          {
                            'team_id': m.teamId,
                            'season_id': m.seasonId,
                            'competition_id': m.competitionId,
                          }
                      ],
                    }),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8'
                    });
              }
              if (request.url.path.endsWith('/users/me/following/players')) {
                return http.Response(
                    request.method == 'GET' ? '{"items":[]}' : '{"ok":true}',
                    200);
              }
              if (request.url.path.endsWith('/users/me/following/teams') &&
                  request.method == 'PUT') {
                return http.Response('{"ok":true}', 200);
              }
              if (request.url.path.endsWith('/users/me/following/teams')) {
                return http.Response(
                    jsonEncode([
                      for (final id
                          in currentUserPreferences.followedTeamIds.value)
                        {
                          'team_id': id,
                          'name':
                              mockTeams.firstWhere((t) => t.teamId == id).name,
                          'short_code': null,
                          'image_path': null
                        }
                    ]),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8'
                    });
              }
              return http.Response('{"detail":"Unstubbed request"}', 500);
            }));
  });
  setUp(() {
    currentUserPreferences.resetViewedTeam();
    currentUserPreferences.applyServerSelection(UserTeamPreferences(
        favoriteTeamId: favoriteTeamId,
        followedTeamIds: [83, 503, 19, 3468, 851]));
  });
}
