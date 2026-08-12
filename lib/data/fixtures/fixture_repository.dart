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
