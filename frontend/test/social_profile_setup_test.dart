import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/SignComps/social_profile_setup.dart';
import 'package:onetouch/l10n/app_localizations.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('social profile accepts three fields at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      (String, String, String)? submitted;
      await tester.pumpWidget(MaterialApp(
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: SocialProfileSetup(
          checkNicknameAvailability: (_) async => true,
          onContinue: (nickname, firstName, lastName) async =>
              submitted = (nickname, firstName, lastName),
          onBack: () async {},
        ),
      ));

      expect(find.text('Pick a nickname'), findsOneWidget);
      expect(find.text('Username'), findsNothing);
      expect(find.text('CONTINUE'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('social-nickname-field')), 'Supporter');
      await tester.enterText(
          find.byKey(const ValueKey('social-first-name-field')), 'First');
      await tester.enterText(
          find.byKey(const ValueKey('social-last-name-field')), 'Last');
      await tester.pumpAndSettle();
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(submitted, ('Supporter', 'First', 'Last'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unavailable nickname cannot be submitted', (tester) async {
    var submitted = false;
    await tester.pumpWidget(MaterialApp(
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      home: SocialProfileSetup(
        checkNicknameAvailability: (_) async => false,
        onContinue: (_, __, ___) async => submitted = true,
        onBack: () async {},
      ),
    ));
    await tester.enterText(
        find.byKey(const ValueKey('social-nickname-field')), 'TakenName');
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(submitted, isFalse);
  });
}
