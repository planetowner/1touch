import 'package:flutter/foundation.dart';
import 'package:onetouch/models/team_best_eleven.dart';

abstract interface class BestElevenRepository {
  ValueListenable<Map<BestElevenQuery, TeamBestEleven>> get cachedLineups;

  TeamBestEleven? cachedForTeam(
    int teamId, {
    int? seasonId,
    String? formation,
  });

  Future<TeamBestEleven?> loadForTeam(
    int teamId, {
    int? seasonId,
    String? formation,
  });
}
