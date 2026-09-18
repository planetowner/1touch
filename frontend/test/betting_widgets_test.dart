import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/betting/betting_repository.dart';
import 'package:onetouch/data/teams/mock/mock_team_repository.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/features/betting/betting_controller.dart';
import 'package:onetouch/features/betting_widgets.dart';
import 'package:onetouch/models/betting.dart';

import 'support/fake_betting_repository.dart';

void main() {
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
      await tester.ensureVisible(find.text('PLACE A BET'));
      await tester.tap(find.text('PLACE A BET'));
      await tester.pumpAndSettle();
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
    expect(find.text('Won · 400 pts returned'), findsOneWidget);
    expect(find.text('Draw · 100 pts'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
