import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/models/fixture.dart';

void main() {
  group('Fixture status parsing', () {
    test('preserves recognized screen statuses', () {
      const expectedStatuses = {
        'past': FixtureStatus.past,
        'live': FixtureStatus.live,
        'upcoming': FixtureStatus.upcoming,
      };

      for (final entry in expectedStatuses.entries) {
        final fixture = Fixture.fromJson(_fixtureJson(status: entry.key));

        expect(fixture.status, entry.value);
      }
    });

    test('maps a null transport status to unknown', () {
      final fixture = Fixture.fromJson(_fixtureJson(status: null));

      expect(fixture.status, FixtureStatus.unknown);
    });

    test('maps an unrecognized transport status to unknown', () {
      final fixture = Fixture.fromJson(_fixtureJson(status: 'postponed'));

      expect(fixture.status, FixtureStatus.unknown);
    });

    test('preserves a missing round as null', () {
      final fixture = Fixture.fromJson(
        _fixtureJson(status: 'upcoming')..['round_name'] = null,
      );

      expect(fixture.roundName, isNull);
    });
  });
}

Map<String, dynamic> _fixtureJson({required String? status}) {
  return {
    'fixture_id': 1,
    'season_id': 2,
    'competition_id': 8,
    'home_team_id': 3,
    'away_team_id': 4,
    'competition_type': 'league',
    'round_name': '1',
    'status': status,
    'starting_at': '2026-08-15 15:00:00',
  };
}
