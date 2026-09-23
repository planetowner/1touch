import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/api_config.dart';

void main() {
  group('ApiConfig', () {
    test('normalizes the API directory and optional development token', () {
      final config = ApiConfig.fromValues(
        baseUri: ' https://api.1touch.football/v1 ',
        sessionToken: ' session-token ',
      );
      expect(config.baseUri, Uri.parse('https://api.1touch.football/v1/'));
      expect(config.sessionToken, 'session-token');
    });

    test('allows login without a configured development session', () {
      for (final token in ['', '  ']) {
        final config = ApiConfig.fromValues(
          baseUri: 'https://api.1touch.football/v1/',
          sessionToken: token,
        );
        expect(config.baseUri, Uri.parse('https://api.1touch.football/v1/'));
        expect(config.sessionToken, isNull);
      }
    });

    test('rejects a missing API address', () {
      expect(() => ApiConfig.fromValues(baseUri: ''), throwsStateError);
    });

    test('rejects malformed API addresses', () {
      for (final baseUri in [
        'api.1touch.football/v1',
        'ftp://api.1touch.football/v1',
        'https://api.1touch.football/v1?debug=true',
        'https://api.1touch.football/v1#fragment',
      ]) {
        expect(
          () => ApiConfig.fromValues(baseUri: baseUri),
          throwsFormatException,
        );
      }
    });
  });
}
