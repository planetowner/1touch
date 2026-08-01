import 'package:flutter/material.dart';

enum PlayerPosition {
  goalkeeper('GK'),
  defender('DF'),
  midfielder('MF'),
  forward('FW');

  final String label;

  const PlayerPosition(this.label);
}

class PlayerSeasonStats {
  final String season;
  final int appearances;
  final int starts;
  final int goals;
  final int assists;
  final double rating;
  final int passes;
  final double passAccuracy;
  final int cleanSheets;
  final int saves;

  const PlayerSeasonStats({
    this.season = '2025/2026',
    required this.appearances,
    required this.starts,
    required this.goals,
    required this.assists,
    required this.rating,
    required this.passes,
    required this.passAccuracy,
    this.cleanSheets = 0,
    this.saves = 0,
  });
}

class PlayerMatchSummary {
  final String result;
  final String score;
  final String competition;
  final String opponent;
  final String? opponentLogoAsset;
  final int goals;
  final int assists;
  final int passes;
  final double rating;

  const PlayerMatchSummary({
    required this.result,
    required this.score,
    required this.competition,
    required this.opponent,
    this.opponentLogoAsset,
    required this.goals,
    required this.assists,
    required this.passes,
    required this.rating,
  });
}

class PlayerClubPeriod {
  final String club;
  final String? logoAsset;
  final String fromSeason;
  final String toSeason;
  final int appearances;
  final int goals;

  const PlayerClubPeriod({
    required this.club,
    this.logoAsset,
    required this.fromSeason,
    required this.toSeason,
    required this.appearances,
    required this.goals,
  });

  String get seasonLabel =>
      fromSeason == toSeason ? fromSeason : '$fromSeason–$toSeason';
}

class PlayerCompetitionStats {
  final String competitionCode;
  final String competitionName;
  final int appearances;
  final int wins;
  final double rating;

  const PlayerCompetitionStats({
    required this.competitionCode,
    required this.competitionName,
    required this.appearances,
    required this.wins,
    required this.rating,
  })  : assert(appearances >= 0),
        assert(wins >= 0 && wins <= appearances);

  int get winRatePercent =>
      appearances == 0 ? 0 : (wins * 100 / appearances).round();
}

class PlayerCareerSeason {
  final int teamId;
  final String seasonLabel;
  final List<PlayerCompetitionStats> competitions;

  const PlayerCareerSeason({
    required this.teamId,
    required this.seasonLabel,
    required this.competitions,
  }) : assert(competitions.length > 0);

  int get appearances => competitions.fold(
        0,
        (total, competition) => total + competition.appearances,
      );

  int get wins => competitions.fold(
        0,
        (total, competition) => total + competition.wins,
      );

  int get winRatePercent =>
      appearances == 0 ? 0 : (wins * 100 / appearances).round();

  double get rating {
    if (appearances == 0) return 0;
    final weightedTotal = competitions.fold<double>(
      0,
      (total, competition) =>
          total + competition.rating * competition.appearances,
    );
    return weightedTotal / appearances;
  }
}

class PlayerAward {
  final String name;
  final List<String> seasons;

  const PlayerAward({
    required this.name,
    required this.seasons,
  });
}

class Player {
  /// Stable frontend identifier. Backend/provider identifiers can be attached
  /// separately without changing routes, favorites, or comparison records.
  final String id;
  final int? externalPlayerId;
  final String fullName;
  final String shortName;
  final List<String> searchAliases;
  final int teamId;
  final String teamName;
  final String leagueName;
  final String leagueCode;
  final int jerseyNumber;
  final List<PlayerPosition> positions;
  final String nationality;
  final String nationalityFlag;
  final String dateOfBirth;
  final int heightCm;
  final int weightKg;
  final String preferredFoot;
  final String marketValue;
  final String form;
  final String squadRole;
  final List<Color> teamColor;
  final String? imageAsset;
  final String? teamLogoAsset;
  final double rankingScore;
  final int rankingChange;
  final bool isFavorite;
  final bool isOneToWatch;
  final List<double> radarValues;
  final PlayerSeasonStats seasonStats;
  final List<PlayerClubPeriod> clubHistory;
  final List<PlayerCareerSeason> careerSeasons;
  final List<PlayerAward> personalAwards;

  const Player({
    required this.id,
    this.externalPlayerId,
    required this.fullName,
    required this.shortName,
    this.searchAliases = const [],
    required this.teamId,
    required this.teamName,
    required this.leagueName,
    required this.leagueCode,
    required this.jerseyNumber,
    required this.positions,
    required this.nationality,
    required this.nationalityFlag,
    required this.dateOfBirth,
    required this.heightCm,
    required this.weightKg,
    required this.preferredFoot,
    required this.marketValue,
    required this.form,
    required this.squadRole,
    required this.teamColor,
    this.imageAsset,
    this.teamLogoAsset,
    required this.rankingScore,
    this.rankingChange = 0,
    this.isFavorite = false,
    this.isOneToWatch = false,
    required this.radarValues,
    required this.seasonStats,
    this.clubHistory = const [],
    this.careerSeasons = const [],
    this.personalAwards = const [],
  })  : assert(radarValues.length == 5),
        assert(teamColor.length >= 2);

  String get positionLabel =>
      positions.map((position) => position.label).join(' • ');

  String get searchableText => [
        fullName,
        shortName,
        teamName,
        nationality,
        ...searchAliases,
      ].join(' ').toLowerCase();
}

class RealPlayer {
  final String squadId;
  final int id;
  final String displayName;
  final String firstName;
  final String lastName;
  final String imagePath;
  final DateTime dateOfBirth;
  final int height;
  final int? weight;
  final int nationalityId;
  final int positionId;
  final int? jerseyNumber;

  RealPlayer({
    required this.squadId,
    required this.id,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    required this.imagePath,
    required this.dateOfBirth,
    required this.height,
    this.weight,
    required this.nationalityId,
    required this.positionId,
    this.jerseyNumber,
  });

  factory RealPlayer.fromSquadJson(Map<String, dynamic> squadJson) {
    final player = squadJson['players'] as Map<String, dynamic>;
    return RealPlayer(
      squadId: squadJson['id'] as String,
      id: player['id'] as int,
      displayName: player['display_name'] as String,
      firstName: player['firstname'] as String,
      lastName: player['lastname'] as String,
      imagePath: player['image_path'] as String,
      dateOfBirth: DateTime.parse(player['date_of_birth'] as String),
      height: player['height'] as int,
      weight: player['weight'] as int?,
      nationalityId: player['nationality_id'] as int,
      positionId: player['position_id'] as int,
      jerseyNumber: squadJson['jersey_number'] as int?,
    );
  }
}
