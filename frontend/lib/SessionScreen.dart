import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/profile/api/api_current_user_response.dart';
import 'package:onetouch/data/profile/current_user_repository_provider.dart';
import 'package:onetouch/data/teams/following_teams_repository_provider.dart';
import 'package:onetouch/data/teams/team_page_eligibility.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/features/profile_fields.dart';

String? _readyToken;
bool get isAppSessionReady =>
    _readyToken != null && _readyToken == authSession.accessToken;

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});
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
      await footballCatalog.initialize();
      final account = await currentUserRepository.loadAccount();
      if (!mounted) return;
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
      final teams = await followingTeamsRepository.load();
      currentUserPreferences.applyServerSelection(UserTeamPreferences(
          favoriteTeamId: account.favoriteTeamId!,
          followedTeamIds: teams.map((t) => t.teamId).toList()));
      await playerFollowingController.load();
      _readyToken = authSession.accessToken;
      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _incompleteProfile;
    return Scaffold(
        body: SafeArea(
            child: profile != null
                ? ListView(padding: const EdgeInsets.all(24), children: [
                    const Text('Complete your profile'),
                    const SizedBox(height: 24),
                    ProfileFields(
                        username: profile.username,
                        firstName: profile.firstName,
                        lastName: profile.lastName,
                        onSaved: _load),
                  ])
                : Center(
                    child: _error == null
                        ? const CircularProgressIndicator()
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            const Text(
                                'Unable to load your account. Please try again.'),
                            TextButton(
                                onPressed: _load, child: const Text('Retry')),
                          ]))));
  }
}
