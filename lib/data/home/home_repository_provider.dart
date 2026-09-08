import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart';
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/data/home/mock/mock_home_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';

final HomeRepository homeRepository = MockHomeRepository(
  teamRepository: teamRepository,
  fixtureRepository: fixtureRepository,
  favoriteTeamId: () => currentUserPreferences.favoriteTeamId.value,
  followedTeamIds: () => currentUserPreferences.followedTeamIds.value,
);
