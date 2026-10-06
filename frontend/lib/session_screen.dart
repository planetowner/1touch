import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/core/notification_navigation.dart';
import 'package:onetouch/core/community_link_navigation.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/data/home/home_repository_provider.dart'
    as home_provider;
import 'package:onetouch/data/players/player_directory_repository.dart';
import 'package:onetouch/data/posts/api/api_post_repository.dart';
import 'package:onetouch/data/posts/post_repository_provider.dart';
import 'package:onetouch/data/seasons/season_repository_provider.dart';
import 'package:onetouch/data/session/session_data_synchronizer.dart';
import 'package:onetouch/data/standings/api/api_standing_repository.dart';
import 'package:onetouch/data/standings/api_standing_repository_provider.dart';
import 'package:onetouch/data/team_overview/api/api_team_overview_repository.dart';
import 'package:onetouch/data/team_overview/team_overview_repository_provider.dart';
import 'package:onetouch/data/profile/api/api_current_user_response.dart';
import 'package:onetouch/data/teams/team_page_eligibility.dart';
import 'package:onetouch/SignComps/social_profile_setup.dart';
import 'package:onetouch/data/auth/auth_repository_provider.dart'
    as auth_provider;
import 'package:onetouch/data/auth/registration_field.dart';
import 'package:onetouch/data/profile/current_user_repository_provider.dart';
import 'package:onetouch/debug/mock_betting_match.dart';
import 'package:onetouch/l10n/app_localizations.dart';

String? _readyToken;
bool get isAppSessionReady =>
    _readyToken != null && _readyToken == authSession.accessToken;

@visibleForTesting
String resolveSessionReadyDestination({
  String? communityDestination,
  String? notificationDestination,
  bool bettingDebugEnabled = mockBettingMatchEnabled,
}) {
  if (bettingDebugEnabled) return '/debug/betting';
  return communityDestination ?? notificationDestination ?? '/home';
}

/// Promote the selected team's disk snapshots before its screens build.
/// No API call is started here; the screens own TTL revalidation on entry.
Future<void> restoreSelectedTeamCaches(int teamId) async {
  final overviewRepository = teamOverviewRepository;
  final standingRepository = apiStandingRepository;
  final tasks = <Future<void>>[];
  if (overviewRepository is ApiTeamOverviewRepository) {
    tasks.add(overviewRepository.restoreCachedForTeam(teamId).then((_) {}));
  }
  final directoryRepository = playerDirectoryRepository;
  if (directoryRepository is ApiPlayerDirectoryRepository) {
    tasks.add(directoryRepository.restoreCachedRanking().then((_) {}));
    tasks.add(directoryRepository.restoreCachedWatch().then((_) {}));
  }
  final communityRepository = postRepository;
  if (communityRepository is ApiPostRepository) {
    tasks.add(
        communityRepository.restoreCachedFeed(teamId: teamId).then((_) {}));
  }
  if (standingRepository is ApiStandingRepository) {
    const bigFiveIds = {8, 82, 301, 384, 564};
    final competitions = footballCatalog.memberships
        .where((membership) => membership.teamId == teamId)
        .map((membership) => membership.competitionId)
        .toSet()
        .toList()
      ..sort((a, b) => (bigFiveIds.contains(a) ? 0 : 1)
          .compareTo(bigFiveIds.contains(b) ? 0 : 1));
    if (competitions.isNotEmpty) {
      final competitionId = competitions.first;
      final seasons = seasonRepository.forCompetition(competitionId);
      final season = seasonRepository.currentForCompetition(competitionId) ??
          (seasons.isNotEmpty ? seasons.first : null);
      if (season != null) {
        tasks.add(standingRepository
            .restoreCachedForCompetition(
              competitionId,
              seasonId: season.seasonId,
            )
            .then((_) {}));
      }
    }
  }
  await Future.wait(tasks.map((task) async {
    try {
      await task;
    } on Object {
      // Local cache availability must not prevent navigation.
    }
  }));
}

