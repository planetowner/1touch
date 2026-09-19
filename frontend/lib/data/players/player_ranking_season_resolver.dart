import 'package:onetouch/data/competitions/competition_repository.dart';
import 'package:onetouch/data/seasons/season_repository.dart';
import 'package:onetouch/models/season.dart';

/// Resolves the existing Players-screen labels to a verified season ID.
///
/// This remains local until the backend exposes a shared season-options
/// endpoint. Keeping the lookup outside the widget prevents season IDs from
/// becoming UI constants.
class PlayerRankingSeasonResolver {
  const PlayerRankingSeasonResolver({
    required CompetitionRepository competitionRepository,
    required SeasonRepository seasonRepository,
  })  : _competitionRepository = competitionRepository,
        _seasonRepository = seasonRepository;

  final CompetitionRepository _competitionRepository;
  final SeasonRepository _seasonRepository;

  Season resolve({
    required String leagueName,
    required String seasonName,
  }) {
    final normalizedLeague = _normalize(leagueName);
    final normalizedSeason = _normalize(seasonName);
    if (normalizedLeague.isEmpty || normalizedSeason.isEmpty) {
      throw ArgumentError('League and season labels must not be empty.');
    }

    final competitions = _competitionRepository.domesticCompetitions
        .where(
          (competition) => _normalize(competition.name) == normalizedLeague,
        )
        .toList(growable: false);
    if (competitions.length != 1) {
      throw StateError(
        'Expected one domestic competition for "$leagueName", found '
        '${competitions.length}.',
      );
    }

    final seasons = _seasonRepository
        .forCompetition(competitions.single.competitionId)
        .where((season) => _normalize(season.name) == normalizedSeason)
        .toList(growable: false);
    if (seasons.length != 1) {
      throw StateError(
        'Expected one season for "$leagueName" / "$seasonName", found '
        '${seasons.length}.',
      );
    }
    return seasons.single;
  }

  static String _normalize(String value) => value.trim().toLowerCase();
}
