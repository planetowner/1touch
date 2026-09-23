import 'package:onetouch/models/fixture_detail.dart';
import 'package:onetouch/models/player_club_history.dart';

typedef PlayerDetailProfile = ({
  String name,
  String? image,
  int? teamId,
  String? teamName,
  String? teamImage,
  int? jerseyNumber,
  int? heightCm,
  int? weightKg,
  DateTime? birthDate,
  String? nationality,
  String? nationalityImage,
  String? position,
  String? squadRole,
});
typedef PlayerDetailSeason = ({
  int id,
  String name,
  int competitionId,
  String competitionName
});
typedef PlayerRecord = ({
  int appearances,
  int starts,
  int minutes,
  double? winRate,
  double? rating
});
typedef PlayerCompetitionRecord = ({int id, String name, PlayerRecord record});
typedef PlayerCareerRecord = ({
  String season,
  int teamId,
  String teamName,
  String? teamCode,
  String? teamImage,
  PlayerRecord record,
  List<PlayerCompetitionRecord> competitions
});
typedef PlayerHonour = ({
  int teamId,
  String? teamName,
  String? teamImage,
  int competitionId,
  String? competitionName,
  String? season
});
typedef PlayerPerformancePoint = ({int fixtureId, int round, double? rating});
typedef PlayerCandidate = ({int id, String name, String? image});

class PlayerDetailMatch {
  const PlayerDetailMatch(
      {required this.id,
      required this.date,
      required this.live,
      required this.competition,
      required this.round,
      required this.opponent,
      required this.opponentImage,
      required this.result,
      required this.homeScore,
      required this.awayScore,
      required this.rating,
      required this.metrics});
  final int id;
  final DateTime date;
  final bool live;
  final String competition;
  final String? round;
  final String? opponent;
  final String? opponentImage;
  final String? result;
  final int? homeScore, awayScore;
  final double? rating;
  final List<FixturePlayerStatMetric> metrics;
}

class PlayerSeasonMetric {
  const PlayerSeasonMetric(
      {required this.metric,
      required this.per90,
      required this.rank,
      required this.referenceCount,
      required this.percentile,
      required this.observedMatches,
      required this.totalMatches});
  final FixturePlayerStatMetric metric;
  final double? per90, percentile;
  final int? rank;
  final int referenceCount, observedMatches, totalMatches;
}

typedef PlayerSeasonCategory = ({
  String code,
  String label,
  List<PlayerSeasonMetric> metrics
});

class PlayerAnalysis {
  const PlayerAnalysis(
      {required this.position,
      required this.categories,
      required this.topStats,
      required this.minimumMinutes,
      required this.referencePlayers,
      required this.startingRate,
      required this.winRate,
      required this.teamMatches,
      required this.starts,
      required this.performance});
  final String? position;
  final List<PlayerSeasonCategory> categories;
  final List<PlayerSeasonMetric> topStats;
  final int minimumMinutes, referencePlayers, teamMatches, starts;
  final double? startingRate, winRate;
  final List<PlayerPerformancePoint> performance;
}

class PlayerDetail {
  const PlayerDetail(
      {required this.playerId,
      required this.profile,
      required this.currentSeason,
      required this.currentPosition,
      required this.seasons,
      required this.selectedSeason,
      required this.competitions,
      required this.matches,
      required this.analysis,
      required this.career,
      required this.clubs,
      required this.honours});
  final int playerId;
  final PlayerDetailProfile profile;
  final String? currentSeason, currentPosition;
  final List<PlayerDetailSeason> seasons;
  final PlayerDetailSeason? selectedSeason;
  final List<PlayerCompetitionRecord> competitions;
  final List<PlayerDetailMatch> matches;
  final PlayerAnalysis? analysis;
  final List<PlayerCareerRecord> career;
  final List<PlayerClubHistoryEntry> clubs;
  final List<PlayerHonour> honours;
}

PlayerCandidate playerCandidateFromJson(Map<String, dynamic> json) => (
      id: json['player_id'] as int,
      name: json['name'] as String,
      image: json['image'] as String?,
    );
