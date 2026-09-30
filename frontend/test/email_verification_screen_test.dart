import 'dart:async';

import 'package:onetouch/data/auth/login_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/SignComps/VerifyEmail.dart';
import 'package:onetouch/SignComps/SignUp.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/data/auth/auth_repository.dart';
import 'package:onetouch/data/auth/auth_request_exception.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/auth/email_code_challenge.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'package:onetouch/data/auth/registration_field.dart';

void main() {
  testWidgets('signup terms and button stay fixed while fields scroll',
      (tester) async {
    tester.view.physicalSize = const Size(393, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const MaterialApp(home: EmailSignUpScreen()));

    final firstName = find.byKey(const ValueKey('signup-first-name-field'));
    final checkbox = find.byType(Checkbox);
    final button = find.byKey(const ValueKey('email-sign-up-button'));
    final firstNameTop = tester.getTopLeft(firstName).dy;
    final checkboxTop = tester.getTopLeft(checkbox).dy;
    final buttonTop = tester.getTopLeft(button).dy;

    await tester.drag(find.byKey(const ValueKey('signup-fields-scroll')),
        const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(firstName).dy, lessThan(firstNameTop));
    expect(tester.getTopLeft(checkbox).dy, checkboxTop);
    expect(tester.getTopLeft(button).dy, buttonTop);

    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(button).dy, lessThanOrEqualTo(370));
    expect(tester.takeException(), isNull);
  });

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
    testWidgets('signup preserves name meanings with $locale input order',
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
      final first = find.byKey(const ValueKey('signup-first-name-field'));
      final last = find.byKey(const ValueKey('signup-last-name-field'));
      expect(tester.getTopLeft(first).dy, tester.getTopLeft(last).dy);
      expect(tester.getTopLeft(first).dx < tester.getTopLeft(last).dx,
          locale.languageCode == 'en');
      await tester.enterText(first, 'Given');
      await tester.enterText(last, 'Family');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(2), 'member');
      await tester.enterText(
          find.byKey(const ValueKey('signup-display-name-field')), 'Supporter');
      await tester.enterText(fields.at(4), 'member@example.com');
      await tester.enterText(fields.at(5), 'Password123');
      await tester.enterText(fields.at(6), 'Password123');
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(
          find.text(translateMessage(locale, 'Available.')), findsNWidgets(3));
      final submit = find.byKey(const ValueKey('email-sign-up-button'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Verification destination'), findsOneWidget);
      expect(draft!.firstName, 'Given');
      expect(draft!.lastName, 'Family');
      expect(draft!.displayName, 'Supporter');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('signup checks both names before requesting an email code',
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
    await tester.enterText(fields.at(0), 'John');
    await tester.enterText(fields.at(1), 'Doe');
    await tester.enterText(fields.at(2), '.john');
    await tester.enterText(fields.at(3), 'June_Kim');
    await tester.enterText(fields.at(4), 'john@example.com');
    await tester.enterText(fields.at(5), 'Password123');
    await tester.enterText(fields.at(6), 'Password123');
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

    await tester.enterText(fields.at(2), 'john_doe');
    await tester.enterText(fields.at(3), '메이플123');
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
      'John',
      'Doe',
      'taken',
      'Supporter',
      'member@example.com',
      'Password123'
    ].indexed) {
      await tester.enterText(fields.at(index), value);
    }
    await tester.enterText(fields.at(6), 'Password123');
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

    expect(
        find.byKey(const ValueKey('signup-first-name-field')), findsOneWidget);
    expect(find.text('Email, username, or nickname is already registered'),
        findsOneWidget);
    expect(
        tester.widget<TextFormField>(fields.at(2)).controller!.text, 'taken');
    await tester.enterText(fields.at(2), 'different');
    expect(tester.widget<TextFormField>(fields.at(2)).controller!.text,
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
    (0, 'John'),
    (1, 'Doe'),
    (2, 'member'),
    (3, 'Supporter'),
    (4, 'member@example.com'),
    (5, 'Password123'),
    (6, 'Password123'),
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
              firstName: 'First',
              lastName: 'Last',
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
    required String firstName,
    required String lastName,
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
