import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/api_client_provider.dart';

typedef BracketSlot = ({int? teamId, String label});
typedef BracketMatch = ({
  int id,
  bool detailAvailable,
  String status,
  int? homeScore,
  int? awayScore
});
typedef BracketTie = ({
  String id,
  List<BracketSlot> slots,
  List<int>? aggregateScore,
  int? winnerTeamId,
  List<BracketMatch> matches
});
typedef BracketStage = ({String name, List<BracketTie> ties});

class TournamentBracket {
  const TournamentBracket({required this.status, required this.stages});
  final String status;
  final List<BracketStage> stages;

  factory TournamentBracket.fromJson(Map<String, dynamic> json) =>
      TournamentBracket(
        status: json['status'] as String,
        stages: (json['stages'] as List)
            .map((stage) => (
                  name: stage['name'] as String,
                  ties: (stage['ties'] as List)
                      .map((tie) => (
                            id: tie['tie_id'] as String,
                            slots: (tie['slots'] as List)
                                .map((slot) => (
                                      teamId: slot['team_id'] as int?,
                                      label: slot['label'] as String
                                    ))
                                .toList(),
                            aggregateScore:
                                (tie['aggregate_score'] as List?)?.cast<int>(),
                            winnerTeamId: tie['winner_team_id'] as int?,
                            matches: (tie['fixtures'] as List)
                                .map((match) => (
                                      id: match['fixture_id'] as int,
                                      detailAvailable:
                                          match['detail_available'] as bool,
                                      status: match['state'] as String,
                                      homeScore: match['home_score'] as int?,
                                      awayScore: match['away_score'] as int?,
                                    ))
                                .toList(),
                          ))
                      .toList(),
                ))
            .toList(),
      );
}

class TournamentBracketRepository {
  TournamentBracketRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;
  static const supportedCompetitions = {2, 5, 2286, 24, 27, 390, 570};

  Future<TournamentBracket> load(int competitionId, int seasonId) async {
    final response = await _api.get(_api.baseUri
        .resolve('competitions/$competitionId/bracket')
        .replace(queryParameters: {'season_id': '$seasonId'}));
    final json = _api.decodeJson<Map<String, dynamic>>(response);
    if (json['competition_id'] != competitionId ||
        json['season_id'] != seasonId) {
      throw const FormatException('Bracket identity mismatch.');
    }
    return TournamentBracket.fromJson(json);
  }
}

final tournamentBracketRepository = TournamentBracketRepository(api: apiClient);
