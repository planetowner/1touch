import 'package:flutter/foundation.dart';
import 'package:onetouch/data/competitions/mock/season_catalog.dart';
import 'package:onetouch/data/seasons/season_repository.dart';
import 'package:onetouch/models/season.dart';

class MockSeasonRepository implements SeasonRepository {
  MockSeasonRepository({List<Season>? seasons})
      : _allSeasons = List.unmodifiable(seasons ?? mockSeasons) {
    _seasonsById = Map<int, Season>.unmodifiable({
      for (final season in _allSeasons) season.seasonId: season,
    });

    final seasonsByCompetition = <int, List<Season>>{};
    for (final season in _allSeasons) {
      seasonsByCompetition
          .putIfAbsent(season.competitionId, () => [])
          .add(season);
    }
    _seasonsByCompetition = Map<int, List<Season>>.unmodifiable({
      for (final entry in seasonsByCompetition.entries)
        entry.key: List<Season>.unmodifiable(entry.value),
    });
    _seasons = ValueNotifier(_allSeasons);
  }

  final List<Season> _allSeasons;
  late final Map<int, Season> _seasonsById;
  late final Map<int, List<Season>> _seasonsByCompetition;
  late final ValueNotifier<List<Season>> _seasons;

  @override
  List<Season> get allSeasons => _allSeasons;

  @override
  ValueListenable<List<Season>> get seasons => _seasons;

  @override
  Season? findById(int seasonId) => _seasonsById[seasonId];

  @override
  List<Season> forCompetition(int competitionId) =>
      _seasonsByCompetition[competitionId] ?? const [];

  @override
  Season? currentForCompetition(int competitionId) {
    for (final season in forCompetition(competitionId)) {
      if (season.isCurrent) return season;
    }
    return null;
  }

  @override
  bool contains(int seasonId) => _seasonsById.containsKey(seasonId);

  @override
  Future<void> initialize() async {}
}
