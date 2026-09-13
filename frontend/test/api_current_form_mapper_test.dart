import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/current_form/api/api_current_form_mapper.dart';
import 'package:onetouch/data/current_form/api/api_current_form_response.dart';

void main() {
  test('maps competition_id to the domain league identity', () {
    const response = ApiCurrentFormOptionsResponse(
      items: [
        ApiCurrentFormOptionResponse(
          teamId: 83,
          teamName: null,
          teamShortCode: null,
          teamLogo: null,
          competitionId: 564,
          seasonId: 25659,
          seasonName: '2025/2026',
          roundsAvailable: 2,
          latestRound: 2,
        ),
      ],
      limit: 200,
    );

    final options = currentFormOptionsFromApiResponse(response);

    expect(options.single.leagueId, 564);
    expect(options.single.seasonStart, isNull);
    expect(options.single.seasonEnd, isNull);
    expect(options.single.teamName, isNull);
    expect(() => options.clear(), throwsUnsupportedError);
  });

  test('maps comparison points and treats offset-less match dates as UTC', () {
    const response = ApiCurrentFormResponse(
      current: ApiCurrentFormSeriesResponse(
        teamId: 83,
        teamName: 'FC Barcelona',
        teamShortCode: 'BAR',
        teamLogo: null,
        competitionId: 564,
        seasonId: 25659,
        seasonName: '2025/2026',
        isCurrent: true,
        points: [
          ApiCurrentFormPointResponse(
            roundNo: 0,
            matchDate: null,
            cumulativePoints: 0,
          ),
          ApiCurrentFormPointResponse(
            roundNo: 2,
            matchDate: '2025-08-16T19:00:00',
            cumulativePoints: 4,
          ),
        ],
      ),
      comparison: ApiCurrentFormSeriesResponse(
        teamId: 83,
        teamName: 'FC Barcelona',
        teamShortCode: 'BAR',
        teamLogo: null,
        competitionId: 564,
        seasonId: 23621,
        seasonName: '2024/2025',
        isCurrent: false,
        points: [],
      ),
      maxRound: 2,
      maxPoints: 4,
    );

    final comparison = currentFormComparisonFromApiResponse(response);

    expect(comparison.current.leagueId, 564);
    expect(comparison.current.points.first.matchDate, isNull);
    expect(
      comparison.current.points.last.matchDate,
      DateTime.utc(2025, 8, 16, 19),
    );
    expect(comparison.comparison.seasonId, 23621);
  });

  test('rejects an invalid non-null match date', () {
    const response = ApiCurrentFormResponse(
      current: ApiCurrentFormSeriesResponse(
        teamId: 83,
        teamName: 'FC Barcelona',
        teamShortCode: 'BAR',
        teamLogo: null,
        competitionId: 564,
        seasonId: 25659,
        seasonName: '2025/2026',
        isCurrent: true,
        points: [
          ApiCurrentFormPointResponse(
            roundNo: 1,
            matchDate: 'not-a-date',
            cumulativePoints: 3,
          ),
        ],
      ),
      comparison: ApiCurrentFormSeriesResponse(
        teamId: 83,
        teamName: 'FC Barcelona',
        teamShortCode: 'BAR',
        teamLogo: null,
        competitionId: 564,
        seasonId: 23621,
        seasonName: '2024/2025',
        isCurrent: false,
        points: [],
      ),
      maxRound: 1,
      maxPoints: 3,
    );

    expect(
      () => currentFormComparisonFromApiResponse(response),
      throwsFormatException,
    );
  });
}
