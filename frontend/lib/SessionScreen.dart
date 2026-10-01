import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/core/notification_navigation.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/data/home/home_repository_provider.dart'
    as home_provider;
import 'package:onetouch/data/session/session_data_synchronizer.dart';
import 'package:onetouch/data/profile/api/api_current_user_response.dart';
import 'package:onetouch/data/teams/team_page_eligibility.dart';
import 'package:onetouch/features/profile_fields.dart';
import 'package:onetouch/l10n/app_localizations.dart';

String? _readyToken;
bool get isAppSessionReady =>
    _readyToken != null && _readyToken == authSession.accessToken;

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, this.homeRepository});

  final HomeSnapshotRepository? homeRepository;
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
    } catch (error) {
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
    if ([account.username, account.firstName, account.lastName]
        .any((s) => s == null || s.isEmpty)) {
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
    if (!mounted || sessionToken != authSession.accessToken) return;
    _readyToken = sessionToken;
    final destination = notificationNavigation.take(
      sessionToken: sessionToken!,
    );
    context.go(destination ?? '/home');
  }

  @override
  Widget build(BuildContext context) {
    final profile = _incompleteProfile;
    return Scaffold(
        body: SafeArea(
            child: profile != null
                ? ListView(padding: const EdgeInsets.all(24), children: [
                    Text(tr(context, 'Complete your profile')),
                    const SizedBox(height: 24),
                    ProfileFields(
                        username: profile.username,
                        displayName: profile.displayName,
                        firstName: profile.firstName,
                        lastName: profile.lastName,
                        onSaved: _load),
                  ])
                : Center(
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
