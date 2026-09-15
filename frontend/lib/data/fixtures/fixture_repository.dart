import 'package:flutter/foundation.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_detail.dart';

abstract interface class FixtureRepository {
  List<Fixture> get allFixtures;
  ValueListenable<List<Fixture>> get fixtures;

  Fixture? findById(int fixtureId);

  /// Loads the contextual data returned by `GET /v1/fixtures/{fixture_id}`.
  Future<FixtureDetail> loadDetail(int fixtureId);

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
  // Preserve the backend's status-specific ordering. The Team Matches tab
  // intentionally does not re-sort pages, so any ordering change belongs to
  // the endpoint contract before paginated scrolling is introduced.
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

  /// Loads completed meetings for the teams in the selected fixture.
  ///
  /// This temporarily coexists with [headToHead], which selects only from the
  /// fixtures already available in memory.
  Future<List<Fixture>> loadHeadToHead(
    int fixtureId, {
    int limit = 10,
  });

  Future<void> initialize();
}
