import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/models/mock_data.dart';

const _divider = Divider(
  color: Color(0xFF3D3D3D),
  thickness: 2,
  height: 1,
);

/// ============ Screen 1: Notification List ============
class NotificationListPage extends StatefulWidget {
  const NotificationListPage({super.key});

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  static const _currentUserId = 1001;

  bool _postsReactions = true;
  bool _postsComments = true;
  bool _postsFollowing = true;

  bool _bettingNewBets = true;
  bool _bettingPostMatch = true;

  @override
  Widget build(BuildContext context) {
    final teamIds = followingTeamIds(_currentUserId);
    final players = followingPlayersByUser(_currentUserId);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            centerTitle: true,
            automaticallyImplyLeading: false,
            backgroundColor: Colors.black,
            elevation: 0,
            floating: true,
            snap: true,
            toolbarHeight: 80,
            title: const Padding(
              padding: EdgeInsets.only(top: 30),
              child: Text("Notifications", style: Heading4.style),
            ),
            leading: Padding(
              padding: const EdgeInsets.only(top: 30),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: IconButton(
                  onPressed: () => context.push('/search'),
                  icon: const Icon(Icons.search, color: Colors.white),
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
                      final teamName = mockTeamById(entry.value).name;
                      return Column(
                        children: [
                          _listRow(
                            label: teamName,
                            onTap: () => context.push(
                              '/profile/notification/team/${Uri.encodeComponent(teamName)}',
                            ),
                          ),
                          if (i != teamIds.length - 1)
                            const Divider(color: Colors.white24),
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
                            label: player.playerName,
                            onTap: () => context.push(
                              '/profile/notification/player/${Uri.encodeComponent(player.playerName)}',
                            ),
                          ),
                          if (i != players.length - 1)
                            const Divider(color: Colors.white24),
                        ],
                      );
                    }),

                    const SizedBox(height: 48),

                    // Posts
                    const Text("POSTS", style: Body2_b.style),
                    const SizedBox(height: 16),
                    _switchRow(
                      label: 'Reactions',
                      value: _postsReactions,
                      onChanged: (v) => setState(() => _postsReactions = v),
                    ),
                    const Divider(color: Colors.white24),
                    _switchRow(
                      label: 'Comments',
                      value: _postsComments,
                      onChanged: (v) => setState(() => _postsComments = v),
                    ),
                    const Divider(color: Colors.white24),
                    _switchRow(
                      label: 'Following',
                      value: _postsFollowing,
                      onChanged: (v) => setState(() => _postsFollowing = v),
                    ),

                    const SizedBox(height: 48),

                    // Betting
                    const Text("BETTING", style: Body2_b.style),
                    const SizedBox(height: 16),
                    _switchRow(
                      label: 'New bets',
                      value: _bettingNewBets,
                      onChanged: (v) => setState(() => _bettingNewBets = v),
                    ),
                    const Divider(color: Colors.white24),
                    _switchRow(
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
            Text(label, style: Body1.style),
            const Icon(Icons.chevron_right, color: Colors.white),
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
      backgroundColor: Colors.black, // Black Background
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                centerTitle: true,
                automaticallyImplyLeading: false,
                backgroundColor: Colors.black, // Black AppBar
                elevation: 0,
                floating: true,
                snap: true,
                toolbarHeight: 80,
                // FlexibleSpace Removed
                title: Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Text("Notifications", style: Heading4.style),
                ),
                leading: Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: IconButton(
                      onPressed: () => context.push('/search'),
                      icon: const Icon(Icons.search, color: Colors.white),
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
                          label: "All Notifications",
                          value: _allOn,
                          onChanged: _toggleAll,
                        ),
                        _divider,
                        const SizedBox(height: 32),
                        ..._opts.entries.toList().asMap().entries.map((entry) {
                          final i = entry.key;
                          final e = entry.value;
                          return Column(
                            children: [
                              _switchRow(
                                label: e.key,
                                value: e.value,
                                onChanged: (v) =>
                                    setState(() => _opts[e.key] = v),
                              ),
                              if (i != _opts.length - 1)
                                const Divider(color: Colors.white24),
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
                        backgroundColor: const Color(0xFF3D3D3D),
                        foregroundColor: Colors.white,
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
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text("UPDATE NOTIFICATIONS",
                          style: Body2_b.style.copyWith(color: Colors.black)),
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
      backgroundColor: Colors.black, // Black Background
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                centerTitle: true,
                automaticallyImplyLeading: false,
                backgroundColor: Colors.black, // Black AppBar
                elevation: 0,
                floating: true,
                snap: true,
                toolbarHeight: 80,
                // FlexibleSpace Removed
                title: Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Text("Notifications", style: Heading4.style),
                ),
                leading: Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: IconButton(
                      onPressed: () => context.push('/search'),
                      icon: const Icon(Icons.search, color: Colors.white),
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
                          label: "All Notifications",
                          value: _allOn,
                          onChanged: _toggleAll,
                        ),
                        _divider,
                        const SizedBox(height: 24),
                        ..._opts.entries.toList().asMap().entries.map((entry) {
                          final i = entry.key;
                          final e = entry.value;
                          return Column(
                            children: [
                              _switchRow(
                                label: e.key,
                                value: e.value,
                                onChanged: (v) =>
                                    setState(() => _opts[e.key] = v),
                              ),
                              if (i != _opts.length - 1)
                                const Divider(color: Colors.white24),
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
                        backgroundColor: const Color(0xFF3D3D3D),
                        foregroundColor: Colors.white,
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
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text("UPDATE NOTIFICATIONS",
                          style: Body2_b.style.copyWith(color: Colors.black)),
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

Widget _switchRow({
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: Body1.style),
      Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: Colors.green,
        inactiveThumbColor: Colors.white24,
        inactiveTrackColor: Colors.white10,
      ),
    ],
  );
}
