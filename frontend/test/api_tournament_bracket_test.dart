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
    expect(
      find.byKey(const ValueKey('tournament-bracket-pages')),
      findsOneWidget,
    );
    expect(find.byType(InteractiveViewer), findsNothing);
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
      const Size(185, 208),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('bracket-stage-Final'))),
      const Size(165, 208),
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
      tester.getCenter(
        find.byKey(const ValueKey('tournament-bracket-pages')),
      ),
    );
    await tester.pump();
    expect(interactionStates, [true]);
    await gesture.up();
    await tester.pump();
    expect(interactionStates, [true, false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('both rounds and their shadows fit inside a narrow viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: app_style.whitetheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ApiKnockoutBracket(
            competitionId: 2,
            seasonId: 100,
            repository: repository(),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final viewport = tester.getRect(
      find.byKey(const ValueKey('tournament-bracket-pages')),
    );
    final cardFinder =
        find.byKey(const ValueKey('bracket-match-card-fixture:1'));
    final card = tester.getRect(cardFinder);
    expect(card.left - viewport.left, greaterThanOrEqualTo(16));
    expect(card.top - viewport.top, greaterThanOrEqualTo(16));
    final rightCard = tester.getRect(
      find.byKey(const ValueKey('bracket-match-card-fixture:5')),
    );
    expect(viewport.right - rightCard.right, greaterThanOrEqualTo(16));
    expect(rightCard.width, 162.5);
    expect(
      rightCard.left - card.right,
      20,
      reason: 'The connector lane must remain exactly 20px wide.',
    );
    expect(
      (tester.widget<Container>(cardFinder).decoration as BoxDecoration)
          .boxShadow,
      app_style.lightModeCardShadows,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('swipes forward by one round while keeping two rounds visible',
      (tester) async {
    BracketStage stage(String name, int tieCount) => (
          name: name,
          ties: List<BracketTie>.generate(
            tieCount,
            (index) => (
              id: '$name:$index',
              slots: <BracketSlot>[
                (teamId: null, label: 'TBD'),
                (teamId: null, label: 'TBD'),
              ],
              aggregateScore: null,
              winnerTeamId: null,
              matches: <BracketMatch>[],
            ),
          ),
        );
    final bracket = TournamentBracket(
      status: 'in_progress',
      stages: [
        stage('Round of 16', 8),
        stage('Quarter-finals', 4),
        stage('Semi-finals', 2),
        stage('Final', 1),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scrollController,
            child: ApiKnockoutBracket(
              competitionId: 24,
              seasonId: 100,
              repository: _StaticBracketRepository(bracket),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final quarterCard =
        find.byKey(const ValueKey('bracket-match-card-Quarter-finals:0'));
    final quarterElement = tester.element(quarterCard);
    final quarterBefore = tester.getTopLeft(quarterCard);
    final initialViewportHeight = tester
        .getSize(find.byKey(const ValueKey('tournament-bracket-pages')))
        .height;
    expect(initialViewportHeight, 936);
    final lastMatch = tester.getRect(
      find.byKey(const ValueKey('bracket-match-card-Round of 16:7')),
    );
    final viewport = tester.getRect(
      find.byKey(const ValueKey('tournament-bracket-pages')),
    );
    expect(viewport.bottom - lastMatch.bottom, greaterThanOrEqualTo(16));
    await tester.drag(
      find.byKey(const ValueKey('tournament-bracket-pages')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(scrollController.offset, greaterThan(0));
    await tester.drag(
      find.byKey(const ValueKey('tournament-bracket-pages')),
      const Offset(-350, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.element(quarterCard), same(quarterElement));
    expect(
      find.byKey(const ValueKey('bracket-stage-Quarter-finals')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bracket-stage-Semi-finals')),
      findsOneWidget,
    );
    final firstQuarter = tester.getTopLeft(
      find.byKey(const ValueKey('bracket-match-card-Quarter-finals:0')),
    );
    final secondQuarter = tester.getTopLeft(
      find.byKey(const ValueKey('bracket-match-card-Quarter-finals:1')),
    );
    final firstSemi = tester.getTopLeft(
      find.byKey(const ValueKey('bracket-match-card-Semi-finals:0')),
    );
    final secondSemi = tester.getTopLeft(
      find.byKey(const ValueKey('bracket-match-card-Semi-finals:1')),
    );
    expect(firstQuarter.dx, lessThan(quarterBefore.dx));
    expect(firstQuarter.dx, closeTo(viewport.left + 16, 0.1));
    expect(firstSemi.dx - firstQuarter.dx, 146);
    expect(secondQuarter.dy - firstQuarter.dy, 116);
    expect(secondSemi.dy - firstSemi.dy, 232);
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('tournament-bracket-pages')),
          )
          .height,
      lessThanOrEqualTo(initialViewportHeight),
    );

    await tester.drag(
      find.byKey(const ValueKey('tournament-bracket-pages')),
      const Offset(-350, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.element(quarterCard), same(quarterElement));
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('tournament-bracket-pages')),
          )
          .height,
      240,
    );
    await tester.drag(
      find.byKey(const ValueKey('tournament-bracket-pages')),
      const Offset(350, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(quarterCard).dx, closeTo(viewport.left + 16, 0.1));
    await tester.drag(
      find.byKey(const ValueKey('tournament-bracket-pages')),
      const Offset(350, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(quarterCard).dx, closeTo(quarterBefore.dx, 0.1));
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

class _StaticBracketRepository extends TournamentBracketRepository {
  _StaticBracketRepository(this.bracket)
      : super(
          api: ApiClient(
            client: MockClient((_) async => throw UnsupportedError('unused')),
            baseUri: Uri.parse('https://api.test/v1'),
            requestHeaders: () => const {},
          ),
        );

  final TournamentBracket bracket;

  @override
  Future<TournamentBracket> load(int competitionId, int seasonId) async =>
      bracket;
}
