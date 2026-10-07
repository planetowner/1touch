import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/team_comparison_colors.dart';
import 'package:onetouch/data/betting/betting_repository.dart';
import 'package:onetouch/data/teams/mock/mock_team_repository.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/features/betting/betting_controller.dart';
import 'package:onetouch/features/betting_widgets.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/betting.dart';
import 'package:onetouch/models/team.dart';

import 'support/fake_betting_repository.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('betting uses code then short name at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = BettingController(
        fixtureId: 1,
        repository: FakeBettingRepository(),
      );
      await controller.load();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MatchBettingSection(
              controller: controller,
              homeTeam: const Team(
                teamId: 83,
                name: 'FC Barcelona',
                shortName: 'FCB',
                shortCode: 'BAR',
              ),
              awayTeam: const Team(
                teamId: 6967,
                name: 'Nîmes Olympique',
                shortName: 'Nîmes',
              ),
            ),
          ),
        ),
      ));
      expect(find.text('BAR'), findsOneWidget);
      expect(find.text('Nîmes'), findsOneWidget);
      expect(find.text('FCB'), findsNothing);
      expect(find.text('Nîmes Olympique'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('PLACE A BET'));
      await tester.pumpAndSettle();
      expect(find.text('BAR Win'), findsWidgets);
      expect(find.text('Nîmes Win'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('match betting card keeps equal outer margins at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = FakeBettingRepository()
        ..unavailableReason = 'unsupported_competition';
      final controller =
          BettingController(fixtureId: 1, repository: repository);
      await controller.load();
      final teams = MockTeamRepository();

      await tester.pumpWidget(MaterialApp(
        theme: darktheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BETS'),
                MatchBettingSection(
                  controller: controller,
                  homeTeam: teams.requireById(6),
                  awayTeam: teams.requireById(14),
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final title = tester.getRect(find.text('BETS'));
      final cardFinder = find.byKey(const ValueKey('match-betting-card'));
      final card = tester.getRect(cardFinder);
      expect(card.left, title.left);
      expect(size.width - card.right, card.left);
      expect(tester.widget<Container>(cardFinder).padding,
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

  testWidgets('betting omits full names when both short fields are missing',
      (tester) async {
    final controller = BettingController(
      fixtureId: 1,
      repository: FakeBettingRepository(),
    );
    await controller.load();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MatchBettingSection(
          controller: controller,
          homeTeam: const Team(teamId: 83, name: 'FC Barcelona'),
          awayTeam: const Team(teamId: 6967, name: 'Nîmes Olympique'),
        ),
      ),
    ));

    expect(find.text('FC Barcelona'), findsNothing);
    expect(find.text('Nîmes Olympique'), findsNothing);
    await tester.tap(find.text('PLACE A BET'));
    await tester.pumpAndSettle();
    expect(find.text('Win'), findsWidgets);
    expect(find.textContaining('Barcelona'), findsNothing);
    expect(find.textContaining('Nîmes'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

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
        expect(labelRect.left, greaterThanOrEqualTo(segmentRect.left + 8));
        expect(labelRect.right, lessThanOrEqualTo(segmentRect.right - 8));
        if (label == '80.0%') {
          expect(labelRect.left, closeTo(segmentRect.left + 8, 0.1));
        } else {
          final contentRow =
              find.ancestor(of: labelFinder, matching: find.byType(Row)).first;
          expect(
            tester.getRect(contentRow).center.dx,
            closeTo(segmentRect.center.dx, 0.1),
          );
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

  testWidgets('equal 1.1% segments use equal numeric padding', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 345,
            child: BettingProbabilityBar(
              values: [0.978, 0.011, 0.011],
              outcomeLabels: ['BAR Win', 'Draw', 'GIR Win'],
            ),
          ),
        ),
      ),
    ));

    final homeSegment = tester.getRect(
      find.byKey(const ValueKey('betting-probability-segment-0')),
    );
    final drawSegment = tester.getRect(
      find.byKey(const ValueKey('betting-probability-segment-1')),
    );
    final awaySegment = tester.getRect(
      find.byKey(const ValueKey('betting-probability-segment-2')),
    );
    final homePercentage = tester.getRect(find.text('97.8%'));
    final drawPercentage = tester.getRect(find.text('1.1%').first);
    final awayPercentage = tester.getRect(find.text('1.1%').last);
    final drawLabel = tester.getRect(
      find.byKey(const ValueKey('betting-outcome-label-1')),
    );

    expect(drawSegment.width, closeTo(awaySegment.width, .1));
    expect(drawPercentage.center.dx, closeTo(drawSegment.center.dx, .1));
    expect(awayPercentage.center.dx, closeTo(awaySegment.center.dx, .1));
    expect(drawPercentage.left - drawSegment.left,
        closeTo(drawSegment.right - drawPercentage.right, .1));
    expect(awayPercentage.left - awaySegment.left,
        closeTo(awaySegment.right - awayPercentage.right, .1));
    expect(homePercentage.left - homeSegment.left, closeTo(8, .1));
    expect(awaySegment.right - awayPercentage.right, closeTo(8, .1));
    expect(
      homePercentage.left - homeSegment.left,
      closeTo(awaySegment.right - awayPercentage.right, .1),
    );
    expect(drawPercentage.left - drawSegment.left, greaterThanOrEqualTo(8));
    expect(awayPercentage.left - awaySegment.left, greaterThanOrEqualTo(8));
    expect(drawLabel.center.dx, closeTo(drawSegment.center.dx, .1));
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('responsive WDL odds keep the multiplication sign visible',
      (tester) async {
    final teams = MockTeamRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 313,
            child: MatchStatsHeader(
              homeTeam: teams.requireById(83),
              awayTeam: teams.requireById(676),
              options: const [
                BettingOption(
                  outcome: BetOutcome.homeWin,
                  probabilityText: '0.978',
                  decimalOdds: 1.022494887526,
                ),
                BettingOption(
                  outcome: BetOutcome.draw,
                  probabilityText: '0.011',
                  decimalOdds: 90.909090909091,
                ),
                BettingOption(
                  outcome: BetOutcome.awayWin,
                  probabilityText: '0.011',
                  decimalOdds: 90.909090909091,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('1.0×'), findsOneWidget);
    expect(find.text('90.9×'), findsNWidgets(2));
    final fontSizes = <double>[];
    for (var index = 0; index < 3; index++) {
      final box = find.byKey(ValueKey('match-betting-odds-box-$index'));
      final text = find.descendant(of: box, matching: find.byType(Text));
      final boxRect = tester.getRect(box);
      final textRect = tester.getRect(text);
      fontSizes.add(tester.widget<Text>(text).style!.fontSize!);
      expect(textRect.left, greaterThanOrEqualTo(boxRect.left + 8));
      expect(textRect.right, lessThanOrEqualTo(boxRect.right - 8));
    }
    expect(fontSizes.toSet().length, 1);
    expect(tester.takeException(), isNull);
  });

  test('spending limit rounds balances and adds the editable stake', () async {
    final repository = FakeBettingRepository();
    final controller = BettingController(fixtureId: 1, repository: repository);
    addTearDown(controller.dispose);
    expect(controller.spendingLimit, 0);
    for (final entry in {9: 0, 10: 10, 19: 10, 1207: 1200}.entries) {
      repository.balance = entry.key;
      await controller.load();
      expect(controller.spendingLimit, entry.value);
      expect(controller.market!.wallet.balance, entry.key);
    }
    repository.bet = const FixtureBet(
      betId: 1,
      fixtureId: 1,
      outcome: BetOutcome.draw,
      stake: 100,
      probabilityText: '0.1',
      decimalOdds: 10,
      potentialReturn: 1000,
      status: 'open',
      revision: 1,
      payout: 0,
    );
    await controller.load();
    expect(controller.spendingLimit, 1300);
    expect(controller.market!.wallet.balance, 1207);
  });

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
    expect(find.text('You’ve got 85 pts!'), findsOneWidget);
    await tester.tap(find.text('PLACE A BET'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Draw').last);
    await tester.pump();
    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('75'), findsOneWidget);
    expect(find.text('You can use up to 75 pts!'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('bet-decrease')))
          .style
          ?.side
          ?.resolve({})?.width,
      2,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('bet-decrease')));
    await tester.tap(find.byKey(const ValueKey('bet-decrease')));
    await tester.pump();
    expect(find.text('50'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bet-increase')));
    await tester.pump();
    expect(find.text('75'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('bet-increase')))
            .onPressed,
        isNull);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('bet-decrease')));
      await tester.pump();
    }
    expect(find.text('25'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('bet-decrease')))
            .onPressed,
        isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('bet-flow-back')));
    await tester.tap(find.byKey(const ValueKey('bet-flow-back')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('25'), findsOneWidget);
    expect(
      find.textContaining('225', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Your estimated win'), findsOneWidget);
    expect(repository.saveCalls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('uses the localized point unit throughout the amount flow',
      (tester) async {
    final repository = FakeBettingRepository()..balance = 1207;
    final controller = BettingController(fixtureId: 1, repository: repository);
    await controller.load();
    final teams = MockTeamRepository();
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ko'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      home: Scaffold(
        body: MatchBettingSection(
          controller: controller,
          homeTeam: teams.requireById(6),
          awayTeam: teams.requireById(14),
        ),
      ),
    ));
    expect(find.text('1,207P를 가지고 있어요'), findsOneWidget);
    await tester.tap(find.text('예측하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first);
    await tester.pump();
    await tester.tap(find.text('계속하기'));
    await tester.pumpAndSettle();

    expect(find.text('사용할 포인트'), findsOneWidget);
    expect(find.text('최대 1,200P를 쓸 수 있어요'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('bet-decrease')));
    await tester.tap(find.byKey(const ValueKey('bet-decrease')));
    await tester.pump();
    expect(find.text('90'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bet-increase')));
    await tester.pump();
    expect(find.text('100'), findsOneWidget);
    expect(find.textContaining('포인트', findRichText: true), findsWidgets);
    expect(find.textContaining('pts', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  for (final drawAllowed in [true, false]) {
    testWidgets(
        'shows opening notice then reloads with drawAllowed=$drawAllowed',
        (tester) async {
      final repository = FakeBettingRepository(
        marketOptions: drawAllowed
            ? FakeBettingRepository.options
            : FakeBettingRepository.decisiveOptions,
      )
        ..unavailableReason = 'betting_not_open'
        ..opensAt = DateTime.now().add(const Duration(seconds: 2));
      final controller =
          BettingController(fixtureId: 1, repository: repository);
      await controller.load();
      final teams = MockTeamRepository();
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: Scaffold(
          body: MatchBettingSection(
            controller: controller,
            homeTeam: teams.requireById(6),
            awayTeam: teams.requireById(14),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(controller.canBet, false);
      expect(find.textContaining('에 베팅이 열려요.'), findsOneWidget);
      expect(find.byKey(const ValueKey('match-betting-opening-notice')),
          findsOneWidget);
      repository.unavailableReason = null;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(controller.canBet, true);
      expect(find.byKey(const ValueKey('match-betting-opening-notice')),
          findsNothing);
      expect(find.byKey(const ValueKey('match-betting-card')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

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
    for (final drawAllowed in [true, false]) {
      testWidgets('place edit cancel at $size with drawAllowed=$drawAllowed',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = FakeBettingRepository(
          marketOptions: drawAllowed
              ? FakeBettingRepository.options
              : FakeBettingRepository.decisiveOptions,
        );
        final outcome = drawAllowed ? BetOutcome.draw : BetOutcome.awayWin;
        final profit = drawAllowed ? 900 : 400;
        const participationColors = [Colors.red, Colors.grey, Colors.blue];
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
                    BettingParticipationCard(
                      controller: controller,
                      barColors: participationColors,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(find.text('1TOUCH'), findsOneWidget);
        expect(find.text('EXPERT'), findsNothing);
        expect(find.text('Draw'), drawAllowed ? findsOneWidget : findsNothing);
        expect(find.text('D'), drawAllowed ? findsOneWidget : findsNothing);
        for (final bar in tester.widgetList<BettingProbabilityBar>(
            find.byType(BettingProbabilityBar))) {
          expect(bar.values, drawAllowed ? [0.6, 0.1, 0.3] : [0.8, 0, 0.2]);
        }
        final statsHeader = find.byType(MatchStatsHeader);
        final oddsBoxes = [
          for (var index = 0; index < (drawAllowed ? 3 : 2); index++)
            find.descendant(
              of: statsHeader,
              matching: find.byKey(
                ValueKey('match-betting-odds-box-$index'),
              ),
            ),
        ];
        final oddsBoxWidths =
            oddsBoxes.map(tester.getSize).map((size) => size.width);
        expect(oddsBoxWidths.toSet().length, 1);
        final oddsFontSizes = <double>[];
        for (final oddsBox in oddsBoxes) {
          final container = tester.widget<Container>(oddsBox);
          final decoration = container.decoration! as BoxDecoration;
          final oddsText = tester.widget<Text>(
            find.descendant(of: oddsBox, matching: find.byType(Text)),
          );
          expect(tester.getSize(oddsBox).height, 32);
          expect(
            container.padding,
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          );
          expect(container.alignment, Alignment.center);
          expect(decoration.color, AppPalette.black);
          expect(decoration.borderRadius, BorderRadius.circular(4));
          oddsFontSizes.add(oddsText.style!.fontSize!);
          expect(oddsText.style?.fontWeight, FontWeight.w700);
          expect(oddsText.textAlign, TextAlign.center);
        }
        expect(oddsFontSizes.toSet().length, 1);
        expect(
            oddsFontSizes.first, lessThanOrEqualTo(Heading4.style.fontSize!));
        final headerBar = tester.getRect(find.descendant(
          of: statsHeader,
          matching: find.byKey(
            const ValueKey('betting-probability-bar-surface'),
          ),
        ));
        final homeLabel = find.descendant(
          of: statsHeader,
          matching: find.text('TOT Win'),
        );
        final awayLabel = find.descendant(
          of: statsHeader,
          matching: find.text('MUN Win'),
        );
        final homeRect = tester.getRect(homeLabel);
        final awayRect = tester.getRect(awayLabel);
        expect(tester.widget<Text>(homeLabel).textAlign, TextAlign.left);
        expect(tester.widget<Text>(awayLabel).textAlign, TextAlign.right);
        expect(homeRect.left, closeTo(headerBar.left, 0.1));
        expect(awayRect.right, closeTo(headerBar.right, 0.1));
        expect(homeRect.top, closeTo(headerBar.bottom + 8, 0.1));
        expect(awayRect.top, closeTo(homeRect.top, 0.1));
        if (drawAllowed) {
          final drawLabel = find.descendant(
            of: statsHeader,
            matching: find.text('Draw'),
          );
          final drawRect = tester.getRect(drawLabel);
          final drawSegment = tester.getRect(find
              .ancestor(
                of: find.descendant(
                  of: statsHeader,
                  matching: find.text('10.0%'),
                ),
                matching: find.byType(Container),
              )
              .first);
          expect(tester.widget<Text>(drawLabel).textAlign, TextAlign.center);
          expect(drawRect.center.dx, closeTo(drawSegment.center.dx, 0.1));
          expect(drawRect.top, closeTo(homeRect.top, 0.1));
        }
        if (!drawAllowed) {
          for (final label in find.text('20.0%').evaluate()) {
            final segment = tester.widget<Container>(find
                .ancestor(
                  of: find.byWidget(label.widget),
                  matching: find.byType(Container),
                )
                .first);
            final bar = tester.widget<BettingProbabilityBar>(find.ancestor(
              of: find.byWidget(label.widget),
              matching: find.byType(BettingProbabilityBar),
            ));
            expect(segment.color, bar.colors![BetOutcome.awayWin.index]);
          }
        }
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
        expect(find.byType(ListTile), findsNWidgets(drawAllowed ? 3 : 2));
        for (final tile in tester.widgetList<ListTile>(find.byType(ListTile))) {
          expect(tile.subtitle, isNull);
          expect((tile.title! as Text).style?.fontWeight, FontWeight.w700);
        }
        final headerTitle = tester.getRect(find.text('Bets'));
        final backButton = tester.getRect(
          find.byKey(const ValueKey('bet-flow-back')),
        );
        final closeButton = tester.getRect(
          find.byKey(const ValueKey('bet-flow-close')),
        );
        expect(headerTitle.center.dy, closeTo(backButton.center.dy, .1));
        expect(headerTitle.center.dy, closeTo(closeButton.center.dy, .1));
        if (drawAllowed) {
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
        } else {
          expect(find.text('Draw'), findsNothing);
          expect(find.text('D'), findsNothing);
          expect(find.text('1.3×'), findsWidgets);
          expect(find.text('5.0×'), findsWidgets);
        }
        final selection = find.byType(ListTile).at(1);
        await tester.ensureVisible(selection);
        await tester.tap(selection);
        await tester.pump();
        await tester.ensureVisible(find.text('CONTINUE'));
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('$profit', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('Your estimated win'), findsOneWidget);
        final amountInput = tester.getRect(
          find.byKey(const ValueKey('match-betting-amount-input')),
        );
        expect(tester.getRect(find.text('You’re betting')).left,
            closeTo(amountInput.left, .1));
        expect(tester.getRect(find.text('You can use up to 1,000 pts!')).left,
            closeTo(amountInput.left, .1));
        await tester.ensureVisible(find.text('CONTINUE'));
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('bet-review-amount')), findsOneWidget);
        expect(find.byKey(const ValueKey('bet-decrease')), findsNothing);
        final flowHeader = tester.getRect(
          find.byKey(const ValueKey('bet-flow-header')),
        );
        final reviewPrompt = tester.getRect(
          find.text('You’re about to place a bet of'),
        );
        final reviewAmount = tester.getRect(
          find.byKey(const ValueKey('bet-review-amount')),
        );
        final reviewQuestion = tester.getRect(
          find.text('Would you like to proceed?'),
        );
        expect(reviewPrompt.top - flowHeader.bottom, closeTo(32, .1));
        expect(reviewAmount.top - reviewPrompt.bottom, closeTo(16, .1));
        expect(reviewQuestion.top - reviewAmount.bottom, closeTo(16, .1));
        expect(repository.saveCalls, 0);
        await tester.tap(find.byKey(const ValueKey('bet-flow-back')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('bet-decrease')), findsOneWidget);
        await tester.ensureVisible(find.text('CONTINUE'));
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();
        repository.submitGate = Completer<void>();
        await tester.ensureVisible(find.text('CONTINUE'));
        await tester.tap(find.text('CONTINUE'));
        await tester.pump();
        expect(find.text('Bet Submitted!'), findsNothing);
        expect(repository.saveCalls, 1);
        expect(find.byKey(const ValueKey('bet-decrease')), findsNothing);
        expect(find.byKey(const ValueKey('bet-increase')), findsNothing);
        repository.submitGate!.complete();
        await tester.pumpAndSettle();
        expect(find.text('Bet Submitted!'), findsOneWidget);
        expect(find.byKey(const ValueKey('bet-flow-back')), findsNothing);
        expect(
            tester.widget<Icon>(find.byIcon(Icons.check_circle_outline)).size,
            56);
        await tester.tap(find.text('DONE'));
        await tester.pumpAndSettle();
        expect(find.text('You’ve got 900 pts!'), findsNothing);
        expect(find.text('You’ve already placed a bet.'), findsOneWidget);
        expect(find.text('EDIT MY BET'), findsOneWidget);
        expect(find.text('CANCEL BET'), findsNothing);
        expect(repository.bet!.outcome, outcome);
        expect(repository.bet!.potentialReturn, profit + 100);
        final participationBar = find
            .descendant(
              of: find.byKey(const ValueKey('match-h2h-bets-card')),
              matching: find.byType(BettingProbabilityBar),
            )
            .last;
        expect(tester.widget<BettingProbabilityBar>(participationBar).selected,
            outcome);
        final selectedSegment = tester.widget<Container>(find
            .ancestor(
              of: find.descendant(
                  of: participationBar, matching: find.text('100.0%')),
              matching: find.byType(Container),
            )
            .first);
        expect(selectedSegment.color, participationColors[outcome.index]);
        expect(
            find.descendant(
                of: participationBar,
                matching: find.byIcon(Icons.check_circle)),
            findsOneWidget);
        await tester.ensureVisible(find.text('EDIT MY BET'));
        await tester.tap(find.text('EDIT MY BET'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('CONTINUE'));
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('bet-increase')));
        await tester.tap(find.byKey(const ValueKey('bet-increase')));
        await tester.pump();
        await tester.ensureVisible(find.text('CONTINUE'));
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('CONTINUE'));
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('DONE'));
        await tester.pumpAndSettle();
        expect(find.text('You’ve got 890 pts!'), findsNothing);
        expect(find.text('You’ve already placed a bet.'), findsOneWidget);
        expect(find.text('EDIT MY BET'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      });
    }
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
