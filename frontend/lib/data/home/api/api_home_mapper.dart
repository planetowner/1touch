import 'package:onetouch/data/fixtures/api/api_fixture_mapper.dart';
import 'package:onetouch/data/home/api/api_home_response.dart';
import 'package:onetouch/data/teams/api/api_team_mapper.dart';
import 'package:onetouch/models/home_content_item.dart';
import 'package:onetouch/models/home_data.dart';
import 'package:onetouch/models/team.dart';

HomeData homeDataFromApiResponse(
  ApiHomeResponse response, {
  DateTime? now,
}) {
  final favoriteResponse = response.favoriteTeam;
  if (favoriteResponse == null) {
    throw StateError('Home response requires a favorite team.');
  }

  final favoriteTeam = teamFromApiResponse(favoriteResponse);
  final highlightsResponse = response.highlights;
  if (highlightsResponse != null &&
      highlightsResponse.teamId != favoriteTeam.teamId) {
    throw StateError(
      'Home highlights team ${highlightsResponse.teamId} must match favorite '
      'team ${favoriteTeam.teamId}.',
    );
  }
  final followingTeams =
      response.followingTeams.map(teamFromApiResponse).toList(growable: false);
  if (!followingTeams.any((team) => team.teamId == favoriteTeam.teamId)) {
    throw StateError(
      'Favorite team ${favoriteTeam.teamId} must belong to following teams.',
    );
  }

  final calendar = response.calendar.map((fixtureResponse) {
    final fixture = fixtureFromApiResponse(fixtureResponse);
    final favoriteIsHome = fixture.homeTeamId == favoriteTeam.teamId;
    final favoriteIsAway = fixture.awayTeamId == favoriteTeam.teamId;
    if (!favoriteIsHome && !favoriteIsAway) {
      throw StateError(
        'Home calendar fixture ${fixture.fixtureId} does not include favorite '
        'team ${favoriteTeam.teamId}.',
      );
    }

    return HomeCalendarFixture(
      fixture: fixture,
      opponent: Team(
        teamId: favoriteIsHome
            ? fixtureResponse.awayTeamId
            : fixtureResponse.homeTeamId,
        name: favoriteIsHome
            ? fixtureResponse.awayTeamName
            : fixtureResponse.homeTeamName,
        shortName: favoriteIsHome
            ? fixtureResponse.awayTeamShortName
            : fixtureResponse.homeTeamShortName,
        imagePath: favoriteIsHome
            ? fixtureResponse.awayTeamLogo
            : fixtureResponse.homeTeamLogo,
      ),
    );
  }).toList(growable: false);

  return HomeData(
    leaguePosition: response.standing?.position,
    leagueRankDelta: response.standing?.rankDelta,
    favoriteTeam: favoriteTeam,
    followingTeams: followingTeams,
    nextMatch: response.nextMatch == null
        ? null
        : fixtureFromApiResponse(response.nextMatch!),
    lastMatch: response.lastMatch == null
        ? null
        : fixtureFromApiResponse(response.lastMatch!),
    calendar: calendar,
    highlights: [
      for (final item in highlightsResponse?.items ?? const [])
        HomeContentItem(
          title: item.title,
          source: item.channelName,
          timeLabel: _relativeTime(item.publishedAt, now: now),
          imageUrl: item.thumbnailUrl,
          destinationUrl: item.videoUrl,
        ),
    ],
  );
}

String _relativeTime(String value, {DateTime? now}) {
  final publishedAt = DateTime.tryParse(value);
  if (publishedAt == null) {
    throw const FormatException('Expected a valid highlight published_at.');
  }
  final difference = (now ?? DateTime.now()).toUtc().difference(
        publishedAt.toUtc(),
      );
  if (difference.isNegative || difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  final local = publishedAt.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}';
}
