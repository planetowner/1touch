import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:onetouch/data/auth/login_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/SignComps/verify_email.dart';
import 'package:onetouch/SignComps/sign_up.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_request_exception.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/auth/email_code_challenge.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'package:onetouch/data/auth/registration_field.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Archivo')
          ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf')))
        .load();
    await (FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  for (final locale in [const Locale('en'), const Locale('ko')]) {
    for (final brightness in Brightness.values) {
      testWidgets('signup geometry matches Figma with $locale $brightness',
          (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
        tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        final previousLocale = appLocaleController.value;
        appLocaleController.value = locale;
        addTearDown(() => appLocaleController.value = previousLocale);
        var failLookup = true;
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: (brightness == Brightness.dark
                    ? app_style.darkThemeForLocale(locale)
                    : app_style.lightThemeForLocale(locale))
                .copyWith(platform: TargetPlatform.iOS),
            locale: locale,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationDelegates,
            home: EmailSignUpScreen(
              authService: _service(
                _FakeAuthRepository(availability: (_, __) async {
                  if (failLookup) throw StateError('Connection failed');
                  return true;
                }),
                AuthSession(),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        final normalCursorColors = tester
            .widgetList<EditableText>(find.byType(EditableText))
            .map((field) => field.cursorColor)
            .toList();

        Rect inputRect(Finder field) {
          final editable =
              find.descendant(of: field, matching: find.byType(EditableText));
          final box = InputDecorator.containerOf(tester.element(editable))!;
          return box.localToGlobal(Offset.zero) & box.size;
        }

        void expectInputGeometry() {
          final fields = find.byType(TextFormField);
          expect(fields, findsNWidgets(5));
          for (var index = 0; index < 5; index++) {
            expect(
                tester
                    .widget<EditableText>(find.descendant(
                        of: fields.at(index),
                        matching: find.byType(EditableText)))
                    .cursorColor,
                normalCursorColors[index]);
            // Figma 7178:41928의 입력칸 실측값으로 확인해요.
            expect(inputRect(fields.at(index)).size, const Size(345, 56));
            final valueRect = tester.getRect(find.descendant(
                of: fields.at(index), matching: find.byType(EditableText)));
            expect(valueRect.left, 36);
            expect(inputRect(fields.at(index)).bottom - valueRect.bottom,
                index < 3 ? 8 : 6);
            final decorator = tester.widget<InputDecorator>(find.descendant(
                of: fields.at(index), matching: find.byType(InputDecorator)));
            expect(
                (decorator.decoration.border! as OutlineInputBorder)
                    .borderRadius,
                BorderRadius.circular(8));
          }
          expect(tester.takeException(), isNull);
        }

        expectInputGeometry();
        Rect textRect(String text) =>
            tester.getRect(find.text(translateMessage(locale, text)));
        final headerTitle = find.descendant(
            of: find.byType(AppBar), matching: find.byType(Text));
        expect(tester.getRect(headerTitle).center, const Offset(196.5, 71));
        expect(textRect('ID').top, 139);
        expect(
            tester.getRect(find.byKey(const ValueKey('email-sign-up-button'))),
            const Rect.fromLTWH(24, 724, 345, 56));
        final backIcon = find.byWidgetPredicate((widget) =>
            widget is SvgPicture &&
            (widget.bytesLoader as SvgAssetLoader).assetName ==
                'assets/auth/back.svg');
        expect(tester.getRect(backIcon), const Rect.fromLTWH(24, 59, 32, 24));
        final fields = find.byType(TextFormField);
        final labels = [
          'ID',
          'Nickname',
          'Email',
          'Password',
          'Retype Password'
        ];
        for (var i = 0; i < 5; i++) {
          expect(textRect(labels[i]).top - inputRect(fields.at(i)).top,
              i < 3 ? 8 : 6);
          final editable = tester.widget<EditableText>(find.descendant(
              of: fields.at(i), matching: find.byType(EditableText)));
          expect(editable.style.letterSpacing, 0);
          expect(
              editable.style.height, locale.languageCode == 'ko' ? 1.6 : 1.3);
          if (i < 3) {
            expect(
                inputRect(fields.at(i + 1)).top -
                    inputRect(fields.at(i)).bottom,
                24);
          }
        }
        final help =
            textRect('Choose a password that is 8 or more characters long.');
        expect(help.top - inputRect(fields.at(3)).bottom, 8);
        expect(inputRect(fields.at(4)).top - help.bottom, 24);
        expect(find.text('••••••••'), findsNothing);
        for (final field
            in tester.widgetList<EditableText>(find.byType(EditableText))) {
          expect(field.controller.text, isEmpty);
        }
        if (brightness == Brightness.dark) {
          final buttonText = tester.widget<Text>(find.descendant(
              of: find.byKey(const ValueKey('email-sign-up-button')),
              matching: find.byType(Text)));
          expect(buttonText.style!.color, const Color(0xFF0A0A0A));
          expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
              const Color(0xFF0A0A0A));
        }
        final eyeIcons = tester
            .widgetList<SvgPicture>(find.byType(SvgPicture))
            .where((icon) =>
                (icon.bytesLoader as SvgAssetLoader).assetName ==
                'assets/auth/visibility_off.svg');
        expect(eyeIcons, hasLength(2));
        for (final (index, icon) in eyeIcons.indexed) {
          expect((icon.bytesLoader as SvgAssetLoader).assetName,
              'assets/auth/visibility_off.svg');
          expect(Size(icon.width!, icon.height!), const Size(24, 24));
          expect(
              tester.getRect(find.byWidget(icon)),
              Rect.fromLTWH(
                  333, inputRect(fields.at(index + 3)).top + 16, 24, 24));
        }
        Future<void> savePreview([String suffix = '']) async {
          final boundary = boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final picture = await boundary.toImage(pixelRatio: 1);
            final bytes =
                (await picture.toByteData(format: ui.ImageByteFormat.png))!
                    .buffer
                    .asUint8List();
            final file = File(
                'build/signup-${locale.languageCode}-${brightness.name}$suffix.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes);
            picture.dispose();
          });
        }

        await savePreview();

        final username = find.byKey(const ValueKey('signup-username-field'));
        await tester.enterText(username, 'member');
        await tester.pumpAndSettle();
        expectInputGeometry();
        failLookup = false;
        await tester.tap(find.byTooltip(translateMessage(locale, 'Try again')));
        await tester.pumpAndSettle();
        expect(
            find.text(translateMessage(locale, 'This username is available!')),
            findsOneWidget);
        expect(
            textRect('This username is available!').top -
                inputRect(username).bottom,
            8);
        expect(
            inputRect(fields.at(1)).top -
                textRect('This username is available!').bottom,
            24);
        expectInputGeometry();

        for (final key in [
          'signup-password-field',
          'signup-confirm-password-field',
        ]) {
          final field = find.byKey(ValueKey(key));
          final textField = tester.widget<TextField>(
              find.descendant(of: field, matching: find.byType(TextField)));
          expect(textField.decoration!.hintText, isNull);
          await tester.enterText(field, 'Password123');
          await tester.pumpAndSettle();
          final editable = tester.widget<EditableText>(
              find.descendant(of: field, matching: find.byType(EditableText)));
          expect(editable.obscureText, isTrue);
          expect(editable.controller.text, 'Password123');
        }
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await savePreview('-filled');
        for (final key in [
          'signup-password-field',
          'signup-confirm-password-field',
        ]) {
          final field = find.byKey(ValueKey(key));
          final editable =
              find.descendant(of: field, matching: find.byType(EditableText));
          final visibility =
              find.descendant(of: field, matching: find.byType(IconButton));
          for (final obscure in [false, true]) {
            await tester.tap(visibility);
            await tester.pumpAndSettle();
            expect(tester.widget<EditableText>(editable).obscureText, obscure);
            expect(tester.widget<EditableText>(editable).controller.text,
                'Password123');
          }
          await tester.enterText(field, '');
          await tester.pumpAndSettle();
          expect(
              tester.widget<EditableText>(editable).controller.text, isEmpty);
          expect(find.text('••••••••'), findsNothing);
        }
        expectInputGeometry();

        final password = find.byKey(const ValueKey('signup-password-field'));
        await tester.tap(
            find.descendant(of: password, matching: find.byType(IconButton)));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<EditableText>(find.descendant(
                    of: password, matching: find.byType(EditableText)))
                .obscureText,
            isFalse);
        final confirm =
            find.byKey(const ValueKey('signup-confirm-password-field'));
        await tester.enterText(confirm, 'different');
        await tester.pumpAndSettle();
        final error =
            find.text(translateMessage(locale, 'Passwords do not match.'));
        expect(error, findsNothing);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(error, findsOneWidget);
        expect(tester.getRect(error).top,
            greaterThanOrEqualTo(inputRect(confirm).bottom));
        expect(
            tester
                .widget<RichText>(
                    find.descendant(of: error, matching: find.byType(RichText)))
                .text
                .style!
                .color,
            Theme.of(tester.element(confirm)).colorScheme.error);
        expectInputGeometry();
      });
    }
  }

  testWidgets(
      'signup shows a password mismatch only after confirmation loses focus',
      (tester) async {
    await _pumpSignup(tester, _FakeAuthRepository());
    final password = find.byKey(const ValueKey('signup-password-field'));
    final confirm = find.byKey(const ValueKey('signup-confirm-password-field'));
    final error = find.text('Passwords do not match.');
    final confirmEditable =
        find.descendant(of: confirm, matching: find.byType(EditableText));

    await tester.enterText(password, 'Password123');
    await tester.enterText(confirm, 'Pass');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(error, findsNothing);
    expect(tester.widget<EditableText>(confirmEditable).focusNode.hasFocus,
        isTrue);

    await tester.tap(password);
    await tester.pumpAndSettle();
    expect(error, findsOneWidget);

    await tester.enterText(confirm, 'Password12');
    await tester.pumpAndSettle();
    expect(error, findsOneWidget);
    await tester.enterText(confirm, 'Password123');
    await tester.pump();
    expect(
        tester
            .state<FormFieldState<String>>(find.descendant(
                of: confirm, matching: find.byType(TextFormField)))
            .hasError,
        isFalse);
    await tester.pumpAndSettle();
    expect(error, findsNothing);
    expect(tester.widget<EditableText>(confirmEditable).focusNode.hasFocus,
        isTrue);

    await tester.enterText(confirm, 'Password1234');
    await tester.pumpAndSettle();
    expect(error, findsNothing);
    await tester.tap(password);
    await tester.pumpAndSettle();
    expect(error, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'signup clears a mismatch when the first password is edited to match',
      (tester) async {
    await _pumpSignup(tester, _FakeAuthRepository());
    final password = find.byKey(const ValueKey('signup-password-field'));
    final confirm = find.byKey(const ValueKey('signup-confirm-password-field'));
    final error = find.text('Passwords do not match.');

    await tester.enterText(password, 'Password123');
    await tester.enterText(confirm, 'Different123');
    await tester.tap(password);
    await tester.pumpAndSettle();
    expect(error, findsOneWidget);

    await tester.enterText(password, 'Different123');
    await tester.pump();
    expect(
        tester
            .state<FormFieldState<String>>(find.descendant(
                of: confirm, matching: find.byType(TextFormField)))
            .hasError,
        isFalse);
    await tester.pumpAndSettle();
    expect(error, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final confirmation in ['', 'Pass']) {
    testWidgets(
        'signup submission validates an unblurred confirmation "$confirmation"',
        (tester) async {
      final repository = _FakeAuthRepository();
      await _pumpSignup(tester, repository);
      final password = find.byKey(const ValueKey('signup-password-field'));
      final confirm =
          find.byKey(const ValueKey('signup-confirm-password-field'));
      final error = find.text('Passwords do not match.');

      await tester.enterText(password, 'Password123');
      await tester.enterText(confirm, confirmation);
      await tester.pumpAndSettle();
      expect(error, findsNothing);
      final confirmEditable =
          find.descendant(of: confirm, matching: find.byType(EditableText));
      expect(tester.widget<EditableText>(confirmEditable).focusNode.hasFocus,
          isTrue);

      await tester.tap(find.byKey(const ValueKey('email-sign-up-button')));
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(confirmEditable).focusNode.hasFocus,
          isTrue);
      expect(error, findsOneWidget);
      expect(repository.requestedEmails, isEmpty);

      await tester.enterText(confirm, 'Password123');
      await tester.pump();
      expect(
          tester
              .state<FormFieldState<String>>(find.descendant(
                  of: confirm, matching: find.byType(TextFormField)))
              .hasError,
          isFalse);
      await tester.pumpAndSettle();
      expect(error, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final lookupFails in [false, true]) {
    testWidgets(
        'signup keyboard advances through fields (lookupFails: $lookupFails)',
        (tester) async {
      await _pumpSignup(tester,
          _FakeAuthRepository(availability: (_, __) async {
        if (lookupFails) throw StateError('Connection failed');
        return true;
      }));
      final fields = find.byType(EditableText);
      await tester.tap(find.byKey(const ValueKey('signup-username-field')));
      addTearDown(tester.view.resetViewInsets);
      tester.view.viewInsets = const FakeViewPadding(bottom: 340);
      await tester.pumpAndSettle();
      for (final (index, value) in [
        'member',
        'Supporter',
        'member@example.com',
        'Password123',
        'Password123',
      ].indexed) {
        expect(tester.widget<EditableText>(fields.at(index)).focusNode.hasFocus,
            isTrue,
            reason:
                'Field $index should be focused; current focus: ${FocusManager.instance.primaryFocus}');
        tester.testTextInput.enterText(value);
        await tester.pumpAndSettle();
        final input = tester.widget<EditableText>(fields.at(index));
        expect(input.textInputAction,
            index == 4 ? TextInputAction.done : TextInputAction.next);
        if (index == 4) {
          final confirm =
              find.byKey(const ValueKey('signup-confirm-password-field'));
          expect(852 - 340 - tester.getRect(confirm).bottom, closeTo(24, 0.1));
        }
        await tester.testTextInput.receiveAction(input.textInputAction!);
        await tester.pumpAndSettle();
      }
      expect(
          tester.widget<EditableText>(fields.last).focusNode.hasFocus, isFalse);
      expect(find.text('Verification destination'), findsNothing);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.mobile());
  }

  for (final size in [const Size(320, 568), const Size(393, 852)]) {
    testWidgets('signup confirmation stays 24px above keyboard at $size',
        (tester) async {
      await _pumpSignup(tester, _FakeAuthRepository());
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      for (final (key, value) in [
        ('signup-username-field', 'member'),
        ('signup-display-name-field', 'Supporter'),
        ('signup-email-field', 'member@example.com'),
        ('signup-password-field', 'Password123'),
      ]) {
        await tester.enterText(find.byKey(ValueKey(key)), value);
        await tester.pumpAndSettle();
      }
      final confirm =
          find.byKey(const ValueKey('signup-confirm-password-field'));
      if (tester.getRect(confirm).bottom > size.height) {
        await tester.ensureVisible(confirm);
      }
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      for (final keyboardHeight in [340.0, 380.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
        await tester.pumpAndSettle();
        expect(size.height - keyboardHeight - tester.getRect(confirm).bottom,
            closeTo(24, 0.1));
      }
      tester.testTextInput.enterText('Password123');
      await tester.pumpAndSettle();
      expect(
          size.height - 380 - tester.getRect(confirm).bottom, closeTo(24, 0.1));
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.mobile());
  }

  testWidgets('signup terms and button scroll after the input fields',
      (tester) async {
    tester.view.physicalSize = const Size(393, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const MaterialApp(home: EmailSignUpScreen()));

    final username = find.byKey(const ValueKey('signup-username-field'));
    final checkbox = find.byType(Checkbox);
    final button = find.byKey(const ValueKey('email-sign-up-button'));
    final usernameTop = tester.getTopLeft(username).dy;
    final checkboxTop = tester.getTopLeft(checkbox).dy;
    final buttonTop = tester.getTopLeft(button).dy;

    await tester.drag(find.byKey(const ValueKey('signup-fields-scroll')),
        const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(username).dy, lessThan(usernameTop));
    expect(tester.getTopLeft(checkbox).dy, lessThan(checkboxTop));
    expect(tester.getTopLeft(button).dy, lessThan(buttonTop));

    final scrolledCheckboxTop = tester.getTopLeft(checkbox).dy;
    final scrolledButtonTop = tester.getTopLeft(button).dy;

    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(checkbox).dy, scrolledCheckboxTop);
    expect(tester.getTopLeft(button).dy, scrolledButtonTop);
    expect(
        tester
            .getRect(find.byKey(const ValueKey('signup-fields-scroll')))
            .bottom,
        568 - 280);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('signup consent appears after scrolling with keyboard at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(const MaterialApp(home: EmailSignUpScreen()));
      await tester.pumpAndSettle();

      final checkbox = find.byType(Checkbox);
      final button = find.byKey(const ValueKey('email-sign-up-button'));
      final checkboxBefore = tester.getRect(checkbox);
      final buttonBefore = tester.getRect(button);
      await tester.tap(find.byKey(const ValueKey('signup-username-field')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();

      expect(
          tester
              .widget<Scaffold>(find.byType(Scaffold))
              .resizeToAvoidBottomInset,
          isFalse);
      expect(tester.getRect(checkbox), checkboxBefore);
      expect(tester.getRect(button), buttonBefore);
      expect(tester.getRect(checkbox).top,
          greaterThanOrEqualTo(size.height - 280));

      final scroll = tester.state<ScrollableState>(find
          .descendant(
            of: find.byKey(const ValueKey('signup-fields-scroll')),
            matching: find.byType(Scrollable),
          )
          .first);
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.getRect(checkbox).top, lessThan(size.height - 280));
      expect(
          tester.getRect(button).bottom, lessThanOrEqualTo(size.height - 280));
      expect(
          tester.getRect(checkbox).top,
          greaterThan(tester
              .getRect(
                  find.byKey(const ValueKey('signup-confirm-password-field')))
              .bottom));
      expect(tester.takeException(), isNull);
    });
  }

  for (final field in RegistrationField.values) {
    testWidgets('blocks duplicate $field and rechecks its edited value',
        (tester) async {
      final replacement = switch (field) {
        RegistrationField.username => 'new_member',
        RegistrationField.displayName => 'NewMember',
        RegistrationField.email => 'new@example.com',
      };
      final repository = _FakeAuthRepository(
          availability: (checkedField, value) async =>
              checkedField != field || value == replacement);
      await _pumpSignup(tester, repository);
      final input = find.byKey(
          ValueKey('signup-${field.apiValue.replaceAll('_', '-')}-field'));
      final editable =
          find.descendant(of: input, matching: find.byType(EditableText));
      final normalCursorColor =
          tester.widget<EditableText>(editable).cursorColor;
      await _fillSignup(tester);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      expect(
          repository.availabilityRequests,
          containsAll([
            (RegistrationField.username, 'member'),
            (RegistrationField.displayName, 'Supporter'),
            (RegistrationField.email, 'member@example.com'),
          ]));
      expect(find.text('Already in use.'), findsOneWidget);
      expect(
          tester.widget<EditableText>(editable).cursorColor, normalCursorColor);
      final submit = find.byKey(const ValueKey('email-sign-up-button'));
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      expect(repository.requestedEmails, isEmpty);

      await tester.enterText(
          find.byKey(
              ValueKey('signup-${field.apiValue.replaceAll('_', '-')}-field')),
          replacement);
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      expect(
          tester.widget<EditableText>(editable).cursorColor, normalCursorColor);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(repository.requestedEmails, [
        field == RegistrationField.email ? replacement : 'member@example.com',
      ]);
      expect(find.text('Verification destination'), findsOneWidget);
    });
  }

  testWidgets('waits for all three availability results before signup',
      (tester) async {
    final results = {
      for (final field in RegistrationField.values) field: Completer<bool>(),
    };
    final repository =
        _FakeAuthRepository(availability: (field, _) => results[field]!.future);
    await _pumpSignup(tester, repository);
    await _fillSignup(tester);
    await tester.pump(const Duration(milliseconds: 250));
    final submit = find.byKey(const ValueKey('email-sign-up-button'));
    expect(find.text('Checking availability...'), findsNWidgets(3));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    results[RegistrationField.username]!.complete(true);
    results[RegistrationField.displayName]!.complete(true);
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(repository.requestedEmails, isEmpty);
    results[RegistrationField.email]!.complete(true);
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.enterText(
        find.byKey(const ValueKey('signup-username-field')), 'changed');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('keeps signup blocked after lookup failure until retry succeeds',
      (tester) async {
    var emailChecks = 0;
    final repository = _FakeAuthRepository(availability: (field, _) async {
      if (field == RegistrationField.email && emailChecks++ == 0) {
        throw StateError('Connection failed');
      }
      return true;
    });
    await _pumpSignup(tester, repository);
    await _fillSignup(tester);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    final submit = find.byKey(const ValueKey('email-sign-up-button'));
    expect(
        find.text('Unable to check availability. Try again.'), findsOneWidget);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(repository.requestedEmails, isEmpty);
    final retry = find.byTooltip('Try again');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();
    expect(emailChecks, 2);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });

  for (final locale in appSupportedLocales) {
    testWidgets('signup requires no personal name with $locale',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      EmailRegistrationDraft? draft;
      final router = GoRouter(initialLocation: '/signup', routes: [
        GoRoute(
            path: '/signup',
            builder: (_, __) => EmailSignUpScreen(
                  authService: _service(_FakeAuthRepository(), AuthSession()),
                )),
        GoRoute(
            path: '/auth/verify',
            builder: (_, state) {
              draft = state.extra! as EmailRegistrationDraft;
              return const Scaffold(body: Text('Verification destination'));
            }),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
        locale: locale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
      ));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('signup-first-name-field')), findsNothing);
      expect(
          find.byKey(const ValueKey('signup-last-name-field')), findsNothing);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'member');
      await tester.enterText(
          find.byKey(const ValueKey('signup-display-name-field')), 'Supporter');
      await tester.enterText(fields.at(2), 'member@example.com');
      await tester.enterText(fields.at(3), 'Password123');
      await tester.enterText(fields.at(4), 'Password123');
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(
          find.text(translateMessage(locale, 'Available.')), findsNWidgets(2));
      final submit = find.byKey(const ValueKey('email-sign-up-button'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Verification destination'), findsOneWidget);
      expect(draft!.displayName, 'Supporter');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('signup checks ID and nickname before requesting an email code',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeAuthRepository();
    final router = GoRouter(initialLocation: '/signup', routes: [
      GoRoute(
        path: '/signup',
        builder: (_, __) => EmailSignUpScreen(
          authService: _service(repository, AuthSession()),
        ),
      ),
      GoRoute(
        path: '/auth/verify',
        builder: (_, __) =>
            const Scaffold(body: Text('Verification destination')),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '.john');
    await tester.enterText(fields.at(1), 'June_Kim');
    await tester.enterText(fields.at(2), 'john@example.com');
    await tester.enterText(fields.at(3), 'Password123');
    await tester.enterText(fields.at(4), 'Password123');
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    final submit = find.byKey(const ValueKey('email-sign-up-button'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(repository.requestedEmails, isEmpty);
    expect(find.textContaining('Dots cannot be first'), findsOneWidget);
    expect(find.textContaining('Korean counts as 2'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(submit)).removeCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.enterText(fields.at(0), 'john_doe');
    await tester.enterText(fields.at(1), '메이플123');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    tester.testTextInput.hide();
    await tester.pump();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repository.requestedEmails, ['john@example.com']);
    expect(find.text('Verification destination'), findsOneWidget);
  });

  testWidgets('duplicate account returns to signup with inputs preserved',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeAuthRepository()..duplicateRegistration = true;
    final router = GoRouter(initialLocation: '/signup', routes: [
      GoRoute(
        path: '/signup',
        builder: (_, __) =>
            EmailSignUpScreen(authService: _service(repository, AuthSession())),
      ),
      GoRoute(
        path: '/auth/verify',
        builder: (_, state) => EmailVerifyScreen(
          email: (state.extra! as EmailRegistrationDraft).email,
          registrationDraft: state.extra! as EmailRegistrationDraft,
          authService: _service(repository, AuthSession()),
        ),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    final fields = find.byType(TextFormField);
    for (final (index, value) in [
      'taken',
      'Supporter',
      'member@example.com',
      'Password123'
    ].indexed) {
      await tester.enterText(fields.at(index), value);
    }
    await tester.enterText(fields.at(4), 'Password123');
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    tester.testTextInput.hide();
    await tester.pump();
    await tester
        .ensureVisible(find.byKey(const ValueKey('email-sign-up-button')));
    await tester.tap(find.byKey(const ValueKey('email-sign-up-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('email-verification-code')), '123456');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('verify-email-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('signup-username-field')), findsOneWidget);
    expect(find.text('Email, username, or nickname is already registered'),
        findsOneWidget);
    expect(
        tester.widget<TextFormField>(fields.at(0)).controller!.text, 'taken');
    await tester.enterText(fields.at(0), 'different');
    expect(tester.widget<TextFormField>(fields.at(0)).controller!.text,
        'different');
    expect(tester.takeException(), isNull);
  });

  testWidgets('submits the six-digit code and establishes the session',
      (tester) async {
    final repository = _FakeAuthRepository();
    final session = AuthSession();
    final router = _router(_service(repository, session));
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(
      find.byKey(const ValueKey('email-verification-code')),
      '123456',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('verify-email-button')),
    );
    await tester.tap(find.byKey(const ValueKey('verify-email-button')));
    await tester.pumpAndSettle();

    expect(repository.registrationCode, '123456');
    expect(repository.registrationChallengeId, 'initial-challenge');
    expect(session.requestHeaders, {
      'Authorization': 'Bearer registered-session',
    });
    expect(find.text('Welcome destination'), findsOneWidget);
  });

  testWidgets('resend replaces the challenge after the cooldown',
      (tester) async {
    final repository = _FakeAuthRepository();
    final router = _router(_service(repository, AuthSession()));
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Send again (60s)'), findsOneWidget);

    await tester.pump(const Duration(seconds: 60));
    expect(find.text('Send again'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('resend-email-code')));
    await tester.pump();

    expect(repository.requestedEmails, ['member@example.com']);
    expect(find.text('A new verification code was sent.'), findsOneWidget);
    expect(find.text('Send again (60s)'), findsOneWidget);
  });
}

Future<void> _pumpSignup(
    WidgetTester tester, _FakeAuthRepository repository) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(initialLocation: '/signup', routes: [
    GoRoute(
      path: '/signup',
      builder: (_, __) => EmailSignUpScreen(
        authService: _service(repository, AuthSession()),
      ),
    ),
    GoRoute(
      path: '/auth/verify',
      builder: (_, __) =>
          const Scaffold(body: Text('Verification destination')),
    ),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
}

Future<void> _fillSignup(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  for (final (index, value) in [
    (0, 'member'),
    (1, 'Supporter'),
    (2, 'member@example.com'),
    (3, 'Password123'),
    (4, 'Password123'),
  ]) {
    await tester.enterText(fields.at(index), value);
  }
  await tester.ensureVisible(find.byType(Checkbox));
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
}

AuthService _service(AuthRepository repository, AuthSession session) =>
    AuthService(
      googleIdentityService: _UnusedGoogleIdentityService(),
      repository: repository,
      session: session,
    );

GoRouter _router(AuthService service) => GoRouter(
      initialLocation: '/verify',
      routes: [
        GoRoute(
          path: '/verify',
          builder: (_, __) => EmailVerifyScreen(
            email: 'member@example.com',
            authService: service,
            registrationDraft: const EmailRegistrationDraft(
              username: 'member',
              displayName: 'Member',
              email: 'member@example.com',
              password: 'Password123',
              challengeId: 'initial-challenge',
              expiresInSeconds: 600,
            ),
          ),
        ),
        GoRoute(
          path: '/session',
          builder: (_, __) => const Scaffold(body: Text('Welcome destination')),
        ),
      ],
    );

class _UnusedGoogleIdentityService implements GoogleIdentityService {
  @override
  Future<String> authenticate() => throw UnimplementedError();
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.availability});

  final Future<bool> Function(RegistrationField, String)? availability;
  final availabilityRequests = <(RegistrationField, String)>[];

  @override
  Future<bool> isRegistrationValueAvailable({
    required RegistrationField field,
    required String value,
  }) async {
    availabilityRequests.add((field, value));
    return availability == null ? true : await availability!(field, value);
  }

  @override
  Future<void> resetPassword(
          {required String challengeId,
          required String code,
          required String password}) =>
      throw UnimplementedError();

  @override
  Future<String> signInWithSocial(
          {required LoginProvider provider,
          required Map<String, String> credentials}) =>
      throw UnimplementedError();

  final requestedEmails = <String>[];
  String? registrationChallengeId;
  String? registrationCode;
  bool duplicateRegistration = false;

  @override
  Future<EmailCodeChallenge> requestEmailCode({
    required String email,
    EmailCodePurpose purpose = EmailCodePurpose.signup,
  }) async {
    requestedEmails.add(email);
    return const EmailCodeChallenge(
      challengeId: 'replacement-challenge',
      expiresInSeconds: 600,
    );
  }

  @override
  Future<String> registerWithEmail({
    required String challengeId,
    required String code,
    required String password,
    required String username,
    required String displayName,
  }) async {
    registrationChallengeId = challengeId;
    registrationCode = code;
    if (duplicateRegistration) {
      throw const AuthRequestException(
          statusCode: 409,
          message: 'Email, username, or nickname is already registered');
    }
    return 'registered-session';
  }

  @override
  Future<String> signInWithGoogle({required String idToken}) =>
      throw UnimplementedError();

  @override
  Future<String> signInWithPassword({
    required String username,
    required String password,
  }) =>
      throw UnimplementedError();
}
