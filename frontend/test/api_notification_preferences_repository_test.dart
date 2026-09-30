import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/notifications/api/api_notification_preferences_repository.dart';
import 'package:onetouch/data/notifications/notification_preferences.dart';

void main() {
  test('loads the backend preference snapshot', () async {
    final repository = _repository((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        'https://api.example.com/v1/users/me/notification-preferences',
      );
      expect(request.headers['Authorization'], 'Bearer session');
      return http.Response(jsonEncode(_snapshot()), 200);
    });

    final snapshot = await repository.load();

    expect(snapshot.global.postReactions, isTrue);
    expect(snapshot.global.postComments, isFalse);
    expect(snapshot.team(83).newBets, isFalse);
    expect(snapshot.team(83).goal, isTrue);
    expect(snapshot.player(10).yellowCard, isFalse);
  });

  test('saves community preferences without team-only values', () async {
    final repository = _repository((request) async {
      expect(request.method, 'PATCH');
      expect(
        request.url.path,
        '/v1/users/me/notification-preferences/community',
      );
      expect(jsonDecode(request.body), {
        'preferences': {
          'post_reactions': false,
          'post_comments': true,
        },
      });
      return http.Response(jsonEncode(_snapshot()), 200);
    });

    await repository.saveGlobal(
      const GlobalNotificationPreferences(
        postReactions: false,
        postComments: true,
      ),
    );
  });

  test('saves one team and preserves separately controlled new bets', () async {
    final repository = _repository((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final preferences = body['preferences'] as Map<String, dynamic>;
      expect(request.url.path.endsWith('/team'), isTrue);
      expect(body['subject_ids'], [83]);
      expect(preferences.containsKey('new_bets'), isFalse);
      expect(preferences['goal'], isFalse);
      return http.Response(jsonEncode(_snapshot()), 200);
    });

    await repository.saveTeam(
      83,
      const TeamNotificationPreferences(goal: false),
    );
  });

  test('new bets uses a partial team update for all supplied teams', () async {
    final repository = _repository((request) async {
      expect(jsonDecode(request.body), {
        'preferences': {'new_bets': false},
        'subject_ids': [83, 9],
      });
      return http.Response(jsonEncode(_snapshot()), 200);
    });

    await repository.applyNewBetsToAll([83, 9], false);
  });

  test('rejects malformed backend preference values', () async {
    final malformed =
        jsonDecode(jsonEncode(_snapshot())) as Map<String, dynamic>;
    (malformed['community'] as Map<String, dynamic>)['post_comments'] = null;
    final repository = _repository(
      (_) async => http.Response(jsonEncode(malformed), 200),
    );

    expect(repository.load(), throwsFormatException);
  });
}

ApiNotificationPreferencesRepository _repository(
  Future<http.Response> Function(http.Request request) handler,
) =>
    ApiNotificationPreferencesRepository(
      api: ApiClient(
        client: MockClient(handler),
        baseUri: Uri.parse('https://api.example.com/v1/'),
        requestHeaders: () => const {'Authorization': 'Bearer session'},
      ),
    );

Map<String, dynamic> _snapshot() => {
      'community': {
        'post_reactions': true,
        'post_comments': false,
      },
      'teams': {
        '83': {
          'new_bets': false,
          'match_reminder': false,
          'kickoff': true,
          'half_time': true,
          'full_time': true,
          'goal': true,
          'substitution': false,
        },
      },
      'players': {
        '10': {
          'starting_xi': true,
          'substitute': true,
          'goal': true,
          'assist': true,
          'yellow_card': false,
          'red_card': false,
          'injury': false,
        },
      },
    };
