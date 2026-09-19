import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/competitions/mock/mock_competition_repository.dart';
import 'package:onetouch/data/players/player_ranking_season_resolver.dart';
import 'package:onetouch/data/seasons/mock/mock_season_repository.dart';
import 'package:onetouch/models/competition.dart';
import 'package:onetouch/models/season.dart';

void main() {
  final competitions = MockCompetitionRepository(
    competitions: const [
      Competition(
        competitionId: 8,
        name: 'Premier League',
        imagePath: null,
      ),
      Competition(
        competitionId: 2,
        name: 'UEFA Champions League',
        imagePath: null,
      ),
    ],
    domesticCompetitionIds: const {8},
  );
  final seasons = MockSeasonRepository(
    seasons: const [
      Season(
        seasonId: 25583,
        competitionId: 8,
        name: '2025/2026',
        isCurrent: false,
        startingAt: '2025-08-15 00:00:00',
        endingAt: '2026-05-24 00:00:00',
      ),
      Season(
        seasonId: 28083,
        competitionId: 8,
        name: '2026/2027',
        isCurrent: true,
        startingAt: '2026-07-01 00:00:00',
        endingAt: '2027-06-30 00:00:00',
      ),
      Season(
        seasonId: 25580,
        competitionId: 2,
        name: '2025/2026',
        isCurrent: false,
        startingAt: '2025-09-16 00:00:00',
        endingAt: '2026-05-30 00:00:00',
      ),
    ],
  );
  final resolver = PlayerRankingSeasonResolver(
    competitionRepository: competitions,
    seasonRepository: seasons,
  );

  test('resolves a league and season label to its season record', () {
    final season = resolver.resolve(
      leagueName: 'Premier League',
      seasonName: '2025/2026',
    );

    expect(season.seasonId, 25583);
    expect(season.competitionId, 8);
  });

  test('normalizes surrounding whitespace and letter case', () {
    final season = resolver.resolve(
      leagueName: '  premier LEAGUE ',
      seasonName: ' 2026/2027 ',
    );

    expect(season.seasonId, 28083);
  });

  test('does not resolve a non-domestic competition', () {
    expect(
      () => resolver.resolve(
        leagueName: 'UEFA Champions League',
        seasonName: '2025/2026',
      ),
      throwsStateError,
    );
  });

  test('rejects an unavailable season and empty labels', () {
    expect(
      () => resolver.resolve(
        leagueName: 'Premier League',
        seasonName: '2023/2024',
      ),
      throwsStateError,
    );
    expect(
      () => resolver.resolve(leagueName: ' ', seasonName: '2025/2026'),
      throwsArgumentError,
    );
  });
}
