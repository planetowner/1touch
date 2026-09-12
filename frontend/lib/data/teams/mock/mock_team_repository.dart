import 'package:flutter/foundation.dart';
import 'package:onetouch/data/teams/mock/team_catalog.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/models/team.dart';

class MockTeamRepository implements TeamRepository {
  MockTeamRepository({List<Team>? teams})
      : _allTeams = List.unmodifiable(teams ?? mockTeams) {
    _teamsById = Map.unmodifiable({
      for (final team in _allTeams) team.teamId: team,
    });
    _teams = ValueNotifier(_allTeams);
  }

  final List<Team> _allTeams;
  late final Map<int, Team> _teamsById;
  late final ValueNotifier<List<Team>> _teams;

  @override
  List<Team> get allTeams => _allTeams;

  @override
  ValueListenable<List<Team>> get teams => _teams;

  @override
  Team? findById(int teamId) => _teamsById[teamId];

  @override
  List<Team> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return _allTeams;

    return List.unmodifiable(
      _allTeams.where((team) {
        final name = team.name.toLowerCase();
        final shortCode = team.shortCode?.toLowerCase() ?? '';
        return name.contains(normalized) || shortCode.contains(normalized);
      }),
    );
  }

  @override
  bool contains(int teamId) => _teamsById.containsKey(teamId);

  @override
  Future<void> initialize() async {}
}
