import 'package:onetouch/models/team_form_comparison.dart';

TeamFormComparison mockTeamFormComparison(int teamId) {
  return TeamFormComparison(
    current: TeamFormSeries(
      teamId: teamId,
      seasonLabel: '23/24',
      points: _points([
        0,
        0,
        3,
        6,
        6,
        9,
        12,
        12,
        15,
        15,
        18,
        21,
        21,
        21,
        24,
        27,
      ]),
    ),
    comparisons: [
      TeamFormSeries(
        teamId: teamId,
        seasonLabel: '22/23',
        points: _points([
          0,
          3,
          3,
          6,
          9,
          9,
          12,
          12,
          15,
          15,
          15,
          18,
          21,
          24,
          27,
          27,
        ]),
      ),
      TeamFormSeries(
        teamId: teamId,
        seasonLabel: '21/22',
        points: _points([
          1,
          4,
          7,
          7,
          10,
          13,
          13,
          16,
          19,
          19,
          22,
          22,
          25,
          28,
          28,
          31,
        ]),
      ),
    ],
  );
}

List<TeamFormPoint> _points(List<int> cumulativePoints) {
  return List.generate(
    cumulativePoints.length,
    (index) => TeamFormPoint(
      round: index + 1,
      points: cumulativePoints[index],
    ),
    growable: false,
  );
}
