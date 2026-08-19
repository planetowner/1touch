import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/players/player_repository_provider.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';

Widget _divider(BuildContext context, {double thickness = 1}) => Divider(
      color: AppColors.of(context).divider,
      thickness: thickness,
      height: 1,
    );

/// ============ Screen 1: Notification List ============
class NotificationListPage extends StatefulWidget {
  const NotificationListPage({super.key});

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  bool _postsReactions = true;
  bool _postsComments = true;
  bool _postsFollowing = true;

  bool _bettingNewBets = true;
  bool _bettingPostMatch = true;

  @override
  Widget build(BuildContext context) {
    final teamIds = currentUserPreferences.followedTeamIds.value;
    final players = playerRepository.favorites;

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
            title: const Padding(
              padding: EdgeInsets.only(top: 30),
              child: Text("Notifications", style: Body1.style),
            ),
            leading: Padding(
              padding: const EdgeInsets.only(top: 30),
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: IconButton(
                  onPressed: () => context.push('/search'),
                  icon: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
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
                    const Text("FOLLOWING TEAMS", style: Body2_b.style),
                    const SizedBox(height: 16),
                    ...teamIds.asMap().entries.map((entry) {
                      final i = entry.key;
                      final teamName =
                          teamRepository.requireById(entry.value).name;
                      return Column(
                        children: [
                          _listRow(
                            label: teamName,
                            onTap: () => context.push(
                              '/profile/notification/team/${Uri.encodeComponent(teamName)}',
                            ),
                          ),
                          if (i != teamIds.length - 1) _divider(context),
                        ],
                      );
                    }),

                    const SizedBox(height: 48),

                    // Following Players
                    const Text("FOLLOWING PLAYERS", style: Body2_b.style),
                    const SizedBox(height: 16),
                    ...players.asMap().entries.map((entry) {
                      final i = entry.key;
                      final player = entry.value;
                      return Column(
                        children: [
                          _listRow(
                            label: player.fullName,
                            onTap: () => context.push(
                              '/profile/notification/player/${Uri.encodeComponent(player.fullName)}',
                            ),
                          ),
                          if (i != players.length - 1) _divider(context),
                        ],
                      );
                    }),

                    const SizedBox(height: 48),

                    // Posts
                    const Text("POSTS", style: Body2_b.style),
                    const SizedBox(height: 16),
                    _switchRow(
                      context,
                      label: 'Reactions',
                      value: _postsReactions,
                      onChanged: (v) => setState(() => _postsReactions = v),
                    ),
                    _divider(context),
                    _switchRow(
                      context,
                      label: 'Comments',
                      value: _postsComments,
                      onChanged: (v) => setState(() => _postsComments = v),
                    ),
                    _divider(context),
                    _switchRow(
                      context,
                      label: 'Following',
                      value: _postsFollowing,
                      onChanged: (v) => setState(() => _postsFollowing = v),
                    ),

                    const SizedBox(height: 48),

                    // Betting
                    const Text("BETTING", style: Body2_b.style),
                    const SizedBox(height: 16),
                    _switchRow(
                      context,
                      label: 'New bets',
                      value: _bettingNewBets,
                      onChanged: (v) => setState(() => _bettingNewBets = v),
                    ),
                    _divider(context),
                    _switchRow(
                      context,
                      label: 'Post-match results',
                      value: _bettingPostMatch,
                      onChanged: (v) => setState(() => _bettingPostMatch = v),
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

  static Widget _listRow({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
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

// ===================== TEAM DETAIL =====================
class TeamNotificationDetailPage extends StatefulWidget {
  final String teamName;
  const TeamNotificationDetailPage({super.key, required this.teamName});

  @override
  State<TeamNotificationDetailPage> createState() =>
      _TeamNotificationDetailPageState();
}

class _TeamNotificationDetailPageState
    extends State<TeamNotificationDetailPage> {
  final Map<String, bool> _opts = {
    "News": true,
    "Match Reminder": false,
    "Kickoff, Half Time, Full Time": true,
    "Goal": true,
    "Substitution": false,
  };

  bool get _allOn => _opts.values.every((v) => v);
  void _toggleAll(bool v) {
    setState(() {
      for (final k in _opts.keys) {
        _opts[k] = v;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                title: Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Text("Notifications", style: Body1.style),
                ),
                leading: Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: IconButton(
                      onPressed: () => context.push('/search'),
                      icon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
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
                        Text(widget.teamName.toUpperCase(),
                            style: Body2_b.style),
                        const SizedBox(height: 24),
                        _switchRow(
                          context,
                          label: "All Notifications",
                          value: _allOn,
                          onChanged: _toggleAll,
                        ),
                        _divider(context, thickness: 2),
                        const SizedBox(height: 32),
                        ..._opts.entries.toList().asMap().entries.map((entry) {
                          final i = entry.key;
                          final e = entry.value;
                          return Column(
                            children: [
                              _switchRow(
                                context,
                                label: e.key,
                                value: e.value,
                                onChanged: (v) =>
                                    setState(() => _opts[e.key] = v),
                              ),
                              if (i != _opts.length - 1) _divider(context),
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
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Applied to all following teams'),
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
                      child: Text("APPLY TO ALL TEAMS", style: Body2_b.style),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
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
                        "UPDATE NOTIFICATIONS",
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

// ===================== PLAYER DETAIL =====================
class PlayerNotificationDetailPage extends StatefulWidget {
  final String playerName;
  const PlayerNotificationDetailPage({super.key, required this.playerName});

  @override
  State<PlayerNotificationDetailPage> createState() =>
      _PlayerNotificationDetailPageState();
}

class _PlayerNotificationDetailPageState
    extends State<PlayerNotificationDetailPage> {
  final Map<String, bool> _opts = {
    "Starting / Substitute": true,
    "Goal": true,
    "Assist": true,
    "Yellow Card": false,
    "Red Card": false,
    "Injury": false,
  };

  bool get _allOn => _opts.values.every((v) => v);
  void _toggleAll(bool v) {
    setState(() {
      for (final k in _opts.keys) {
        _opts[k] = v;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                title: Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Text("Notifications", style: Body1.style),
                ),
                leading: Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: IconButton(
                      onPressed: () => context.push('/search'),
                      icon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
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
                        Text(widget.playerName.toUpperCase(),
                            style: Body2_b.style),
                        const SizedBox(height: 24),
                        _switchRow(
                          context,
                          label: "All Notifications",
                          value: _allOn,
                          onChanged: _toggleAll,
                        ),
                        _divider(context, thickness: 2),
                        const SizedBox(height: 24),
                        ..._opts.entries.toList().asMap().entries.map((entry) {
                          final i = entry.key;
                          final e = entry.value;
                          return Column(
                            children: [
                              _switchRow(
                                context,
                                label: e.key,
                                value: e.value,
                                onChanged: (v) =>
                                    setState(() => _opts[e.key] = v),
                              ),
                              if (i != _opts.length - 1) _divider(context),
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
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Applied to all following players'),
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
                      child: Text("APPLY TO ALL PLAYERS", style: Body2_b.style),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
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
                        "UPDATE NOTIFICATIONS",
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

/// ============ 공통 스위치 UI ============

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
          label,
          style: Body1.style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: 8),
      Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: Colors.green,
        inactiveThumbColor: AppPalette.white,
        inactiveTrackColor: AppPalette.lightGrey,
      ),
    ],
  );
}
