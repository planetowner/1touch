import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/bottom_navigation.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/catalog/football_names.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/features/betting/bet_settlement_notifications.dart';
import 'package:onetouch/models/betting.dart';
import 'package:onetouch/models/fixture.dart';

import 'support/app_fonts.dart';
import 'support/screen_pixels.dart';

void main() {
  setUpAll(loadAppFonts);

  // 현재 경기 상태와 관계없이 정산 응답의 사유로 환불 문구를 골라요.
  const fixture = Fixture(
    fixtureId: 83,
    seasonId: 1,
    competitionId: 1,
    homeTeamId: 83,
    awayTeamId: 84,
    homeTeamName: 'FC Barcelona',
    awayTeamName: 'Real Madrid CF',
    homeTeamShortName: 'Barcelona',
    awayTeamShortName: 'Real Madrid',
    competitionType: CompetitionType.league,
    roundName: '1',
    status: FixtureStatus.upcoming,
    stateId: 1,
    stateName: 'Not Started',
    startingAt: null,
  );
  const notice = BetSettlementNotice(
    bet: FixtureBet(
      betId: 7,
      fixtureId: 83,
      outcome: BetOutcome.homeWin,
      stake: 100,
      probabilityText: '0.200000000000000000',
      decimalOdds: 5,
      potentialReturn: 500,
      status: 'won',
      revision: 2,
      payout: 500,
    ),
    selectionTeamId: 83,
    selectionName: 'Barcelona',
    fixture: fixture,
  );
  const namesByLanguage = {
    'en': FootballNames(
      teams: {83: 'FC Barcelona', 84: 'Real Madrid CF'},
      teamShortNames: {83: 'Barcelona', 84: 'Real Madrid'},
    ),
    'ko': FootballNames(
      teams: {83: 'FC 바르셀로나', 84: '레알 마드리드 CF'},
      teamShortNames: {83: '바르셀로나', 84: '레알 마드리드'},
    ),
    'ja': FootballNames(teams: {83: 'FCバルセロナ', 84: 'レアル・マドリード'}),
    'zh': FootballNames(teams: {83: '巴塞罗那足球俱乐部', 84: '皇家马德里足球俱乐部'}),
  };

  BetSettlementNotice resultNotice(String status, {String? reason}) =>
      BetSettlementNotice(
        bet: FixtureBet(
          betId: 7,
          fixtureId: 83,
          outcome: BetOutcome.homeWin,
          stake: 100,
          probabilityText: '0.200000000000000000',
          decimalOdds: 5,
          potentialReturn: 500,
          status: status,
          revision: 2,
          payout: status == 'refunded' ? 100 : 0,
          settlementReason: reason,
        ),
        selectionTeamId: 83,
        selectionName: 'Barcelona',
        fixture: fixture,
      );

  Future<void> pumpOverlay(
    WidgetTester tester, {
    required VoidCallback onDismiss,
    VoidCallback? onSeeResults,
    String language = 'en',
    double bottomInset = 0,
    Brightness brightness = Brightness.dark,
    Size size = const Size(393, 852),
    BetSettlementNotice settlementNotice = notice,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(bottom: bottomInset);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('refund-preview-capture'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.dark ? darktheme : whitetheme,
          locale: Locale(language),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          builder: (context, child) => FootballNamesScope(
            names: namesByLanguage[language]!,
            child: child!,
          ),
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                Scaffold(
                  body: const ColoredBox(color: Colors.black),
                  bottomNavigationBar: OneTouchBottomNavigationBar(
                    currentIndex: 0,
                    onTap: (_) {},
                  ),
                ),
                BetSettlementResultOverlay(
                  notice: settlementNotice,
                  onDismiss: onDismiss,
                  onSeeResults: onSeeResults ?? () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  for (final preview in [
    (language: 'en', brightness: Brightness.dark),
    (language: 'ko', brightness: Brightness.light),
  ]) {
    testWidgets('refund preview ${preview.language} ${preview.brightness}',
        (tester) async {
      final previousLocale = appLocaleController.value;
      appLocaleController.value = Locale(preview.language);
      addTearDown(() => appLocaleController.value = previousLocale);
      await pumpOverlay(tester,
          onDismiss: () {},
          language: preview.language,
          brightness: preview.brightness,
          settlementNotice: resultNotice('refunded', reason: 'CANCELLED'));
      await tester.pumpAndSettle();
      await screenPixels(
        tester,
        find.byKey(const ValueKey('refund-preview-capture')),
        [const Offset(0, 0)],
        screenshotName: 'refund-${preview.language}-${preview.brightness.name}',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows the settled result above the main navigation area',
      (tester) async {
    await pumpOverlay(tester, onDismiss: () {});

    expect(find.text('You won 500 points!'), findsOneWidget);
    expect(
      find.textContaining('Barcelona', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('SEE RESULTS'), findsOneWidget);
    expect(find.text('MAYBE LATER'), findsOneWidget);
    expect(
      tester
          .getBottomRight(find.byKey(const ValueKey('bet-settlement-sheet')))
          .dy,
      tester.getTopLeft(find.byType(OneTouchBottomNavigationBar)).dy,
    );
    expect(tester.takeException(), isNull);
  });

  for (final entry in {
    'en': ('You won 500 points!', 'Your bet on Barcelona was correct.'),
    'ko': ('500 pts를 받았어요!', '바르셀로나에 대한 예측이 맞았어요.'),
    'ja': ('500ポイントを獲得しました！', 'FCバルセロナへの予想が的中しました。'),
    'zh': ('你赢得了500积分！', '你对巴塞罗那足球俱乐部的预测正确。'),
  }.entries) {
    testWidgets('winning result uses localized team names in ${entry.key}',
        (tester) async {
      await pumpOverlay(tester, onDismiss: () {}, language: entry.key);
      expect(find.text(entry.value.$1), findsOneWidget);
      expect(find.textContaining(entry.value.$2, findRichText: true),
          findsOneWidget);
    });
  }

  for (final entry in {
    'en': 'Your bet on Draw was correct.',
    'ko': '무승부에 대한 예측이 맞았어요.',
    'ja': '引き分けへの予想が的中しました。',
    'zh': '你对平局的预测正确。',
  }.entries) {
    testWidgets('draw result uses the localized outcome in ${entry.key}',
        (tester) async {
      await pumpOverlay(tester,
          onDismiss: () {},
          language: entry.key,
          settlementNotice: const BetSettlementNotice(
            bet: FixtureBet(
              betId: 7,
              fixtureId: 83,
              outcome: BetOutcome.draw,
              stake: 100,
              probabilityText: '0.200000000000000000',
              decimalOdds: 5,
              potentialReturn: 500,
              status: 'won',
              revision: 2,
              payout: 500,
            ),
            selectionTeamId: null,
            selectionName: 'Draw',
          ));
      expect(
          find.textContaining(entry.value, findRichText: true), findsOneWidget);
    });
  }

  for (final language in ['en', 'ko', 'ja', 'zh']) {
    for (final inset in [0.0, 34.0]) {
      testWidgets(
          'sheet meets navigation at $language with bottom inset $inset',
          (tester) async {
        await pumpOverlay(tester,
            onDismiss: () {}, language: language, bottomInset: inset);
        await tester.pumpAndSettle();
        expect(find.textContaining('500'), findsOneWidget);
        expect(
          tester
              .getBottomLeft(find.byKey(const ValueKey('bet-settlement-sheet')))
              .dy,
          tester.getTopLeft(find.byType(OneTouchBottomNavigationBar)).dy,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('dismisses from the empty area and maybe later', (tester) async {
    var dismissCount = 0;
    await pumpOverlay(tester, onDismiss: () => dismissCount++);
    expect(find.byKey(const ValueKey('bet-settlement-close-button')),
        findsNothing);

    await tester.tapAt(const Offset(12, 12));
    expect(dismissCount, 1);

    await tester.tap(find.byKey(const ValueKey('bet-settlement-maybe-later')));
    expect(dismissCount, 2);
  });

  testWidgets('keeps taps inside the sheet from dismissing it', (tester) async {
    var dismissCount = 0;
    await pumpOverlay(tester, onDismiss: () => dismissCount++);

    final sheet = tester.getRect(
      find.byKey(const ValueKey('bet-settlement-sheet')),
    );
    await tester.tapAt(Offset(12, sheet.top + 12));
    expect(dismissCount, 0);
  });

  testWidgets('see results still opens the result', (tester) async {
    var resultCount = 0;
    await pumpOverlay(
      tester,
      onDismiss: () {},
      onSeeResults: () => resultCount++,
    );

    await tester.tap(find.byKey(const ValueKey('bet-settlement-see-results')));
    expect(resultCount, 1);
  });

  for (final entry in {
    'en': ('No points this time.', 'Your bet on Barcelona was not correct.'),
    'ko': ('이번엔 포인트를 받지 못했어요.', '바르셀로나에 대한 예측이 빗나갔어요.'),
  }.entries) {
    testWidgets('losing result copy matches in ${entry.key}', (tester) async {
      await pumpOverlay(tester,
          onDismiss: () {},
          language: entry.key,
          settlementNotice: resultNotice('lost'));
      expect(find.text(entry.value.$1), findsOneWidget);
      expect(find.textContaining(entry.value.$2, findRichText: true),
          findsOneWidget);
      expect(find.textContaining('You won 0'), findsNothing);
    });
  }

  for (final entry in {
    'en': (
      title: 'Your 100 points\nhave been returned',
      bodies: {
        'POSTPONED': 'Barcelona vs Real Madrid was postponed.',
        'CANCELLED': 'Barcelona vs Real Madrid was cancelled.',
        'WO': 'Barcelona vs Real Madrid was decided by walkover.',
        'ABANDONED': 'Barcelona vs Real Madrid was abandoned.',
        'AWARDED':
            'Barcelona vs Real Madrid: the result was decided by the organizer.',
        'DELETED':
            'Barcelona vs Real Madrid: the match record was deleted or changed.',
      },
      button: 'CONTINUE',
    ),
    'ko': (
      title: '100 pts를 돌려받았어요.',
      bodies: {
        'POSTPONED': '바르셀로나 vs 레알 마드리드 경기가 연기됐어요.',
        'CANCELLED': '바르셀로나 vs 레알 마드리드 경기가 취소됐어요.',
        'WO': '바르셀로나 vs 레알 마드리드 경기가 부전승으로 처리됐어요.',
        'ABANDONED': '바르셀로나 vs 레알 마드리드 경기가 도중에 중단됐어요.',
        'AWARDED': '바르셀로나 vs 레알 마드리드 경기 결과를 주최 측이 결정했어요.',
        'DELETED': '바르셀로나 vs 레알 마드리드 경기 기록이 삭제되거나 바뀌었어요.',
      },
      button: '확인',
    ),
    'ja': (
      title: '100ポイントが返還されました。',
      bodies: {
        'POSTPONED': 'FCバルセロナ vs レアル・マドリードの試合が延期されました。',
        'CANCELLED': 'FCバルセロナ vs レアル・マドリードの試合が中止になりました。',
        'WO': 'FCバルセロナ vs レアル・マドリードの試合は不戦勝扱いになりました。',
        'ABANDONED': 'FCバルセロナ vs レアル・マドリードの試合が途中で中断されました。',
        'AWARDED': 'FCバルセロナ vs レアル・マドリードの試合結果は主催者が決定しました。',
        'DELETED': 'FCバルセロナ vs レアル・マドリードの試合記録が削除または変更されました。',
      },
      button: '確認',
    ),
    'zh': (
      title: '已返还100积分。',
      bodies: {
        'POSTPONED': '巴塞罗那足球俱乐部 vs 皇家马德里足球俱乐部的比赛已延期。',
        'CANCELLED': '巴塞罗那足球俱乐部 vs 皇家马德里足球俱乐部的比赛已取消。',
        'WO': '巴塞罗那足球俱乐部 vs 皇家马德里足球俱乐部的比赛按一方不战而胜处理。',
        'ABANDONED': '巴塞罗那足球俱乐部 vs 皇家马德里足球俱乐部的比赛中途终止。',
        'AWARDED': '巴塞罗那足球俱乐部 vs 皇家马德里足球俱乐部的比赛结果由主办方决定。',
        'DELETED': '巴塞罗那足球俱乐部 vs 皇家马德里足球俱乐部的比赛记录已被删除或更改。',
      },
      button: '确定',
    ),
  }.entries) {
    for (final refund in entry.value.bodies.entries) {
      final reason = refund.key;
      final body = refund.value;
      testWidgets(
          'refund shows both teams and one action: $reason ${entry.key}',
          (tester) async {
        var dismissed = 0;
        var openedResults = 0;
        await pumpOverlay(tester,
            onDismiss: () => dismissed++,
            onSeeResults: () => openedResults++,
            language: entry.key,
            size: const Size(320, 568),
            settlementNotice: resultNotice('refunded', reason: reason));
        expect(find.text(entry.value.title), findsOneWidget);
        final description = find.text(body, findRichText: true);
        expect(description, findsOneWidget);
        final span = tester.widget<Text>(find.text(body)).textSpan as TextSpan;
        final highlighted = span.children!
            .whereType<TextSpan>()
            .where((child) => child.style?.fontWeight == FontWeight.w700)
            .map((child) => child.text);
        final names = namesByLanguage[entry.key]!;
        expect(highlighted, [
          names.team(83, 'Barcelona', short: true),
          names.team(84, 'Real Madrid', short: true),
        ]);
        expect(find.byKey(const ValueKey('bet-settlement-close-button')),
            findsNothing);
        expect(find.byKey(const ValueKey('bet-settlement-see-results')),
            findsNothing);
        expect(find.byKey(const ValueKey('bet-settlement-maybe-later')),
            findsNothing);
        await tester.tap(find.text(entry.value.button));
        expect(dismissed, 1);
        expect(openedResults, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final entry in {'en': 285.0, 'ko': 273.0}.entries) {
    testWidgets('refund sheet follows the ${entry.key} design height',
        (tester) async {
      final previousLocale = appLocaleController.value;
      appLocaleController.value = Locale(entry.key);
      addTearDown(() => appLocaleController.value = previousLocale);
      await pumpOverlay(tester,
          onDismiss: () {},
          language: entry.key,
          settlementNotice: resultNotice('refunded', reason: 'CANCELLED'));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('bet-settlement-sheet')))
            .height,
        closeTo(entry.value, 4),
      );
      final sheet =
          tester.getRect(find.byKey(const ValueKey('bet-settlement-sheet')));
      final icon = find.byKey(const ValueKey('bet-settlement-refund-icon'));
      expect(icon, findsOneWidget);
      expect(tester.widget<SvgPicture>(icon).bytesLoader, isNotNull);
      expect(tester.getRect(icon).top - sheet.top, 48);
      expect(tester.getSize(icon), const Size(56, 56));
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('settlement sheet matches $brightness colors and spacing',
        (tester) async {
      await pumpOverlay(tester, onDismiss: () {}, brightness: brightness);
      final dark = brightness == Brightness.dark;
      final sheet = find.byKey(const ValueKey('bet-settlement-sheet'));
      final decoration =
          tester.widget<Container>(sheet).decoration! as BoxDecoration;
      expect(decoration.color, dark ? const Color(0xFF272828) : Colors.white);
      final primary = find.descendant(
        of: find.byKey(const ValueKey('bet-settlement-see-results')),
        matching: find.byType(Material),
      );
      final secondary = find.descendant(
        of: find.byKey(const ValueKey('bet-settlement-maybe-later')),
        matching: find.byType(Material),
      );
      expect(tester.widget<Material>(primary).color,
          dark ? Colors.white : const Color(0xFF090A0A));
      expect(tester.widget<Material>(secondary).color,
          dark ? const Color(0xFF3D3D3D) : const Color(0xFFEBEBEB));

      final icon = find.byIcon(Icons.celebration_outlined);
      final title = find.text('You won 500 points!');
      final description = find.textContaining(
        'Your bet on Barcelona was correct.',
        findRichText: true,
      );
      expect(tester.getRect(icon).top - tester.getRect(sheet).top, 24);
      expect(tester.getRect(title).top - tester.getRect(icon).bottom, 16);
      expect(tester.getRect(description).top - tester.getRect(title).bottom, 8);
      expect(
          tester.getRect(secondary).top - tester.getRect(primary).bottom, 16);
    });
  }

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('settlement sheet fits $size in $brightness', (tester) async {
        await pumpOverlay(
          tester,
          onDismiss: () {},
          size: size,
          brightness: brightness,
          language: 'ko',
        );
        final sheet = find.byKey(const ValueKey('bet-settlement-sheet'));
        expect(tester.getRect(sheet).left, 0);
        expect(tester.getRect(sheet).right, size.width);
        expect(
          tester.getRect(sheet).bottom,
          tester.getRect(find.byType(OneTouchBottomNavigationBar)).top,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
