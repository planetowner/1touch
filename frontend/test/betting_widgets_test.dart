import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/team_comparison_colors.dart';
import 'package:onetouch/data/betting/betting_repository.dart';
import 'package:onetouch/data/teams/mock/mock_team_repository.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/features/betting/betting_controller.dart';
import 'package:onetouch/features/betting_widgets.dart';
import 'package:onetouch/models/betting.dart';

import 'support/fake_betting_repository.dart';

void main() {
  for (final barWidth in [280.0, 390.0, 110.0]) {
    testWidgets('probability labels retain Heading5 at width $barWidth',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: barWidth,
              child: const BettingProbabilityBar(
                values: [0.8, 0.15, 0.05],
                selected: BetOutcome.awayWin,
              ),
            ),
          ),
        ),
      ));

      for (final label in ['80.0%', '15.0%', '5.0%']) {
        final labelFinder = find.text(label);
        final text = tester.widget<Text>(labelFinder);
        final container = find
            .ancestor(
              of: labelFinder,
              matching: find.byType(Container),
            )
            .first;
        final labelRect = tester.getRect(labelFinder);
        final segmentRect = tester.getRect(container);
        expect(text.style?.fontSize, 18);
        expect(labelRect.left, greaterThanOrEqualTo(segmentRect.left + 3));
        expect(labelRect.right, lessThanOrEqualTo(segmentRect.right - 3));
        if (label == '80.0%') {
          expect(labelRect.left, closeTo(segmentRect.left + 3, 0.1));
        } else if (label == '15.0%') {
          expect(labelRect.center.dx, closeTo(segmentRect.center.dx, 0.1));
        } else {
          expect(labelRect.right, closeTo(segmentRect.right - 3, 0.1));
        }
      }
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(tester.getRect(find.byIcon(Icons.check_circle)).right,
          lessThanOrEqualTo(tester.getRect(find.text('5.0%')).left));
      expect(tester.takeException(), isNull);
      expect(
        find.byType(SingleChildScrollView),
        barWidth == 390 ? findsNothing : findsOneWidget,
      );
    });
  }

  testWidgets('uses the server stake unit for minimum and amount buttons',
      (tester) async {
    final repository = FakeBettingRepository()
      ..stakeUnit = 25
      ..balance = 24;
    final controller = BettingController(fixtureId: 1, repository: repository);
    await controller.load();
    final teams = MockTeamRepository();
    await tester.pumpWidget(MaterialApp(
        theme: whitetheme,
        home: Scaffold(
          body: MatchBettingSection(
              controller: controller,
              homeTeam: teams.requireById(6),
              awayTeam: teams.requireById(14)),
        )));
    expect(
        find.text('You need at least 25 pts to place a bet.'), findsOneWidget);
    await tester.tap(find.text('PLACE A BET'));
    await tester.pumpAndSettle();
    expect(find.byType(BettingFlowModal), findsNothing);

    repository.balance = 85;
    await controller.load();
    await tester.pump();
    await tester.tap(find.text('PLACE A BET'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Draw').last);
    await tester.pump();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('75 pts'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bet-decrease')));
    await tester.pump();
    expect(find.text('50 pts'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bet-increase')));
    await tester.pump();
    expect(find.text('75 pts'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('bet-increase')))
            .onPressed,
        isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('reloads betting when the server opening time arrives',
      (tester) async {
    final repository = FakeBettingRepository()
      ..unavailableReason = 'betting_not_open'
      ..opensAt = DateTime.now().add(const Duration(seconds: 2));
    final controller = BettingController(fixtureId: 1, repository: repository);
    await controller.load();
    expect(controller.canBet, false);
    repository.unavailableReason = null;
    await tester.pump(const Duration(seconds: 2));
    expect(controller.canBet, true);
    controller.dispose();
  });

  test('point return uses exact decimal arithmetic', () {
    expect(FakeBettingRepository.options[0].totalReturn(100), 166);
    expect(FakeBettingRepository.options[1].totalReturn(100), 1000);
    expect(FakeBettingRepository.options[2].totalReturn(100), 333);
  });

  test(
    'failed request retries with the same ID and never fabricates success',
    () async {
      final repository = FakeBettingRepository()
        ..saveError = const BettingRequestException('request_failed');
      final controller = BettingController(
        fixtureId: 1,
        repository: repository,
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(await controller.save(BetOutcome.draw, 100), false);
      expect(controller.market!.bet, isNull);
      repository.saveError = null;
      expect(await controller.save(BetOutcome.draw, 100), true);
      expect(repository.requestIds[0], repository.requestIds[1]);
      expect(controller.market!.wallet.balance, 900);
    },
  );

  testWidgets('keeps the anchor primary and advances a similar opponent color',
      (tester) async {
    final repository = FakeBettingRepository();
    final controller = BettingController(fixtureId: 1, repository: repository);
    await controller.load();
    final teams = MockTeamRepository();
    final home = teams.requireById(83);
    final away = teams.requireById(459);
    final homePalette = TeamComparisonColorResolver.paletteFor(
      teamName: home.name,
      primaryFallback: Color(home.primaryColor),
    );
    final awayPalette = TeamComparisonColorResolver.paletteFor(
      teamName: away.name,
      primaryFallback: Color(away.primaryColor),
    );

    Future<void> pumpWithAnchor(int anchorTeamId) => tester.pumpWidget(
          MaterialApp(
            theme: whitetheme,
            home: Scaffold(
              body: MatchBettingSection(
                controller: controller,
                homeTeam: home,
                awayTeam: away,
                anchorTeamId: anchorTeamId,
              ),
            ),
          ),
        );

    await pumpWithAnchor(home.teamId);
    var colors = tester
        .widget<BettingProbabilityBar>(find.byType(BettingProbabilityBar))
        .colors!;
    expect(colors.first, homePalette.primary);
    expect(colors.last, awayPalette.secondary);
    expect(colors[1], Color.lerp(colors.first, colors.last, 0.5));

    await pumpWithAnchor(away.teamId);
    colors = tester
        .widget<BettingProbabilityBar>(find.byType(BettingProbabilityBar))
        .colors!;
    expect(colors.first, homePalette.secondary);
    expect(colors.last, awayPalette.primary);
    expect(colors[1], Color.lerp(colors.first, colors.last, 0.5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('place edit cancel at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = FakeBettingRepository();
      final controller = BettingController(
        fixtureId: 1,
        repository: repository,
      );
      await controller.load();
      final teams = MockTeamRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: size.width == 320 ? whitetheme : darktheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  MatchBettingSection(
                    controller: controller,
                    homeTeam: teams.requireById(6),
                    awayTeam: teams.requireById(14),
                  ),
                  BettingParticipationCard(controller: controller),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('1Touch'), findsOneWidget);
      expect(find.text('EXPERT'), findsNothing);
      expect(find.text('No bets yet.'), findsOneWidget);
      final noBetsBar = find.byKey(const ValueKey('match-h2h-no-bets-bar'));
      final noBetsContainer = tester.widget<Container>(noBetsBar);
      final noBetsText = tester.widget<Text>(
        find.descendant(of: noBetsBar, matching: find.byType(Text)),
      );
      expect(tester.getSize(noBetsBar).height, 40);
      expect(noBetsContainer.padding, const EdgeInsets.all(8));
      expect(noBetsContainer.alignment, Alignment.center);
      expect((noBetsContainer.decoration as BoxDecoration).color,
          AppPalette.lightGrey);
      expect((noBetsContainer.decoration as BoxDecoration).borderRadius,
          const BorderRadius.all(Radius.circular(6)));
      expect(noBetsText.style?.fontSize, 18);
      expect(noBetsText.style?.fontWeight, FontWeight.w700);
      expect(noBetsText.style?.color, AppPalette.white);
      await tester.ensureVisible(find.text('PLACE A BET'));
      await tester.tap(find.text('PLACE A BET'));
      await tester.pumpAndSettle();
      final drawHomeLogo = tester.getRect(
        find.byKey(const ValueKey('match-betting-draw-home-logo')),
      );
      final drawAwayLogo = tester.getRect(
        find.byKey(const ValueKey('match-betting-draw-away-logo')),
      );
      expect(
        find.byKey(const ValueKey('match-betting-draw-home-clip')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('match-betting-draw-away-clip')),
        findsOneWidget,
      );
      expect(drawHomeLogo.overlaps(drawAwayLogo), isTrue);
      expect(drawAwayLogo.left, greaterThan(drawHomeLogo.left));
      expect(drawAwayLogo.top, greaterThan(drawHomeLogo.top));
      expect(
        tester
            .widget<Divider>(
              find.byKey(
                const ValueKey('match-betting-option-divider-draw'),
              ),
            )
            .color,
        size.width == 320
            ? AppColors.of(
                tester.element(
                  find.byKey(
                    const ValueKey('match-betting-option-divider-draw'),
                  ),
                ),
              ).divider
            : AppPalette.lightGrey,
      );
      await tester.ensureVisible(find.widgetWithText(ListTile, 'Draw'));
      await tester.tap(find.widgetWithText(ListTile, 'Draw'));
      await tester.pump();
      await tester.ensureVisible(find.text('CONTINUE'));
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.text('If correct: +900 pts'), findsOneWidget);
      repository.submitGate = Completer<void>();
      await tester.ensureVisible(find.text('CONFIRM BET'));
      await tester.tap(find.text('CONFIRM BET'));
      await tester.pump();
      expect(find.text('Bet Submitted!'), findsNothing);
      expect(repository.saveCalls, 1);
      repository.submitGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Bet Submitted!'), findsOneWidget);
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();
      expect(find.text('You’ve got 900 pts!'), findsOneWidget);
      expect(find.text('EDIT BET'), findsOneWidget);
      await tester.ensureVisible(find.text('EDIT BET'));
      await tester.tap(find.text('EDIT BET'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('CONTINUE'));
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('bet-increase')));
      await tester.tap(find.byKey(const ValueKey('bet-increase')));
      await tester.pump();
      await tester.ensureVisible(find.text('CONFIRM BET'));
      await tester.tap(find.text('CONFIRM BET'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();
      expect(find.text('You’ve got 890 pts!'), findsOneWidget);
      await tester.ensureVisible(find.text('CANCEL BET'));
      await tester.tap(find.text('CANCEL BET'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'CANCEL BET').last);
      await tester.pumpAndSettle();
      expect(find.text('You’ve got 1000 pts!'), findsOneWidget);
      expect(find.text('No bets yet.'), findsOneWidget);
      expect(noBetsBar, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

  testWidgets('H2H shows the accepted payout after settlement', (tester) async {
    final repository = FakeBettingRepository()
      ..bet = const FixtureBet(
        betId: 1,
        fixtureId: 1,
        outcome: BetOutcome.draw,
        stake: 100,
        probabilityText: '0.250000000000000000',
        decimalOdds: 4,
        potentialReturn: 400,
        status: 'won',
        revision: 2,
        payout: 400,
      );
    final controller = BettingController(fixtureId: 1, repository: repository);
    await controller.load();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: BettingParticipationCard(controller: controller),
    )));
    expect(
        find.text('You earned 400 points from this bet! 🎉'), findsOneWidget);
    expect(find.text('Won · 400 pts returned'), findsNothing);
    expect(find.text('Draw · 100 pts'), findsNothing);
    expect(find.text('0 participants'), findsOneWidget);
    expect(find.textContaining('Home / Draw / Away'), findsNothing);

    final card = find.byKey(const ValueKey('match-h2h-bets-card'));
    final receipt = find.byKey(const ValueKey('match-h2h-bet-receipt'));
    expect(receipt, findsOneWidget);
    expect(
      (tester.widget<Container>(card).decoration! as BoxDecoration).color,
      AppPalette.white,
    );
    expect(tester.getTopLeft(receipt).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(card).dy));
    expect(tester.getTopLeft(receipt).dx, tester.getTopLeft(card).dx);
    expect(
      find.descendant(
        of: card,
        matching: find.text('You earned 400 points from this bet! 🎉'),
      ),
      findsNothing,
    );
    final summary = tester.widget<Text>(find.descendant(
      of: receipt,
      matching: find.byType(Text),
    ));
    expect(summary.textAlign, TextAlign.left);
    expect(summary.maxLines, 1);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(
        body: BettingParticipationCard(controller: controller),
      ),
    ));
    await tester.pumpAndSettle();
    expect(
      (tester.widget<Container>(card).decoration! as BoxDecoration).color,
      AppPalette.darkGrey,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
