import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/probability_display.dart';
import 'package:onetouch/models/team_probability.dart';

void main() {
  test('rounds percentages before applying the display boundaries', () {
    for (final (probability, prefix, number) in [
      (0.85255, '', '85.3'),
      (0.16, '', '16.0'),
      (0.00073, '', '0.1'),
      (0.0005, '', '0.1'),
      (0.00049999, '<', '0.1'),
      (0.00036, '<', '0.1'),
      (0.0, '<', '0.1'),
      (0.99949999, '', '99.9'),
      (0.9995, '>', '99.9'),
      (1.0, '>', '99.9'),
    ]) {
      expect(probabilityDisplay(_card(probability)),
          (prefix: prefix, number: number),
          reason: '$probability');
    }
  });

  test('only mathematically resolved outcomes display zero or one hundred', () {
    expect(probabilityDisplay(_card(0, ProbabilityResolution.impossible)),
        (prefix: '', number: '0'));
    expect(probabilityDisplay(_card(1, ProbabilityResolution.certain)),
        (prefix: '', number: '100'));
  });
}

TeamProbabilityCard _card(double probability,
    [ProbabilityResolution resolution = ProbabilityResolution.unresolved]) {
  return TeamProbabilityCard(
    event: 'top_4',
    competitionId: 8,
    category: 'LEAGUE_FINISH',
    probability: probability,
    changePercentagePoints: null,
    entropy: null,
    resolution: resolution,
  );
}
