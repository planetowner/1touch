import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/match_info/relevant_standings.dart';
import 'package:onetouch/models/standing.dart';

void main() {
  final standings = List.generate(20, (index) => _standing(index + 1));

  test('far-apart teams receive three relevant rows each', () {
    final selection = selectRelevantMatchStandings(
      standings.reversed.toList(),
      homeTeamId: 1,
      awayTeamId: 17,
    );

    expect(_positions(selection), [1, 2, 3, 16, 17, 18]);
    expect(selection.dividerIndex, 3);
  });

  test('nearby teams share one continuous six-row window', () {
    final selection = selectRelevantMatchStandings(
      standings,
      homeTeamId: 17,
      awayTeamId: 18,
    );

    expect(_positions(selection), [15, 16, 17, 18, 19, 20]);
    expect(selection.dividerIndex, -1);
  });

  test('mid-table nearby teams stay centered in a continuous window', () {
    final selection = selectRelevantMatchStandings(
      standings,
      homeTeamId: 7,
      awayTeamId: 9,
    );

    expect(_positions(selection), [6, 7, 8, 9, 10, 11]);
    expect(selection.dividerIndex, -1);
  });

  test('top-table window clamps to the first six teams', () {
    final selection = selectRelevantMatchStandings(
      standings,
      homeTeamId: 1,
      awayTeamId: 4,
    );

    expect(_positions(selection), [1, 2, 3, 4, 5, 6]);
  });

  test('one available fixture team receives a centered six-row window', () {
    final selection = selectRelevantMatchStandings(
      standings,
      homeTeamId: 17,
      awayTeamId: 999,
    );

    expect(_positions(selection), [15, 16, 17, 18, 19, 20]);
    expect(selection.dividerIndex, -1);
  });

  test('missing fixture teams fall back to the first six rows', () {
    final selection = selectRelevantMatchStandings(
      standings,
      homeTeamId: 998,
      awayTeamId: 999,
    );

    expect(_positions(selection), [1, 2, 3, 4, 5, 6]);
  });

  test('short competitions show every available team', () {
    final selection = selectRelevantMatchStandings(
      standings.take(4).toList().reversed.toList(),
      homeTeamId: 1,
      awayTeamId: 4,
    );

    expect(_positions(selection), [1, 2, 3, 4]);
    expect(selection.dividerIndex, -1);
  });
}

List<int> _positions(RelevantStandingWindow selection) =>
    selection.standings.map((row) => row.position).toList();

Standing _standing(int position) => Standing(
      competitionId: 8,
      seasonId: 1,
      phase: StandingPhase.league,
      groupName: '',
      teamId: position,
      teamName: 'Team $position',
      position: position,
      matchesPlayed: 10,
      won: 0,
      draw: 0,
      lost: 0,
      goalsFor: 0,
      goalsAgainst: 0,
      goalDiff: 0,
      points: 0,
      last5Form: const [],
    );
