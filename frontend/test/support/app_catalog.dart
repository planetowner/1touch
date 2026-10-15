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
              if (request.url.path.endsWith('/users/me/points/initialize') &&
                  request.method == 'POST') {
                return http.Response('{"balance":0,"initialized":true}', 200);
              }
              if (request.url.path.endsWith('/users/me') &&
                  request.method == 'GET') {
                return http.Response(
                    jsonEncode({
                      'user_id': 1,
                      'username': null,
                      'display_name': 'Example',
                      'email': null,
                      'avatar_url': null,
                      'favorite_team_id':
                          currentUserPreferences.favoriteTeamId.value,
                      'created_at': '2026-09-22T00:00:00Z',
                      'onboarding_complete': true,
                      'social_accounts': [],
                    }),
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
              // 글쓰기 화면에서 함께 요청하는 임시저장 API도 정상 응답을 제공해요.
              if (request.url.path.endsWith('/post-drafts')) {
                if (request.method == 'GET') {
                  return http.Response('{"items":[]}', 200);
                }
                if (request.method == 'POST') {
                  final input =
                      jsonDecode(request.body) as Map<String, dynamic>;
                  return http.Response(
                      jsonEncode({
                        'post_id': 42,
                        'team_id': input['team_id'],
                        'language': input['language'],
                        'category': input['category'],
                        'title': input['title'],
                        'body': input['body'],
                        'attachments': [],
                        'expires_at': '2026-12-31T00:00:00Z',
                      }),
                      201);
                }
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
