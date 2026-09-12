import 'package:flutter_test/flutter_test.dart';
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
    });

    test('preserves an existing trailing slash and trims input', () {
      final config = ApiConfig.fromValues(
        baseUri: ' https://api.1touch.football/v1/ ',
        sessionToken: ' session-token ',
      );

      expect(config.baseUri, Uri.parse('https://api.1touch.football/v1/'));
      expect(config.requestHeaders['Authorization'], 'Bearer session-token');
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
  });
}
