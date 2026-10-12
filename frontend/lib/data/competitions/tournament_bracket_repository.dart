import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/api_client_provider.dart';

typedef BracketSlot = ({int? teamId, String label, String? sourceTieId});
typedef BracketMatch = ({
  int id,
  bool detailAvailable,
  String status,
  int? homeScore,
  int? awayScore
});
typedef BracketTie = ({
  String id,
  String? nextTieId,
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

  factory TournamentBracket.fromJson(Map<String, dynamic> json) {
    final stages = (json['stages'] as List)
        .map((stage) => (
              name: stage['name'] as String,
              ties: (stage['ties'] as List)
                  .map((tie) => (
                        id: tie['tie_id'] as String,
                        nextTieId: tie['next_tie_id'] as String?,
                        slots: (tie['slots'] as List)
                            .map((slot) => (
                                  teamId: slot['team_id'] as int?,
                                  label: slot['label'] as String,
                                  sourceTieId: slot['source_tie_id'] as String?,
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
        .toList();
    // API의 경기 ID 순서는 대진 경로와 달라요. 다음 대진 순서에 맞춰 앞 라운드를 묶어요.
    for (var index = stages.length - 2; index >= 0; index--) {
      final ties = stages[index].ties;
      final following = stages[index + 1].ties;
      final destinations = {
        for (var i = 0; i < following.length; i++) following[i].id: i,
      };
      final original = {for (var i = 0; i < ties.length; i++) ties[i].id: i};
      ties.sort((a, b) {
        final byDestination = (destinations[a.nextTieId] ?? following.length)
            .compareTo(destinations[b.nextTieId] ?? following.length);
        return byDestination != 0
            ? byDestination
            : original[a.id]!.compareTo(original[b.id]!);
      });
    }
    return TournamentBracket(status: json['status'] as String, stages: stages);
  }
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
