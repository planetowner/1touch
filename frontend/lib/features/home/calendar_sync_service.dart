import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/auth/google/google_sign_in_identity_service.dart';
import 'package:url_launcher/url_launcher.dart';

const _calendarScopes = [
  'openid',
  'https://www.googleapis.com/auth/calendar.app.created'
];

Future<String> authorizeGoogleCalendar() async {
  await GoogleSignInIdentityService().initialize();
  final account = await GoogleSignIn.instance.authenticate();
  final authorization =
      await account.authorizationClient.authorizeServer(_calendarScopes);
  final code = authorization?.serverAuthCode;
  if (code == null || code.isEmpty) {
    throw const CalendarSyncException('calendar_reconnect_required');
  }
  return code;
}

Future<bool> _openSubscription(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class CalendarSyncException implements Exception {
  const CalendarSyncException(this.code);
  final String code;
}

class CalendarConnection {
  const CalendarConnection(
      {required this.connected, required this.subscribed, this.lastError});
  final bool connected;
  final bool subscribed;
  final String? lastError;

  bool get needsAuthorization =>
      !connected ||
      const {
        'calendar_reconnect_required',
        'calendar_permission_required',
        'calendar_missing',
      }.contains(lastError);
}

class CalendarSyncService {
  const CalendarSyncService({
    required this.api,
    this.authorizeGoogle = authorizeGoogleCalendar,
    this.openSubscription = _openSubscription,
  });

  final ApiClient api;
  final Future<String> Function() authorizeGoogle;
  final Future<bool> Function(Uri) openSubscription;

  Future<CalendarConnection> connection(int teamId) async {
    final data = _decode(
        await api.get(api.baseUri.resolve('users/me/calendar/teams/$teamId')));
    return CalendarConnection(
        connected: data['connected'] as bool,
        subscribed: data['subscribed'] as bool,
        lastError: data['last_error'] as String?);
  }

  Future<void> syncGoogle(int teamId) async {
    final state = await connection(teamId);
    if (state.needsAuthorization) {
      final code = await authorizeGoogle();
      _decode(await api.post(api.baseUri.resolve('users/me/calendar/google'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'server_auth_code': code})));
    }
    _decode(
        await api.put(api.baseUri.resolve('users/me/calendar/teams/$teamId')));
  }

  Future<void> stopGoogle(int teamId) async {
    _decode(await api
        .delete(api.baseUri.resolve('users/me/calendar/teams/$teamId')));
  }

  Future<void> disconnectGoogle() async {
    _decode(await api.delete(api.baseUri.resolve('users/me/calendar/google')));
  }

  Future<void> subscribeApple(int teamId) async {
    final uri = api.baseUri.resolve('calendars/teams/$teamId.ics');
    // 서버 준비가 안 된 주소를 캘린더 앱에 넘겨 연결됐다고 안내하지 않아요.
    final response = await api.get(uri);
    if (response.statusCode != 200 ||
        !response.body.startsWith('BEGIN:VCALENDAR')) {
      throw const CalendarSyncException('calendar_feed_unavailable');
    }
    if (!await openSubscription(uri.replace(scheme: 'webcal'))) {
      throw const CalendarSyncException('calendar_open_failed');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode != 200) {
      String? code;
      try {
        final detail = jsonDecode(response.body)['detail'];
        if (detail is Map) code = detail['code'] as String?;
      } on FormatException {
        // 프록시 오류처럼 JSON이 아닌 응답도 같은 실패 안내로 처리해요.
      }
      throw CalendarSyncException(code ?? 'calendar_request_failed');
    }
    return api.decodeJson<Map<String, dynamic>>(response);
  }
}
