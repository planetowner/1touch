import 'package:onetouch/models/team_attribute_scores.dart';

// 5대 리그 팀 Attribute의 예시 점수예요. 실제 계산값은 API에서 받아요.
// 필드와 축 순서는 서버의 다섯 지표에 맞추고, 점수 범위는 5~95로 유지해요.

const mockTeamAttributes = <TeamAttributeScores>[
  //   FC Barcelona
  TeamAttributeScores(
      teamId: 83,
      competitionId: 564,
      seasonId: 23621,
      seasonLabel: '24/25',
      shootingFinishing: 92,
      attackingThreat: 85,
      chanceCreation: 88,
      defending: 75,
      possessionBuildUp: 94),
  TeamAttributeScores(
      teamId: 83,
      competitionId: 564,
      seasonId: 19799,
      seasonLabel: '22/23',
      shootingFinishing: 82,
      attackingThreat: 78,
      chanceCreation: 80,
      defending: 82,
      possessionBuildUp: 89),
  TeamAttributeScores(
      teamId: 83,
      competitionId: 564,
      seasonId: 18462,
      seasonLabel: '21/22',
      shootingFinishing: 75,
      attackingThreat: 72,
      chanceCreation: 75,
      defending: 78,
      possessionBuildUp: 86),
  TeamAttributeScores(
      teamId: 83,
      competitionId: 564,
      seasonId: 17480,
      seasonLabel: '20/21',
      shootingFinishing: 72,
      attackingThreat: 70,
      chanceCreation: 73,
      defending: 75,
      possessionBuildUp: 88),

  //   Real Madrid
  TeamAttributeScores(
      teamId: 3468,
      competitionId: 564,
      seasonId: 23621,
      seasonLabel: '24/25',
      shootingFinishing: 88,
      attackingThreat: 82,
      chanceCreation: 84,
      defending: 82,
      possessionBuildUp: 80),
  TeamAttributeScores(
      teamId: 3468,
      competitionId: 564,
      seasonId: 19799,
      seasonLabel: '22/23',
      shootingFinishing: 85,
      attackingThreat: 80,
      chanceCreation: 82,
      defending: 85,
      possessionBuildUp: 78),
  TeamAttributeScores(
      teamId: 3468,
      competitionId: 564,
      seasonId: 18462,
      seasonLabel: '21/22',
      shootingFinishing: 90,
      attackingThreat: 78,
      chanceCreation: 85,
      defending: 80,
      possessionBuildUp: 75),

  //   Liverpool
  TeamAttributeScores(
      teamId: 8,
      competitionId: 8,
      seasonId: 23614,
      seasonLabel: '24/25',
      shootingFinishing: 90,
      attackingThreat: 84,
      chanceCreation: 86,
      defending: 78,
      possessionBuildUp: 78),
  TeamAttributeScores(
      teamId: 8,
      competitionId: 8,
      seasonId: 19734,
      seasonLabel: '22/23',
      shootingFinishing: 84,
      attackingThreat: 80,
      chanceCreation: 80,
      defending: 75,
      possessionBuildUp: 76),

  //   Arsenal
  TeamAttributeScores(
      teamId: 19,
      competitionId: 8,
      seasonId: 23614,
      seasonLabel: '24/25',
      shootingFinishing: 87,
      attackingThreat: 85,
      chanceCreation: 83,
      defending: 85,
      possessionBuildUp: 81),
  TeamAttributeScores(
      teamId: 19,
      competitionId: 8,
      seasonId: 19734,
      seasonLabel: '22/23',
      shootingFinishing: 80,
      attackingThreat: 78,
      chanceCreation: 78,
      defending: 80,
      possessionBuildUp: 76),

  //   Manchester City
  TeamAttributeScores(
      teamId: 9,
      competitionId: 8,
      seasonId: 23614,
      seasonLabel: '24/25',
      shootingFinishing: 88,
      attackingThreat: 86,
      chanceCreation: 87,
      defending: 80,
      possessionBuildUp: 92),
  TeamAttributeScores(
      teamId: 9,
      competitionId: 8,
      seasonId: 19734,
      seasonLabel: '22/23',
      shootingFinishing: 92,
      attackingThreat: 88,
      chanceCreation: 90,
      defending: 84,
      possessionBuildUp: 94),

  //   Bayern Munich
  TeamAttributeScores(
      teamId: 503,
      competitionId: 82,
      seasonId: 23744,
      seasonLabel: '24/25',
      shootingFinishing: 90,
      attackingThreat: 84,
      chanceCreation: 85,
      defending: 78,
      possessionBuildUp: 86),

  //   PSG
  TeamAttributeScores(
      teamId: 591,
      competitionId: 301,
      seasonId: 23643,
      seasonLabel: '24/25',
      shootingFinishing: 88,
      attackingThreat: 82,
      chanceCreation: 86,
      defending: 76,
      possessionBuildUp: 84),

  //   Inter Milan
  TeamAttributeScores(
      teamId: 2930,
      competitionId: 384,
      seasonId: 23746,
      seasonLabel: '24/25',
      shootingFinishing: 86,
      attackingThreat: 80,
      chanceCreation: 82,
      defending: 84,
      possessionBuildUp: 80),
];

//
