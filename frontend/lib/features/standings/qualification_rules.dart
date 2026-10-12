part of 'standing_features.dart';

enum QualificationTier { ucl, uel, conference, relegation, roundOf16, playoff }

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
      case QualificationTier.roundOf16:
        return 'Round of 16';
      case QualificationTier.playoff:
        return 'Play-offs';
    }
  }

  Color get color {
    switch (this) {
      case QualificationTier.ucl:
      case QualificationTier.roundOf16:
        return const Color(0xFF2D8CFF);
      case QualificationTier.uel:
        return const Color(0xFFFF7A3D);
      case QualificationTier.conference:
      case QualificationTier.playoff:
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
      case QualificationTier.roundOf16:
      case QualificationTier.playoff:
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
  final Map<QualificationTier, Set<int>> positions;
  final Map<QualificationTier, Set<int>> qualifyingPositions;

  const LeagueQualificationRules({
    required this.positions,
    this.qualifyingPositions = const {},
  });

  QualificationMarker? markerFor(int position) {
    for (final tier in availableTiers) {
      if (positions[tier]?.contains(position) ?? false) {
        return QualificationMarker(tier);
      }
      if (qualifyingPositions[tier]?.contains(position) ?? false) {
        return QualificationMarker(tier, usesLightColor: true);
      }
    }
    return null;
  }

  QualificationTier? tierFor(int position) => markerFor(position)?.tier;

  List<QualificationTier> get availableTiers => QualificationTier.values
      .where((tier) =>
          positions.containsKey(tier) || qualifyingPositions.containsKey(tier))
      .toList();
}

// 세 유럽대항전의 리그 페이즈는 같은 진출 구간을 사용해요.
const _leaguePhaseRules = LeagueQualificationRules(positions: {
  QualificationTier.roundOf16: {1, 2, 3, 4, 5, 6, 7, 8},
  QualificationTier.playoff: {
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24
  },
});

// 리그 ID별 진출·강등 표시 위치를 고정값으로 두며 시즌별 규칙 변경은 반영하지 않아요.
const Map<int, LeagueQualificationRules> _leagueRules = {
  2: _leaguePhaseRules,
  5: _leaguePhaseRules,
  2286: _leaguePhaseRules,
  8: LeagueQualificationRules(positions: {
    QualificationTier.ucl: {1, 2, 3, 4, 5},
    QualificationTier.uel: {6, 7},
    QualificationTier.conference: {8},
    QualificationTier.relegation: {18, 19, 20},
  }),
  82: LeagueQualificationRules(positions: {
    QualificationTier.ucl: {1, 2, 3, 4},
    QualificationTier.uel: {5, 6},
    QualificationTier.conference: {7},
    QualificationTier.relegation: {17, 18},
  }, qualifyingPositions: {
    QualificationTier.relegation: {16},
  }),
  301: LeagueQualificationRules(positions: {
    QualificationTier.ucl: {1, 2, 3},
    QualificationTier.uel: {5, 6},
    QualificationTier.conference: {7},
    QualificationTier.relegation: {17, 18},
  }, qualifyingPositions: {
    QualificationTier.ucl: {4},
    QualificationTier.relegation: {16},
  }),
  384: LeagueQualificationRules(positions: {
    QualificationTier.ucl: {1, 2, 3, 4},
    QualificationTier.uel: {5, 6},
    QualificationTier.conference: {7},
    QualificationTier.relegation: {18, 19, 20},
  }),
  564: LeagueQualificationRules(positions: {
    QualificationTier.ucl: {1, 2, 3, 4, 5},
    QualificationTier.uel: {6},
    QualificationTier.conference: {7},
    QualificationTier.relegation: {18, 19, 20},
  }),
};

LeagueQualificationRules? rulesForLeague(int leagueId) =>
    _leagueRules[leagueId];
