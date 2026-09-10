import 'package:flutter/foundation.dart';
import 'package:onetouch/models/fixture.dart';

abstract interface class FixtureRepository {
  List<Fixture> get allFixtures;
  ValueListenable<List<Fixture>> get fixtures;

  Fixture? findById(int fixtureId);

  List<Fixture> forTeam(
    int teamId, {
    int? seasonId,
    int? competitionId,
    FixtureStatus? status,
  });

  /// Loads the backend-supported team match window.
  ///
  /// This temporarily coexists with [forTeam], which remains the synchronous
  /// cache selector used by existing screens during the incremental API
  /// migration.
  Future<List<Fixture>> loadForTeam(
    int teamId, {
    FixtureStatus? status,
    DateTime? start,
    DateTime? end,
    int limit = 50,
    int offset = 0,
  });

  List<Fixture> forCompetition(
    int competitionId, {
    int? seasonId,
    FixtureStatus? status,
    CompetitionType? competitionType,
  });

  Fixture? nextForTeam(
    int teamId, {
    int? seasonId,
    int? competitionId,
  });

  Fixture? lastForTeam(
    int teamId, {
    int? seasonId,
    int? competitionId,
  });

  List<Fixture> headToHead(
    int firstTeamId,
    int secondTeamId, {
    int? seasonId,
    int? competitionId,
  });

  Future<void> initialize();
}
