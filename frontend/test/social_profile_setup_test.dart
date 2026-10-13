import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/SignComps/auth_widgets.dart';
import 'package:onetouch/SignComps/social_profile_setup.dart';
import 'package:onetouch/l10n/app_localizations.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('social profile accepts only a nickname at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? submitted;
      await tester.pumpWidget(MaterialApp(
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: SocialProfileSetup(
          checkNicknameAvailability: (_) async => true,
          onContinue: (nickname) async => submitted = nickname,
          onBack: () async {},
        ),
      ));

      expect(find.text('Pick a nickname'), findsOneWidget);
      expect(find.text('Username'), findsNothing);
      expect(find.text('CONTINUE'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('social-nickname-field')), 'Supporter');
      await tester.pumpAndSettle();
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(submitted, 'Supporter');
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('First name'), findsNothing);
      expect(find.text('Last name'), findsNothing);
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
        onContinue: (_) async => submitted = true,
        onBack: () async {},
      ),
    ));
    await tester.enterText(
        find.byKey(const ValueKey('social-nickname-field')), 'TakenName');
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(
        tester
            .state<FormFieldState<String>>(find.byType(TextFormField))
            .hasError,
        isTrue);
    expect(submitted, isFalse);
  });

  for (final locale in appSupportedLocales) {
    for (final editToRetry in [false, true]) {
      testWidgets(
          'social availability failure recovers by '
          '${editToRetry ? "editing" : "retry icon"} in $locale',
          (tester) async {
        var result = Completer<bool>();
        final requests = <String>[];
        String? submitted;
        await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          home: SocialProfileSetup(
            checkNicknameAvailability: (value) {
              requests.add(value);
              return result.future;
            },
            onContinue: (value) async => submitted = value,
            onBack: () async {},
          ),
        ));
        final field = find.byKey(const ValueKey('social-nickname-field'));
        final button = find.byType(FilledButton);
        Finder message(String key) => find.text(translateMessage(locale, key));

        await tester.enterText(field, 'Supporter');
        await tester.pump();
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        expect(message('Checking availability. Please wait.'), findsOneWidget);
        final spinner = find.descendant(
            of: field, matching: find.byType(CircularProgressIndicator));
        expect(spinner, findsOneWidget);
        expect(
            tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
        await tester.pump(const Duration(milliseconds: 250));
        expect(requests, ['Supporter']);

        result.completeError(StateError('Connection failed'));
        await tester.pumpAndSettle();
        expect(message('Unable to check availability. Please try again.'),
            findsOneWidget);
        final error = tester.widget<AuthFieldMessage>(find.byWidgetPredicate(
            (widget) => widget is AuthFieldMessage && widget.error));
        expect(
            error.text,
            translateMessage(
                locale, 'Unable to check availability. Please try again.'));
        expect(spinner, findsNothing);
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        expect(
            tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
        expect(submitted, isNull);

        result = Completer<bool>();
        if (editToRetry) {
          await tester.enterText(field, 'NewMember');
        } else {
          await tester
              .tap(find.byTooltip(translateMessage(locale, 'Try again')));
        }
        await tester.pump();
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        expect(spinner, findsOneWidget);
        expect(find.byTooltip(translateMessage(locale, 'Try again')),
            findsNothing);
        await tester.pump(const Duration(milliseconds: 250));
        final expectedNickname = editToRetry ? 'NewMember' : 'Supporter';
        expect(requests, ['Supporter', expectedNickname]);

        result.complete(true);
        await tester.pumpAndSettle();
        expect(spinner, findsNothing);
        expect(message("It's available."), findsOneWidget);
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(submitted, expectedNickname);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('automatically checks a prefilled social nickname',
      (tester) async {
    final result = Completer<bool>();
    final requests = <String>[];
    String? submitted;
    await tester.pumpWidget(MaterialApp(
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      home: SocialProfileSetup(
        initialNickname: 'Supporter',
        checkNicknameAvailability: (value) {
          requests.add(value);
          return result.future;
        },
        onContinue: (value) async => submitted = value,
        onBack: () async {},
      ),
    ));
    await tester.pump(const Duration(milliseconds: 250));
    expect(requests, ['Supporter']);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    result.complete(true);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(submitted, 'Supporter');
    expect(tester.takeException(), isNull);
  });
}
