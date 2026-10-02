import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/comm_pages/Profile_settings/InfoEdit.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/auth/auth_session.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/data/auth/social_identity_service.dart';
import 'package:onetouch/data/profile/social_account_service.dart';
import 'package:onetouch/models/current_user_profile.dart';

void main() {
  for (final provider in [LoginProvider.google, LoginProvider.apple]) {
    testWidgets(
        'email user connects ${provider.name} without replacing the session',
        (tester) async {
      var requests = 0;
      final session = AuthSession()..establish('existing-session');
      final api = ApiClient(
        client: MockClient((request) async {
          requests++;
          expect(request.method, 'PUT');
          expect(request.url.path,
              '/v1/users/me/social-accounts/${provider.name}');
          expect(request.headers['Authorization'], 'Bearer existing-session');
          expect(
              jsonDecode(request.body),
              provider == LoginProvider.google
                  ? {'id_token': 'google-id-token'}
                  : _appleProof);
          return http.Response(
              jsonEncode({
                'social_accounts': [provider.name]
              }),
              200);
        }),
        baseUri: Uri.parse('https://api.example.com/v1/'),
        requestHeaders: () => session.requestHeaders,
      );
      final service = SocialAccountService(
        api: api,
        googleIdentityService: _GoogleIdentity(),
        socialIdentityService: _SocialIdentity(),
      );
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: EditProfileScreen(
          profile: CurrentUserProfile(
            userId: 1,
            username: 'email-user',
            displayName: 'Email User',
            email: 'email@example.com',
            avatarUri: null,
            favoriteTeamId: 1,
            createdAt: DateTime.utc(2026),
          ),
          socialAccountService: service,
        ),
      ));

      final row = find.byKey(ValueKey('social-account-${provider.name}'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(session.accessToken, 'existing-session');
      expect(find.descendant(of: row, matching: find.text('Connected')),
          findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(requests, 1);
    });
  }

  testWidgets(
      'already linked Google is shown as connected and cannot be tapped',
      (tester) async {
    var requests = 0;
    final service = SocialAccountService(
      api: ApiClient(
        client: MockClient((request) async {
          requests++;
          return http.Response('{"social_accounts":["google"]}', 200);
        }),
        baseUri: Uri.parse('https://api.example.com/v1/'),
        requestHeaders: () => {'Authorization': 'Bearer existing-session'},
      ),
      googleIdentityService: _GoogleIdentity(),
      socialIdentityService: _SocialIdentity(),
    );
    await tester.pumpWidget(MaterialApp(
      home: EditProfileScreen(
        profile: CurrentUserProfile(
          userId: 1,
          username: 'email-user',
          displayName: 'Email User',
          email: 'email@example.com',
          avatarUri: null,
          favoriteTeamId: 1,
          createdAt: DateTime.utc(2026),
          socialAccounts: const {'google'},
        ),
        socialAccountService: service,
      ),
    ));

    final google = find.byKey(const ValueKey('social-account-google'));
    await tester.ensureVisible(google);
    expect(find.descendant(of: google, matching: find.text('Connected')),
        findsOneWidget);
    await tester.tap(google);
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(find.byKey(const ValueKey('social-account-apple')), findsNothing);
  });

  for (final status in [409, 503]) {
    testWidgets(
        'HTTP $status keeps the account disconnected and shows an error',
        (tester) async {
      await _pumpConnection(tester, status: status);
      final google = find.byKey(const ValueKey('social-account-google'));
      await tester.ensureVisible(google);
      await tester.tap(google);
      await tester.pumpAndSettle();
      expect(find.descendant(of: google, matching: find.text('Not Connected')),
          findsOneWidget);
      expect(
          find.text(
              'Unable to connect Google. It may already be linked to another account.'),
          findsOneWidget);
    });
  }

  for (final provider in [LoginProvider.google, LoginProvider.apple]) {
    testWidgets(
        'cancelling ${provider.name} does not send a connection request',
        (tester) async {
      var requests = 0;
      await _pumpConnection(tester,
          cancelled: true, onRequest: () => requests++);
      final row = find.byKey(ValueKey('social-account-${provider.name}'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(requests, 0);
      expect(find.descendant(of: row, matching: find.text('Not Connected')),
          findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  }
}

Future<void> _pumpConnection(WidgetTester tester,
    {int status = 200, bool cancelled = false, VoidCallback? onRequest}) async {
  final service = SocialAccountService(
    api: ApiClient(
      client: MockClient((request) async {
        onRequest?.call();
        return http.Response('{"social_accounts":[]}', status);
      }),
      baseUri: Uri.parse('https://api.example.com/v1/'),
      requestHeaders: () => {'Authorization': 'Bearer existing-session'},
    ),
    googleIdentityService: _GoogleIdentity(cancelled: cancelled),
    socialIdentityService: _SocialIdentity(cancelled: cancelled),
  );
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(platform: TargetPlatform.iOS),
    home: EditProfileScreen(socialAccountService: service),
  ));
}

const _appleProof = {
  'code': 'apple-code',
  'client_id': 'com.onetouch.football',
  'nonce': 'apple-nonce-for-linking',
};

class _GoogleIdentity implements GoogleIdentityService {
  _GoogleIdentity({this.cancelled = false});
  final bool cancelled;

  @override
  Future<String> authenticate() async {
    if (cancelled) {
      throw const GoogleIdentityException(GoogleIdentityFailureType.cancelled);
    }
    return 'google-id-token';
  }
}

class _SocialIdentity implements SocialIdentityService {
  _SocialIdentity({this.cancelled = false});
  final bool cancelled;

  @override
  Future<Map<String, String>> authenticate(LoginProvider provider) async {
    if (cancelled) throw const SocialLoginCancelled();
    return _appleProof;
  }
}
