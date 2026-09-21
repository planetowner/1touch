import 'package:onetouch/models/player_indicators.dart';

class ApiPlayerIndicatorsResponse {
  ApiPlayerIndicatorsResponse.fromJson(Map<String, dynamic> json)
      : indicators = PlayerIndicators(
          playerId: json['player_id'] as int,
          seasonName: json['season_name'] as String,
          asOf: DateTime.parse(json['as_of'] as String),
          squadRole: _squadRole(json['squad_role'] as String?),
          form: _score(json['form'] as Map<String, dynamic>),
          costEffectiveness: _score(
            json['cost_effectiveness'] as Map<String, dynamic>,
            requirePercentile: false,
          ),
        ) {
    if (json['comparison_scope'] != 'current_season_big_five_all_positions') {
      throw const FormatException('Unexpected player indicator comparison.');
    }
  }

  final PlayerIndicators indicators;

  static String? _squadRole(String? role) {
    return switch (role) {
      null => null,
      'crucial' => 'Crucial',
      'important' => 'Important',
      'rotation' => 'Rotation',
      'sporadic' => 'Sporadic',
      'prospect' => 'Prospect',
      _ => throw const FormatException('Unknown squad role.'),
    };
  }

  static PlayerIndicatorScore _score(
    Map<String, dynamic> json, {
    bool requirePercentile = true,
  }) {
    final band = json['band'] as int?;
    final grade = json['grade'] as String?;
    final percentile = (json['percentile'] as num?)?.toDouble();
    if ((band == null) != (grade == null) ||
        (requirePercentile && (band == null) != (percentile == null)) ||
        (band == null && percentile != null) ||
        (band != null && (band < 0 || band > 4)) ||
        (percentile != null &&
            (!percentile.isFinite || percentile < 0 || percentile > 100))) {
      throw const FormatException('Invalid player indicator score.');
    }
    return PlayerIndicatorScore(
      grade: grade,
      band: band,
      percentile: percentile,
      referenceCount: json['reference_count'] as int,
      ratedMatches: json['rated_matches'] as int,
      unavailableReason: json['unavailable_reason'] as String?,
    );
  }
}
