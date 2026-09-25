import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/style.dart' as app_style;
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
  testWidgets('renders the approved bracket cards and enables collected ties',
      (tester) async {
    final interactionStates = <bool>[];
    await tester.pumpWidget(MaterialApp(
        theme: app_style.darktheme,
        home: Scaffold(
            body: SingleChildScrollView(
                child: ApiKnockoutBracket(
                    competitionId: 2,
                    seasonId: 100,
                    onInteractionChanged: interactionStates.add,
                    repository: repository())))));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tournament-bracket')), findsOneWidget);
    final zoom = tester.widget<InteractiveViewer>(
      find.byKey(const ValueKey('tournament-bracket-zoom')),
    );
    expect(zoom.minScale, 0.5);
    expect(zoom.maxScale, 1.5);
    expect(zoom.constrained, isFalse);
    expect(zoom.alignment, Alignment.topLeft);
    expect(zoom.boundaryMargin, const EdgeInsets.all(48));
    expect(find.byKey(const ValueKey('bracket-match-card-fixture:1')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('bracket-match-card-fixture:3')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('bracket-match-card-fixture:5')),
        findsOneWidget);

    final cardFinder =
        find.byKey(const ValueKey('bracket-match-card-fixture:1'));
    final card = tester.widget<Container>(cardFinder);
    expect(tester.getSize(cardFinder), const Size(165, 92));
    expect(
      card.padding,
      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    );
    final decoration = card.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xFF272828));
    expect(decoration.borderRadius, BorderRadius.circular(8));

    expect(
      tester.getSize(find.byKey(const ValueKey('bracket-stage-Semi-finals'))),
      const Size(185, 232),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('bracket-stage-Final'))),
      const Size(165, 232),
    );

    final ties = tester.widgetList<GestureDetector>(
      find.byWidgetPredicate(
        (widget) =>
            widget is GestureDetector &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('bracket-tie-'),
      ),
    );
    expect(ties, hasLength(3));
    expect(
      ties.where((tie) => tie.onTap != null),
      hasLength(1),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tournament-bracket-zoom'))),
    );
    await tester.pump();
    expect(interactionStates, [true]);
    await gesture.up();
    await tester.pump();
    expect(interactionStates, [true, false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens every available bracket card on its match screen',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/bracket',
      routes: [
        GoRoute(
          path: '/bracket',
          builder: (context, state) => Scaffold(
            body: ApiKnockoutBracket(
              competitionId: 2,
              seasonId: 100,
              repository: repository(),
            ),
          ),
        ),
        GoRoute(
          path: '/match/:id',
          builder: (context, state) => Text(
            'match:${state.pathParameters['id']}:${state.uri.queryParameters['status']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: app_style.darktheme,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bracket-tie-fixture:1')));
    await tester.pumpAndSettle();

    expect(find.text('match:1:past'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
