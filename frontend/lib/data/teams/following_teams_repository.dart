import 'package:flutter/foundation.dart';
import 'package:onetouch/models/team.dart';

class FavoriteTeamChangeLimitException implements Exception {
  const FavoriteTeamChangeLimitException({
    required this.message,
    required this.availableAt,
  });

  final String message;
  final DateTime availableAt;

  @override
  String toString() => message;
}

abstract interface class FollowingTeamsRepository {
  /// Last authoritative, backend-ordered list loaded by this repository.
  ValueListenable<List<Team>> get cachedTeams;

  Future<List<Team>> load();

  /// Replaces the complete ordered list and returns the authoritative GET
  /// response after the update succeeds.
  Future<List<Team>> replaceFollowing({
    required Iterable<int> teamIds,
    required int favoriteTeamId,
  });
}
