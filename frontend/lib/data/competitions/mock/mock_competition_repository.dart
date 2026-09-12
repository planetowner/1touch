import 'package:flutter/foundation.dart';
import 'package:onetouch/data/competitions/competition_repository.dart';
import 'package:onetouch/data/competitions/mock/competition_catalog.dart';
import 'package:onetouch/models/competition.dart';

class MockCompetitionRepository implements CompetitionRepository {
  MockCompetitionRepository({
    List<Competition>? competitions,
    Set<int>? domesticCompetitionIds,
  })  : _allCompetitions = List.unmodifiable(
          competitions ?? mockCompetitions,
        ),
        _domesticCompetitionIds = Set.unmodifiable(
          domesticCompetitionIds ?? leagueNames.keys,
        ) {
    _competitionsById = Map.unmodifiable({
      for (final competition in _allCompetitions)
        competition.competitionId: competition,
    });
    _domesticCompetitions = List.unmodifiable(
      _allCompetitions.where(
        (competition) =>
            _domesticCompetitionIds.contains(competition.competitionId),
      ),
    );
    _competitions = ValueNotifier(_allCompetitions);
  }

  final List<Competition> _allCompetitions;
  final Set<int> _domesticCompetitionIds;
  late final Map<int, Competition> _competitionsById;
  late final List<Competition> _domesticCompetitions;
  late final ValueNotifier<List<Competition>> _competitions;

  @override
  List<Competition> get allCompetitions => _allCompetitions;

  @override
  ValueListenable<List<Competition>> get competitions => _competitions;

  @override
  Competition? findById(int competitionId) => _competitionsById[competitionId];

  @override
  List<Competition> get domesticCompetitions => _domesticCompetitions;

  @override
  bool contains(int competitionId) =>
      _competitionsById.containsKey(competitionId);

  @override
  Future<void> initialize() async {}
}
