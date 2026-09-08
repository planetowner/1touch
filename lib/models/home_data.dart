import 'package:flutter/foundation.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team.dart';

/// User-specific team and fixture data returned for the Home screen.
@immutable
class HomeData {
  HomeData({
    required this.favoriteTeam,
    required List<Team> followingTeams,
    required this.nextMatch,
    required this.lastMatch,
    required List<Fixture> calendar,
  })  : followingTeams = List.unmodifiable(followingTeams),
        calendar = List.unmodifiable(calendar);

  final Team? favoriteTeam;
  final List<Team> followingTeams;
  final Fixture? nextMatch;
  final Fixture? lastMatch;
  final List<Fixture> calendar;

  Fixture? get liveMatch {
    for (final fixture in calendar) {
      if (fixture.status == FixtureStatus.live) return fixture;
    }
    return null;
  }
}
