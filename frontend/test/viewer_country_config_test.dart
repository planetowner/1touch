import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/viewer_country_config.dart';

void main() {
  test('normalizes an ISO viewer country', () {
    expect(ViewerCountryConfig.normalize(' us '), 'US');
    expect(ViewerCountryConfig.normalize('KR'), 'KR');
  });

  test('rejects missing or malformed viewer countries', () {
    for (final value in ['', 'U', 'USA', '1S', 'U-']) {
      expect(
        () => ViewerCountryConfig.normalize(value),
        throwsFormatException,
      );
    }
  });
}