class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    this.homeRepository,
    this.checkNicknameAvailability,
    this.logout,
  });

  final HomeSnapshotRepository? homeRepository;
  final Future<bool> Function(String)? checkNicknameAvailability;
  final Future<void> Function()? logout;
  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  Object? _error;
  ApiCurrentUserResponse? _incompleteProfile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _incompleteProfile = null;
    });
    try {
      if (!authSession.isAuthenticated) {
        if (mounted) context.go('/onboarding');
        return;
      }
      final cached = await sessionDataSynchronizer.hydrate();
      if (!mounted) return;
      if (cached?.canOpenHome == true) {
        await _openHome();
        if (mounted && isAppSessionReady) {
          unawaited(_refreshCachedSession());
        }
        return;
      }
      final fresh = await sessionDataSynchronizer.synchronize(
        trigger: CacheSyncTrigger.bootstrap,
      );
      if (!mounted) return;
      await _handle(fresh);
    } catch (error, stackTrace) {
      // 서버 응답이 정상이어도 앱 내부 처리에서 실패할 수 있어 발생 위치를 남겨요.
      if (kDebugMode) {
        debugPrint('Session loading failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _refreshCachedSession() async {
    try {
      await sessionDataSynchronizer.synchronize(
        trigger: CacheSyncTrigger.bootstrap,
      );
    } on Object {
      // Cached session data remains usable while the device is offline.
    }
  }

  Future<void> _handle(SessionDataSnapshot snapshot) async {
    final account = snapshot.account;
    if (account.email == null && !account.profileComplete) {
      setState(() => _incompleteProfile = account);
      return;
    }
    if (!account.onboardingComplete) {
      if (!footballCatalog.competitions.value.any((c) =>
          TeamPageEligibility.domesticBigFiveCompetitionIds
              .contains(c.competitionId) &&
          footballCatalog.currentTeams(c.competitionId).isNotEmpty)) {
        throw StateError('No current team memberships available.');
      }
      context.go('/onboarding/welcome');
      return;
    }
    if (!snapshot.canOpenHome) {
      throw StateError('Complete session data is unavailable.');
    }
    await _openHome();
  }

  Future<void> _openHome() async {
    final sessionToken = authSession.accessToken;
    // 새 로그인에서는 이전 계정의 탐색 팀을 이어받지 않아요.
    if (_readyToken != sessionToken) {
      currentUserPreferences.resetViewedTeam();
    }
    final repository = widget.homeRepository ?? home_provider.homeRepository;
    if (repository is HomeSnapshotRepository) {
      final now = DateTime.now();
      try {
        await repository.restoreFor(
          teamId: currentUserPreferences.viewedTeamId.value,
          month: DateTime(now.year, now.month),
        );
      } on Object {
        // Local storage is optional; an unreadable cache must not block Home.
      }
    }
    await restoreSelectedTeamCaches(currentUserPreferences.viewedTeamId.value);
    if (!mounted || sessionToken != authSession.accessToken) return;
    _readyToken = sessionToken;
    final communityDestination = communityLinkNavigation.take(
      sessionToken: sessionToken!,
    );
    final notificationDestination = notificationNavigation.take(
      sessionToken: sessionToken,
    );
    context.go(resolveSessionReadyDestination(
      communityDestination: communityDestination,
      notificationDestination: notificationDestination,
    ));
  }

  Future<void> _leaveSocialSetup() async {
    await (widget.logout ?? auth_provider.authService.logout)();
    if (mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final profile = _incompleteProfile;
    if (profile != null) {
      return SocialProfileSetup(
        initialNickname: profile.displayName,
        checkNicknameAvailability: widget.checkNicknameAvailability ??
            (value) => auth_provider.authService.isRegistrationValueAvailable(
                  field: RegistrationField.displayName,
                  value: value,
                ),
        onContinue: (nickname) async {
          await currentUserRepository.updateProfile(
            displayName: nickname,
          );
          await _load();
        },
        onBack: _leaveSocialSetup,
      );
    }
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: _error == null
                    ? const FootballLoadingIndicator()
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(tr(context,
                            'Unable to load your account. Please try again.')),
                        TextButton(
                            onPressed: _load,
                            child: Text(tr(context, 'Retry'))),
                      ]))));
  }
}
