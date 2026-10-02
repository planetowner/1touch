import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/comm_pages/Profile_settings/InfoEdit.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/data/auth/social_identity_service.dart';
import 'package:onetouch/data/profile/social_account_service.dart';
import 'package:onetouch/models/current_user_profile.dart';

void main() {
  testWidgets('email user connects Google without replacing the session',
      (tester) async {
    var requests = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        requests++;
        expect(request.method, 'PUT');
        expect(request.url.path, '/v1/users/me/social-accounts/google');
        expect(request.headers['Authorization'], 'Bearer existing-session');
        expect(jsonDecode(request.body), {'id_token': 'google-id-token'});
        return http.Response('{"social_accounts":["google"]}', 200);
      }),
      baseUri: Uri.parse('https://api.example.com/v1/'),
      requestHeaders: () => {'Authorization': 'Bearer existing-session'},
    );
    final service = SocialAccountService(
      api: api,
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
        ),
        socialAccountService: service,
      ),
    ));

    final google = find.byKey(const ValueKey('social-account-google'));
    await tester.ensureVisible(google);
    await tester.tap(google);
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.descendant(of: google, matching: find.text('Connected')),
        findsOneWidget);
    await tester.tap(google);
    await tester.pumpAndSettle();
    expect(requests, 1);
  });

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
}

class _GoogleIdentity implements GoogleIdentityService {
  @override
  Future<String> authenticate() async => 'google-id-token';
}

class _SocialIdentity implements SocialIdentityService {
  @override
  Future<Map<String, String>> authenticate(LoginProvider provider) async =>
      {'code': 'apple-code', 'client_id': 'app', 'nonce': 'nonce'};
}
