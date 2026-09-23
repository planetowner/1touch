import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/competitions/tournament_bracket_repository.dart';
import 'package:onetouch/features/api_knockout_bracket.dart';

void main() {
  TournamentBracketRepository repository() => TournamentBracketRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/v1/competitions/2/bracket');
            expect(request.url.queryParameters, {'season_id': '100'});
            return http.Response(
                File('test/fixtures/api_bracket.json').readAsStringSync(), 200);
          }),
          baseUri: Uri.parse('https://api.test/v1'),
          requestHeaders: () => const {}));

  test(
      'shared bracket preserves aggregate result, two legs and detail availability',
      () async {
    final result = await repository().load(2, 100);
    final tie = result.stages.first.ties.first;
    expect(tie.aggregateScore, [1, 1]);
    expect(tie.winnerTeamId, 1);
    expect(tie.matches, hasLength(2));
    expect(tie.matches.first.detailAvailable, isTrue);
    expect(tie.matches.last.detailAvailable, isFalse);
  });
  testWidgets('renders backend ties and only enables collected match details',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ApiKnockoutBracket(
                    competitionId: 2,
                    seasonId: 100,
                    repository: repository())))));
    await tester.pumpAndSettle();
    final matchButtons = tester.widgetList<TextButton>(find.byType(TextButton));
    expect(matchButtons, hasLength(5));
    expect(
        matchButtons.where((button) => button.onPressed != null), hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
