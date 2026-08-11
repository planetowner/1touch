import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/competitions/mock/competition_catalog.dart';

void main() {
  const expectedLabels = <int, String>{
    8: 'Premier League',
    82: 'Bundesliga',
    301: 'Ligue 1',
    384: 'Serie A',
    564: 'LaLiga',
    2: 'UEFA Champions League',
    5: 'UEFA Europa League',
    2286: 'UEFA Conference League',
    1371: 'UEFA Europa League Play-offs',
    24: 'FA Cup',
    27: 'Carabao Cup (EFL Cup)',
    390: 'Coppa Italia',
    570: 'Copa del Rey',
  };

  test('matches the supported competition label contract', () {
    expect(competitionLabels, expectedLabels);

    for (final entry in expectedLabels.entries) {
      final competition = mockCompetitionById(entry.key);
      expect(competition.name, entry.value);
      expect(competition.imagePath, isNotEmpty);
    }
  });

  test('keeps domestic league detection limited to the Big Five', () {
    expect(leagueNames, {
      8: 'Premier League',
      82: 'Bundesliga',
      301: 'Ligue 1',
      384: 'Serie A',
      564: 'LaLiga',
    });
  });

  test('uses unique IDs and retains fixture-backed legacy competitions', () {
    final ids = mockCompetitions
        .map((competition) => competition.competitionId)
        .toSet();

    expect(ids, hasLength(mockCompetitions.length));
    expect(mockCompetitionById(392).name, 'DFB Pokal');
    expect(mockCompetitionById(569).name, 'Coupe de France');
    expect(competitionLabels, isNot(contains(392)));
    expect(competitionLabels, isNot(contains(569)));
  });

  test('returns an explicit unknown competition fallback', () {
    final competition = mockCompetitionById(-1);

    expect(competition.competitionId, -1);
    expect(competition.name, 'Unknown');
    expect(competition.imagePath, isNull);
  });
}
