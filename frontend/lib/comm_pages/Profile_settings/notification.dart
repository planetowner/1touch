import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/data/notifications/notification_preferences.dart';
import 'package:onetouch/data/notifications/notification_preferences_repository.dart';
import 'package:onetouch/data/notifications/notification_preferences_repository_provider.dart';
import 'package:onetouch/services/push_device_registration_service_provider.dart';

Widget _divider(BuildContext context, {double thickness = 1}) => Divider(
      color: AppColors.of(context).divider,
      thickness: thickness,
      height: 1,
    );

Future<void> _requestDeviceNotificationPermission(bool needed) async {
  if (!needed) return;
  try {
    await pushDeviceRegistrationService.requestPermissionAndRegister();
  } on Object catch (error) {
    debugPrint('Unable to request notification permission: $error');
  }
}

///  Screen 1: Notification List
class NotificationListPage extends StatefulWidget {
  const NotificationListPage({super.key, this.repository});

  final NotificationPreferencesRepository? repository;

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  GlobalNotificationPreferences _preferences =
      const GlobalNotificationPreferences();
  bool _newBets = true;

  NotificationPreferencesRepository get _repository =>
      widget.repository ?? notificationPreferencesRepository;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final snapshot = await _repository.load();
    if (!mounted) return;
    setState(() {
      _preferences = snapshot.global;
      _newBets = snapshot.teams.values.every((team) => team.newBets);
    });
  }

  void _update(GlobalNotificationPreferences preferences, bool enabled) {
    setState(() => _preferences = preferences);
    unawaited(_save(preferences, requestPermission: enabled));
  }

  Future<void> _save(
    GlobalNotificationPreferences preferences, {
    required bool requestPermission,
  }) async {
    await _repository.saveGlobal(preferences);
    await _requestDeviceNotificationPermission(requestPermission);
  }

  void _updateNewBets(bool enabled) {
    setState(() => _newBets = enabled);
    unawaited(_saveNewBets(enabled));
  }

  Future<void> _saveNewBets(bool enabled) async {
    await _repository.applyNewBetsToAll(
      currentUserPreferences.followedTeamIds.value,
      enabled,
    );
    await _requestDeviceNotificationPermission(enabled);
  }

  @override
  Widget build(BuildContext context) {
    final teamIds = currentUserPreferences.followedTeamIds.value;
    final players = playerFollowingController.players;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.of(context).pageBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            centerTitle: true,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.of(context).pageBackground,
            elevation: 0,
            floating: true,
            snap: true,
            toolbarHeight: 80,
            title: Text(tr(context, "Notifications"), style: Body1.style),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                onPressed: () => context.push('/search'),
                icon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Following Teams
                    Text(trUpper(context, "Following Teams"),
                        style: Body2_b.style),
                    const SizedBox(height: 16),
                    ...teamIds.asMap().entries.map((entry) {
                      final i = entry.key;
                      final teamName =
                          teamRepository.requireById(entry.value).name;
                      return Column(
                        children: [
                          _listRow(
                            label:
                                teamNameLabel(context, entry.value, teamName),
                            onTap: () => context.push(
                              '/profile/notification/team/${Uri.encodeComponent(teamName)}?id=${entry.value}',
                            ),
                          ),
                          if (i != teamIds.length - 1) _divider(context),
                        ],
                      );
                    }),

                    if (players.isNotEmpty) ...[
                      const SizedBox(height: 48),

                      // Following Players
                      Text(
                        trUpper(context, "Following Players"),
                        style: Body2_b.style,
                      ),
                      const SizedBox(height: 16),
                      ...players.asMap().entries.map((entry) {
                        final i = entry.key;
                        final player = entry.value;
                        return Column(
                          children: [
                            _listRow(
                              label: playerNameLabel(
                                context,
                                player.playerId,
                                player.name,
                              ),
                              onTap: () => context.push(
                                '/profile/notification/player/${Uri.encodeComponent(player.name)}?id=${player.playerId}',
                              ),
                            ),
                            if (i != players.length - 1) _divider(context),
                          ],
                        );
                      }),
                    ],

                    const SizedBox(height: 48),

                    // Posts
                    Text(tr(context, "POSTS"), style: Body2_b.style),
                    const SizedBox(height: 16),
                    _switchRow(
                      context,
                      label: tr(context, 'Reactions'),
                      value: _preferences.postReactions,
                      onChanged: (value) => _update(
                        _preferences.copyWith(postReactions: value),
                        value,
                      ),
                    ),
                    _divider(context),
                    _switchRow(
                      context,
                      label: tr(context, 'Comments'),
                      value: _preferences.postComments,
                      onChanged: (value) => _update(
                        _preferences.copyWith(postComments: value),
                        value,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Betting
                    Text(trUpper(context, "Bets"), style: Body2_b.style),
                    const SizedBox(height: 16),
                    _switchRow(
                      context,
                      label: tr(context, 'New bets'),
                      value: _newBets,
                      onChanged: _updateNewBets,
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _listRow({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                tr(context, label),
                style: Body1.style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

//  TEAM DETAIL
class TeamNotificationDetailPage extends StatefulWidget {
  final String teamName;
  final int? teamId;
  final NotificationPreferencesRepository? repository;
  const TeamNotificationDetailPage(
      {super.key, required this.teamName, this.teamId, this.repository});

  @override
  State<TeamNotificationDetailPage> createState() =>
      _TeamNotificationDetailPageState();
}

class _TeamNotificationDetailPageState
    extends State<TeamNotificationDetailPage> {
  TeamNotificationPreferences _preferences =
      const TeamNotificationPreferences();

  NotificationPreferencesRepository get _repository =>
      widget.repository ?? notificationPreferencesRepository;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final teamId = widget.teamId;
    if (teamId == null) return;
    final preferences = (await _repository.load()).team(teamId);
    if (!mounted) return;
    setState(() => _apply(preferences));
  }

  void _apply(TeamNotificationPreferences preferences) {
    _preferences = preferences;
  }

  bool get _allOn => _preferences.copyWith(newBets: true).allEnabled;

  void _toggleAll(bool v) {
    final newBets = _preferences.newBets;
    setState(
      () => _preferences = _preferences.setAll(v).copyWith(newBets: newBets),
    );
  }

  Future<void> _save({required bool applyToAll}) async {
    if (applyToAll) {
      await _repository.applyTeamToAll(
        currentUserPreferences.followedTeamIds.value,
        _preferences,
      );
    } else if (widget.teamId case final int teamId) {
      await _repository.saveTeam(teamId, _preferences);
    }
    await _requestDeviceNotificationPermission(
      [
        _preferences.matchReminder,
        _preferences.kickoff,
        _preferences.halfTime,
        _preferences.fullTime,
        _preferences.goal,
        _preferences.substitution,
      ].any((enabled) => enabled),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        'Match Reminder',
        _preferences.matchReminder,
        (bool value) => _preferences.copyWith(matchReminder: value),
      ),
      (
        'Kickoff, Half Time, Full Time',
        _preferences.kickoff && _preferences.halfTime && _preferences.fullTime,
        (bool value) => _preferences.copyWith(
              kickoff: value,
              halfTime: value,
              fullTime: value,
            ),
      ),
      (
        'Goal',
        _preferences.goal,
        (bool value) => _preferences.copyWith(goal: value),
      ),
      (
        'Substitution',
        _preferences.substitution,
        (bool value) => _preferences.copyWith(substitution: value),
      ),
    ];
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.of(context).pageBackground,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                centerTitle: true,
                automaticallyImplyLeading: false,
                backgroundColor: AppColors.of(context).pageBackground,
                elevation: 0,
                floating: true,
                snap: true,
                toolbarHeight: 80,
                // FlexibleSpace Removed
                title: Text(tr(context, "Notifications"), style: Body1.style),
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  IconButton(
                    onPressed: () => context.push('/search'),
                    icon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            teamNameLabel(
                                    context, widget.teamId, widget.teamName)
                                .toUpperCase(),
                            style: Body2_b.style),
                        const SizedBox(height: 24),
                        _switchRow(
                          context,
                          label: tr(context, "All Notifications"),
                          value: _allOn,
                          onChanged: _toggleAll,
                        ),
                        _divider(context, thickness: 2),
                        const SizedBox(height: 32),
                        ...options.asMap().entries.map((entry) {
                          final (label, value, update) = entry.value;
                          return Column(
                            children: [
                              _switchRow(
                                context,
                                label: label,
                                value: value,
                                onChanged: (value) => setState(
                                  () => _preferences = update(value),
                                ),
                              ),
                              if (entry.key < options.length - 1)
                                _divider(context),
                            ],
                          );
                        }),
                        const SizedBox(height: 170),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ),
          // Bottom fixed buttons
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _save(applyToAll: true);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                tr(context, 'Applied to all following teams')),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? AppPalette.lightGrey
                                : AppColors.of(context).subtleBackground,
                        foregroundColor:
                            Theme.of(context).colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(tr(context, "APPLY TO ALL TEAMS"),
                          style: Body2_b.style),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _save(applyToAll: false);
                        if (context.mounted) context.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.onSurface,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        tr(context, "UPDATE NOTIFICATIONS"),
                        style: Body2_b.style.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//  PLAYER DETAIL
class PlayerNotificationDetailPage extends StatefulWidget {
  final String playerName;
  final int? playerId;
  final NotificationPreferencesRepository? repository;
  const PlayerNotificationDetailPage(
      {super.key, required this.playerName, this.playerId, this.repository});

  @override
  State<PlayerNotificationDetailPage> createState() =>
      _PlayerNotificationDetailPageState();
}

class _PlayerNotificationDetailPageState
    extends State<PlayerNotificationDetailPage> {
  PlayerNotificationPreferences _preferences =
      const PlayerNotificationPreferences();

  NotificationPreferencesRepository get _repository =>
      widget.repository ?? notificationPreferencesRepository;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final playerId = widget.playerId;
    if (playerId == null) return;
    final preferences = (await _repository.load()).player(playerId);
    if (!mounted) return;
    setState(() => _apply(preferences));
  }

  void _apply(PlayerNotificationPreferences preferences) {
    _preferences = preferences;
  }

  bool get _allOn => _preferences.allEnabled;

  void _toggleAll(bool v) {
    setState(() => _preferences = _preferences.setAll(v));
  }

  Future<void> _save({required bool applyToAll}) async {
    if (applyToAll) {
      await _repository.applyPlayerToAll(
        playerFollowingController.players.map((player) => player.playerId),
        _preferences,
      );
    } else if (widget.playerId case final int playerId) {
      await _repository.savePlayer(playerId, _preferences);
    }
    await _requestDeviceNotificationPermission(
      [
        _preferences.startingXi,
        _preferences.substitute,
        _preferences.goal,
        _preferences.assist,
        _preferences.yellowCard,
        _preferences.redCard,
        _preferences.injury,
      ].any((enabled) => enabled),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        'Starting / Substitute',
        _preferences.startingXi && _preferences.substitute,
        (bool value) => _preferences.copyWith(
              startingXi: value,
              substitute: value,
            ),
      ),
      (
        'Goal',
        _preferences.goal,
        (bool value) => _preferences.copyWith(goal: value),
      ),
      (
        'Assist',
        _preferences.assist,
        (bool value) => _preferences.copyWith(assist: value),
      ),
      (
        'Yellow Card',
        _preferences.yellowCard,
        (bool value) => _preferences.copyWith(yellowCard: value),
      ),
      (
        'Red Card',
        _preferences.redCard,
        (bool value) => _preferences.copyWith(redCard: value),
      ),
      (
        'Injury',
        _preferences.injury,
        (bool value) => _preferences.copyWith(injury: value),
      ),
    ];
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.of(context).pageBackground,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                centerTitle: true,
                automaticallyImplyLeading: false,
                backgroundColor: AppColors.of(context).pageBackground,
                elevation: 0,
                floating: true,
                snap: true,
                toolbarHeight: 80,
                // FlexibleSpace Removed
                title: Text(tr(context, "Notifications"), style: Body1.style),
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  IconButton(
                    onPressed: () => context.push('/search'),
                    icon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            playerNameLabel(
                                    context, widget.playerId, widget.playerName)
                                .toUpperCase(),
                            style: Body2_b.style),
                        const SizedBox(height: 24),
                        _switchRow(
                          context,
                          label: tr(context, "All Notifications"),
                          value: _allOn,
                          onChanged: _toggleAll,
                        ),
                        _divider(context, thickness: 2),
                        const SizedBox(height: 24),
                        ...options.asMap().entries.map((entry) {
                          final (label, value, update) = entry.value;
                          return Column(
                            children: [
                              _switchRow(
                                context,
                                label: label,
                                value: value,
                                onChanged: (value) => setState(
                                  () => _preferences = update(value),
                                ),
                              ),
                              if (entry.key < options.length - 1)
                                _divider(context),
                            ],
                          );
                        }),
                        const SizedBox(height: 170),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _save(applyToAll: true);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tr(
                                context, 'Applied to all following players')),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? AppPalette.lightGrey
                                : AppColors.of(context).subtleBackground,
                        foregroundColor:
                            Theme.of(context).colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(tr(context, "APPLY TO ALL PLAYERS"),
                          style: Body2_b.style),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _save(applyToAll: false);
                        if (context.mounted) context.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.onSurface,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        tr(context, "UPDATE NOTIFICATIONS"),
                        style: Body2_b.style.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

///  공통 스위치 UI

Widget _switchRow(
  BuildContext context, {
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Text(
          tr(context, label),
          style: Body1.style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: 8),
      Switch.adaptive(
        value: value,
        onChanged: onChanged,
      ),
    ],
  );
}
