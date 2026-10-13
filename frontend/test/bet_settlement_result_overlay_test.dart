import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/bottom_navigation.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/features/betting/bet_settlement_notifications.dart';
import 'package:onetouch/models/betting.dart';

void main() {
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
    selectionName: 'Barcelona',
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
      MaterialApp(
        theme: brightness == Brightness.dark ? darktheme : whitetheme,
        locale: Locale(language),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
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
    );
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

  testWidgets('winning result uses Korean points wording', (tester) async {
    await pumpOverlay(tester, onDismiss: () {}, language: 'ko');
    expect(find.text('500 포인트를 획득했어요!'), findsOneWidget);
    expect(
      find.textContaining('Barcelona에 대한 베팅이 적중했어요.', findRichText: true),
      findsOneWidget,
    );
  });

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

  for (final status in ['lost', 'refunded']) {
    for (final language in ['en', 'ko']) {
      testWidgets('settlement copy matches $status in $language',
          (tester) async {
        final refund = status == 'refunded';
        await pumpOverlay(
          tester,
          onDismiss: () {},
          language: language,
          settlementNotice: BetSettlementNotice(
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
              payout: refund ? 100 : 0,
            ),
            selectionName: 'Barcelona',
          ),
        );
        expect(
          find.text(refund
              ? language == 'ko'
                  ? '100 포인트가 반환됐어요.'
                  : '100 points returned.'
              : language == 'ko'
                  ? '이번엔 포인트를 얻지 못했어요.'
                  : 'No points this time.'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            language == 'ko'
                ? refund
                    ? 'Barcelona에 대한 베팅 포인트가 반환됐어요.'
                    : 'Barcelona에 대한 베팅이 적중하지 않았어요.'
                : refund
                    ? 'Your bet on Barcelona was refunded.'
                    : 'Your bet on Barcelona was not correct.',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(find.textContaining('You won 0'), findsNothing);
      });
    }
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
