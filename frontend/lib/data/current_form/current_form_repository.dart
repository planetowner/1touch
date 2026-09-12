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
    int limit = 200,
  });

  CurrentFormComparison? cachedComparisonFor(
    int teamId, {
    int? seasonId,
    required int compareTeamId,
    required int compareSeasonId,
  });

  /// Mirrors the backend's global, searchable Big Five team-season options.
  ///
  /// TODO(current-form): If the product is restricted to same-team historical
  /// comparisons, prefer an exact backend team-ID filter over fuzzy search.
  Future<List<CurrentFormOption>> loadOptions(
    int teamId, {
    String search = '',
    int limit = 200,
  });

  Future<CurrentFormComparison?> loadComparison(
    int teamId, {
    int? seasonId,
    required int compareTeamId,
    required int compareSeasonId,
  });
}
