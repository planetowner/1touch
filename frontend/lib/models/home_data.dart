import 'package:flutter/foundation.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team.dart';

/// User-specific team and fixture data returned for the Home screen.
///
/// The app requires a favorite team before Home can be opened. Transport
/// implementations must reject a missing favorite instead of creating this
/// model with incomplete data.
@immutable
class HomeData {
  HomeData({
    required this.favoriteTeam,
    required List<Team> followingTeams,
    required this.nextMatch,
    required this.lastMatch,
    required List<HomeCalendarFixture> calendar,
  })  : followingTeams = List.unmodifiable(followingTeams),
        calendar = List.unmodifiable(calendar);

  final Team favoriteTeam;
  final List<Team> followingTeams;
  final Fixture? nextMatch;
  final Fixture? lastMatch;
  final List<HomeCalendarFixture> calendar;

  Fixture? get liveMatch {
    for (final calendarFixture in calendar) {
      if (calendarFixture.fixture.status == FixtureStatus.live) {
        return calendarFixture.fixture;
      }
    }
    return null;
  }
}

/// A Home calendar fixture with the opponent data needed to render it.
///
/// The opponent is contextual to the user's favorite team, so it belongs to
/// the Home aggregate instead of the stable [Fixture] entity.
@immutable
class HomeCalendarFixture {
  const HomeCalendarFixture({
    required this.fixture,
    required this.opponent,
  });

  final Fixture fixture;
  final Team opponent;
}
