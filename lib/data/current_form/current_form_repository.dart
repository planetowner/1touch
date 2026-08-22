import 'package:flutter/foundation.dart';
import 'package:onetouch/models/current_form.dart';

abstract interface class CurrentFormRepository {
  ValueListenable<Map<CurrentFormOptionsQuery, List<CurrentFormOption>>>
      get cachedOptions;

  ValueListenable<Map<CurrentFormComparisonQuery, CurrentFormComparison>>
      get cachedComparisons;

  List<CurrentFormOption>? cachedOptionsFor(
    int teamId, {
    String search = '',
    int limit = 100,
  });

  CurrentFormComparison? cachedComparisonFor(
    int teamId, {
    int? seasonId,
    required int compareTeamId,
    required int compareSeasonId,
  });

  Future<List<CurrentFormOption>> loadOptions(
    int teamId, {
    String search = '',
    int limit = 100,
  });

  Future<CurrentFormComparison?> loadComparison(
    int teamId, {
    int? seasonId,
    required int compareTeamId,
    required int compareSeasonId,
  });
}
