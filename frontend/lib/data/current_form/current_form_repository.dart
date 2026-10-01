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
    String? seasonName,
    int limit = 200,
  });

  CurrentFormComparison? cachedComparisonFor(
    int teamId, {
    int? seasonId,
    required int compareTeamId,
    required int compareSeasonId,
  });

  /// 시즌 이름을 지정하면 리그별 시즌 ID와 관계없이 해당 시즌만 조회해요.
  Future<List<CurrentFormOption>> loadOptions(
    int teamId, {
    String search = '',
    String? seasonName,
    int limit = 200,
  });

  /// 선택한 시즌의 모든 페이지를 조회해 비교 후보가 빠지지 않게 해요.
  Future<List<CurrentFormOption>> loadAllOptions(
    int teamId, {
    String? seasonName,
  });

  Future<CurrentFormComparison?> loadComparison(
    int teamId, {
    int? seasonId,
    required int compareTeamId,
    required int compareSeasonId,
  });
}
