import 'package:flutter/foundation.dart';
import 'package:onetouch/models/team.dart';

abstract interface class TeamRepository {
  List<Team> get allTeams;

  ValueListenable<List<Team>> get teams;

  Team? findById(int teamId);

  List<Team> search(String query);

  bool contains(int teamId);

  Future<void> initialize();
}

extension TeamRepositoryFallback on TeamRepository {
  Team requireById(int teamId) {
    final team = findById(teamId);
    if (team == null) {
      throw StateError(
        'Team $teamId must exist after repository initialization and '
        'preference validation.',
      );
    }
    return team;
  }

  Team findByIdOrUnknown(int teamId) {
    return findById(teamId) ?? Team(teamId: teamId, name: 'Unknown Team');
  }
}
