import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_config.dart';

void main() {
  group('ApiConfig', () {
    test('normalizes the base URI and creates the bearer header', () {
      final config = ApiConfig.fromValues(
        baseUri: 'https://api.1touch.football/v1',
        sessionToken: 'session-token',
      );

      expect(config.baseUri, Uri.parse('https://api.1touch.football/v1/'));
      expect(config.requestHeaders, {
        'Authorization': 'Bearer session-token',
      });
      expect(config.sessionToken, 'session-token');
    });

    test('preserves an existing trailing slash and trims input', () {
      final config = ApiConfig.fromValues(
        baseUri: ' https://api.1touch.football/v1/ ',
        sessionToken: ' session-token ',
      );

      expect(config.baseUri, Uri.parse('https://api.1touch.football/v1/'));
      expect(config.requestHeaders['Authorization'], 'Bearer session-token');
    });

    test('creates unauthenticated API settings without a session token', () {
      final config = ApiConfig.unauthenticated(
        baseUri: ' https://api.1touch.football/v1 ',
      );

      expect(config.baseUri, Uri.parse('https://api.1touch.football/v1/'));
      expect(config.requestHeaders, isEmpty);
      expect(config.sessionToken, isNull);
    });

    test('rejects missing configuration values', () {
      expect(
        () => ApiConfig.fromValues(baseUri: '', sessionToken: 'token'),
        throwsStateError,
      );
      expect(
        () => ApiConfig.fromValues(
          baseUri: 'https://api.1touch.football/v1/',
          sessionToken: '',
        ),
        throwsStateError,
      );
    });

    test('rejects malformed base URIs', () {
      for (final baseUri in [
        'api.1touch.football/v1',
        'ftp://api.1touch.football/v1',
        'https://api.1touch.football/v1?debug=true',
      ]) {
        expect(
          () => ApiConfig.fromValues(
            baseUri: baseUri,
            sessionToken: 'token',
          ),
          throwsFormatException,
        );
      }

      expect(
        () => ApiConfig.unauthenticated(baseUri: 'not-a-uri'),
        throwsFormatException,
      );
    });

    test('does not expose mutable request headers', () {
      final config = ApiConfig.fromValues(
        baseUri: 'https://api.1touch.football/v1/',
        sessionToken: 'session-token',
      );

      expect(
        () => config.requestHeaders['Authorization'] = 'Bearer replacement',
        throwsUnsupportedError,
      );
    });

    test('session-aware client replaces stale authorization per request',
        () async {
      final receivedAuthorization = <String?>[];
      final client = ApiConfig.sessionAwareClient(
        MockClient((request) async {
          receivedAuthorization.add(request.headers['Authorization']);
          return http.Response('{}', 200);
        }),
      );
      addTearDown(() {
        ApiConfig.setRuntimeAccessToken(null);
        client.close();
      });

      ApiConfig.setRuntimeAccessToken('first-session');
      await client.get(
        Uri.parse('https://api.example.test/first'),
        headers: const {'Authorization': 'Bearer stale-development-token'},
      );
      ApiConfig.setRuntimeAccessToken('second-session');
      await client.get(Uri.parse('https://api.example.test/second'));

      expect(receivedAuthorization, [
        'Bearer first-session',
        'Bearer second-session',
      ]);
    });
  });
}
