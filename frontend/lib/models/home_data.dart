import 'package:flutter/foundation.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/home_content_item.dart';
import 'package:onetouch/models/team.dart';

/// 홈에서 조회한 팀과 해당 팀의 경기·콘텐츠예요.
@immutable
class HomeData {
  HomeData({
    required this.favoriteTeam,
    required List<Team> followingTeams,
    required this.nextMatch,
    required this.lastMatch,
    required List<HomeCalendarFixture> calendar,
    required List<HomeContentItem> highlights,
    this.leaguePosition,
    this.leagueRankDelta,
  })  : followingTeams = List.unmodifiable(followingTeams),
        calendar = List.unmodifiable(calendar),
        highlights = List.unmodifiable(highlights);

  // 기존 API의 favorite_team 필드예요. 홈에서 팀을 전환하면 조회 팀을 담아요.
  final Team favoriteTeam;
  final List<Team> followingTeams;
  final Fixture? nextMatch;
  final Fixture? lastMatch;
  final List<HomeCalendarFixture> calendar;
  final List<HomeContentItem> highlights;
  final int? leaguePosition;
  final int? leagueRankDelta;

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
/// The opponent is contextual to the viewed team, so it belongs to
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
