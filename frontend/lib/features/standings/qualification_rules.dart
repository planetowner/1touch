part of 'standing_features.dart';

enum QualificationTier { ucl, uel, conference, relegation }

extension QualificationTierMeta on QualificationTier {
  String get label {
    switch (this) {
      case QualificationTier.ucl:
        return 'UCL';
      case QualificationTier.uel:
        return 'UEL';
      case QualificationTier.conference:
        return 'CONF';
      case QualificationTier.relegation:
        return 'REL';
    }
  }

  Color get color {
    switch (this) {
      case QualificationTier.ucl:
        return const Color(0xFF2D8CFF);
      case QualificationTier.uel:
        return const Color(0xFFFF7A3D);
      case QualificationTier.conference:
        return const Color(0xFF22C55E);
      case QualificationTier.relegation:
        return const Color(0xFFEF4444);
    }
  }

  Color get lightColor {
    switch (this) {
      case QualificationTier.ucl:
        return const Color(0xFF8EC5FF);
      case QualificationTier.relegation:
        return const Color(0xFFFCA5A5);
      case QualificationTier.uel:
      case QualificationTier.conference:
        return color;
    }
  }
}

class QualificationMarker {
  final QualificationTier tier;
  final bool usesLightColor;

  const QualificationMarker(
    this.tier, {
    this.usesLightColor = false,
  });

  Color get color => usesLightColor ? tier.lightColor : tier.color;
}

class LeagueQualificationRules {
  final Set<int> uclPositions;
  final Set<int> uclQualifyingPositions;
  final Set<int> uelPositions;
  final Set<int> conferencePositions;
  final Set<int> relegationPlayoffPositions;
  final Set<int> relegationPositions;

  const LeagueQualificationRules({
    this.uclPositions = const {},
    this.uclQualifyingPositions = const {},
    this.uelPositions = const {},
    this.conferencePositions = const {},
    this.relegationPlayoffPositions = const {},
    this.relegationPositions = const {},
  });

  QualificationMarker? markerFor(int position) {
    if (uclPositions.contains(position)) {
      return const QualificationMarker(QualificationTier.ucl);
    }
    if (uclQualifyingPositions.contains(position)) {
      return const QualificationMarker(
        QualificationTier.ucl,
        usesLightColor: true,
      );
    }
    if (uelPositions.contains(position)) {
      return const QualificationMarker(QualificationTier.uel);
    }
    if (conferencePositions.contains(position)) {
      return const QualificationMarker(QualificationTier.conference);
    }
    if (relegationPlayoffPositions.contains(position)) {
      return const QualificationMarker(
        QualificationTier.relegation,
        usesLightColor: true,
      );
    }
    if (relegationPositions.contains(position)) {
      return const QualificationMarker(QualificationTier.relegation);
    }
    return null;
  }

  QualificationTier? tierFor(int position) => markerFor(position)?.tier;

  List<QualificationTier> get availableTiers => [
        if (uclPositions.isNotEmpty || uclQualifyingPositions.isNotEmpty)
          QualificationTier.ucl,
        if (uelPositions.isNotEmpty) QualificationTier.uel,
        if (conferencePositions.isNotEmpty) QualificationTier.conference,
        if (relegationPositions.isNotEmpty ||
            relegationPlayoffPositions.isNotEmpty)
          QualificationTier.relegation,
      ];
}

const Map<int, LeagueQualificationRules> _leagueRules = {
  8: LeagueQualificationRules(
    uclPositions: {1, 2, 3, 4, 5},
    uelPositions: {6, 7},
    conferencePositions: {8},
    relegationPositions: {18, 19, 20},
  ),
  82: LeagueQualificationRules(
    uclPositions: {1, 2, 3, 4},
    uelPositions: {5, 6},
    conferencePositions: {7},
    relegationPlayoffPositions: {16},
    relegationPositions: {17, 18},
  ),
  301: LeagueQualificationRules(
    uclPositions: {1, 2, 3},
    uclQualifyingPositions: {4},
    uelPositions: {5, 6},
    conferencePositions: {7},
    relegationPlayoffPositions: {16},
    relegationPositions: {17, 18},
  ),
  384: LeagueQualificationRules(
    uclPositions: {1, 2, 3, 4},
    uelPositions: {5, 6},
    conferencePositions: {7},
    relegationPositions: {18, 19, 20},
  ),
  564: LeagueQualificationRules(
    uclPositions: {1, 2, 3, 4, 5},
    uelPositions: {6},
    conferencePositions: {7},
    relegationPositions: {18, 19, 20},
  ),
};

LeagueQualificationRules? rulesForLeague(int leagueId) =>
    _leagueRules[leagueId];
