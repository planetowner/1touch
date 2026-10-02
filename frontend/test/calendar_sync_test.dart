import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/features/home_screen_features.dart';
import 'package:onetouch/features/home/calendar_sync_service.dart';
import 'package:onetouch/l10n/app_localizations.dart';

CalendarSyncService service(
  Future<http.Response> Function(http.Request) request, {
  Future<String> Function()? authorize,
  Future<bool> Function(Uri)? open,
}) =>
    CalendarSyncService(
      api: ApiClient(
          client: MockClient(request),
          baseUri: Uri.parse('https://api.example/v1/'),
          requestHeaders: () => {'Authorization': 'Bearer app-session'}),
      authorizeGoogle: authorize ?? () async => 'one-time-code',
      openSubscription: open ?? (_) async => true,
    );

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'Google connects once and subscribes the viewed team using the app session',
      () async {
    final requests = <http.Request>[];
    var consentCount = 0;
    var connected = false;
    final sync = service((request) async {
      requests.add(request);
      expect(request.headers['Authorization'], 'Bearer app-session');
      if (request.method == 'GET') {
        return jsonResponse({
          'connected': connected,
          'subscribed': connected,
          'last_error': null
        });
      }
      if (request.method == 'POST') {
        expect(jsonDecode(request.body), {'server_auth_code': 'consent-code'});
        connected = true;
        return jsonResponse({'ok': true});
      }
      return jsonResponse({'synced_matches': 2});
    }, authorize: () async {
      consentCount++;
      return 'consent-code';
    });
    await sync.syncGoogle(9);
    await sync.syncGoogle(9);
    expect(consentCount, 1);
    expect(requests.where((r) => r.method == 'PUT').map((r) => r.url.path),
        ['/v1/users/me/calendar/teams/9', '/v1/users/me/calendar/teams/9']);
  });

  test('revoked permission requests fresh authorization', () async {
    var consentCount = 0;
    final sync = service(
        (request) async => request.method == 'GET'
            ? jsonResponse({
                'connected': true,
                'subscribed': true,
                'last_error': 'calendar_reconnect_required'
              })
            : jsonResponse({'ok': true}), authorize: () async {
      consentCount++;
      return 'new-code';
    });
    await sync.syncGoogle(8);
    expect(consentCount, 1);
  });

  test('rejects malformed calendar connection responses', () async {
    final sync = service(
      (_) async => jsonResponse({
        'connected': 'yes',
        'subscribed': true,
        'last_error': null,
      }),
    );

    await expectLater(sync.connection(8), throwsFormatException);
  });

  test(
      'server setup failure never opens Google consent or writes a subscription',
      () async {
    var consent = false;
    final requests = <String>[];
    final sync = service((request) async {
      requests.add(request.method);
      return http.Response('Service unavailable', 503);
    }, authorize: () async {
      consent = true;
      return 'code';
    });
    await expectLater(
        sync.syncGoogle(8), throwsA(isA<CalendarSyncException>()));
    expect(consent, isFalse);
    expect(requests, ['GET']);
  });

  test(
      'cancelled Google consent does not send an authorization code or subscribe',
      () async {
    final requests = <String>[];
    final sync = service((request) async {
      requests.add(request.method);
      return jsonResponse({'connected': false, 'subscribed': false});
    },
        authorize: () async => throw const GoogleSignInException(
            code: GoogleSignInExceptionCode.canceled));
    await expectLater(
        sync.syncGoogle(8), throwsA(isA<GoogleSignInException>()));
    expect(requests, ['GET']);
  });

  test(
      'Apple validates the feed and opens a stable subscription URL without credentials',
      () async {
    final opened = <Uri>[];
    final sync = service((request) async {
      expect(request.url.path, '/v1/calendars/teams/8.ics');
      return http.Response('BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n', 200);
    }, open: (uri) async {
      opened.add(uri);
      return true;
    });
    await sync.subscribeApple(8);
    expect(opened.single.toString(),
        'webcal://api.example/v1/calendars/teams/8.ics');
    expect(opened.single.hasQuery, isFalse);
  });

  test(
      'Apple does not launch unavailable feeds or claim a failed launch succeeded',
      () async {
    var opened = false;
    final unavailable =
        service((_) async => http.Response('Not found', 404), open: (_) async {
      opened = true;
      return true;
    });
    await expectLater(
        unavailable.subscribeApple(8), throwsA(isA<CalendarSyncException>()));
    expect(opened, isFalse);
    final failedLaunch = service(
        (_) async => http.Response('BEGIN:VCALENDAR', 200),
        open: (_) async => false);
    await expectLater(
        failedLaunch.subscribeApple(8),
        throwsA(isA<CalendarSyncException>()
            .having((e) => e.code, 'code', 'calendar_open_failed')));
  });

  Future<void> show(WidgetTester tester, CalendarSyncService sync,
      {Locale locale = const Locale('en')}) async {
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    onPressed: () => showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => SyncDialog(
                            teamId: 9,
                            teamName: 'Manchester City',
                            service: sync)),
                    child: const Text('Open'),
                  ))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Android disables repeated taps while syncing and shows the selected team',
      (tester) async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final sync = service((request) async {
      calls++;
      if (request.method == 'GET') return pending.future;
      return jsonResponse({'synced_matches': 1});
    });
    await show(tester, sync);
    expect(find.textContaining('Manchester City'), findsOneWidget);
    await tester.tap(find.text('YES, SYNC IT!'));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);
    expect(calls, 1);
    pending.complete(jsonResponse({'connected': true, 'subscribed': true}));
    await tester.pumpAndSettle();
    expect(find.textContaining('Connected to the 1touch calendar'),
        findsOneWidget);
    expect(calls, 2);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('retrying a failed unsubscribe never subscribes again',
      (tester) async {
    final requests = <String>[];
    var deletes = 0;
    final sync = service((request) async {
      requests.add(request.method);
      if (request.method == 'GET') {
        return jsonResponse({'connected': true, 'subscribed': true});
      }
      if (request.method == 'DELETE' && deletes++ == 0) {
        return jsonResponse({}, 503);
      }
      return jsonResponse({'ok': true});
    });
    await show(tester, sync);
    await tester.tap(find.text('YES, SYNC IT!'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop syncing this team'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(requests, ['GET', 'PUT', 'DELETE', 'DELETE']);
    expect(find.textContaining('Automatic sync for this team has stopped.'),
        findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
      'Apple opens subscription setup without claiming that the user subscribed',
      (tester) async {
    final sync = service((_) async => http.Response('BEGIN:VCALENDAR', 200));
    await show(tester, sync, locale: const Locale('ko'));
    await tester.tap(find.text('네, 동기화할게요'));
    await tester.pumpAndSettle();
    expect(find.textContaining('캘린더 앱에서 구독을 완료'), findsOneWidget);
    expect(find.textContaining('Google의 1touch'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
