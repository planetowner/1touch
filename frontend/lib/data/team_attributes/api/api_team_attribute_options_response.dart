/// Transport response for `GET /v1/teams/{team_id}/attributes/options`.
class ApiTeamAttributeOptionsResponse {
  const ApiTeamAttributeOptionsResponse({
    required this.teamId,
    required this.items,
  });

  final int teamId;
  final List<ApiTeamAttributeSeasonOptionResponse> items;

  factory ApiTeamAttributeOptionsResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final teamId = json['team_id'];
    final items = json['items'];
    if (teamId is! int) {
      throw const FormatException(
        'Expected required integer field "team_id".',
      );
    }
    if (items is! List) {
      throw const FormatException('Expected required list field "items".');
    }

    return ApiTeamAttributeOptionsResponse(
      teamId: teamId,
      items: List.unmodifiable(
        items.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException(
              'Expected each attribute option to be a JSON object.',
            );
          }
          return ApiTeamAttributeSeasonOptionResponse.fromJson(item);
        }),
      ),
    );
  }
}

class ApiTeamAttributeSeasonOptionResponse {
  const ApiTeamAttributeSeasonOptionResponse({
    required this.competitionId,
    required this.seasonId,
    required this.seasonName,
    required this.isCurrent,
  });

  final int competitionId;
  final int seasonId;
  final String seasonName;
  final bool isCurrent;

  factory ApiTeamAttributeSeasonOptionResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final competitionId = json['competition_id'];
    final seasonId = json['season_id'];
    final seasonName = json['season_name'];
    final isCurrent = json['is_current'];
    if (competitionId is! int) {
      throw const FormatException(
        'Expected required integer field "competition_id".',
      );
    }
    if (seasonId is! int) {
      throw const FormatException(
        'Expected required integer field "season_id".',
      );
    }
    if (seasonName is! String) {
      throw const FormatException(
        'Expected required string field "season_name".',
      );
    }
    if (isCurrent is! bool) {
      throw const FormatException(
        'Expected required boolean field "is_current".',
      );
    }

    return ApiTeamAttributeSeasonOptionResponse(
      competitionId: competitionId,
      seasonId: seasonId,
      seasonName: seasonName,
      isCurrent: isCurrent,
    );
  }
}
