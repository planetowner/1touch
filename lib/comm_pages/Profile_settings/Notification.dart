import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

/// Common header wrapper - Gradient removed
class _GradientHeader extends StatelessWidget {
  const _GradientHeader();

  @override
  Widget build(BuildContext context) {
    // Just an empty placeholder or background since scaffold is black
    return const SizedBox.shrink();
  }
}

const _divider = Divider(
  color: Color(0xFF3D3D3D), // 시안과 동일
  thickness: 2,
  height: 1,
);

/// ============ Screen 1: Notification List ============
class NotificationListPage extends StatelessWidget {
  const NotificationListPage({super.key});

  final List<String> teams = const [
    "FC Barcelona",
    "Bayern Munich",
    "Inter Milan",
    "Paris Saint-Germain",
    "Manchester City",
  ];

  final List<String> players = const [
    "Heungmin Son",
    "Kangin Lee",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.black, // Background Black
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
                    padding: EdgeInsets.only(top: 30),
                    child: Text(
                      "Notifications",
                      style: Heading4.style,
                    ),
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
                    Container(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "FOLLOWING TEAMS",
                            style: Body2_b.style,
                          ),
                          const SizedBox(height: 16),
                          ...teams.asMap().entries.map((entry) {
                            final i = entry.key;
                            final t = entry.value;
                            return Column(
                              children: [
                                _listRow(
                                  label: t,
                                  onTap: () => context.push(
                                    '/profile/notification/team/${Uri.encodeComponent(t)}',
                                  ),
                                ),
                                if (i != teams.length - 1)
                                  const Divider(color: Colors.white24),
                              ],
                            );
                          }),
                          const SizedBox(height: 48),
                          Text(
                            "FOLLOWING PLAYERS",
                            style: Body2_b.style,
                          ),
                          const SizedBox(height: 16),
                          ...players.asMap().entries.map((entry) {
                            final i = entry.key;
                            final p = entry.value;
                            return Column(
                              children: [
                                _listRow(
                                  label: p,
                                  onTap: () => context.push(
                                    '/profile/notification/player/${Uri.encodeComponent(p)}',
                                  ),
                                ),
                                if (i != players.length - 1)
                                  const Divider(color: Colors.white24),
                              ],
                            );
                          }),
                          const SizedBox(height: 120),
                        ],
                      ),
                    )
                  ]),
                )
              ],
            ),
          ],
        )
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
            Text(label,
                style: Body1.style),
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
  State<TeamNotificationDetailPage> createState() => _TeamNotificationDetailPageState();
}

class _TeamNotificationDetailPageState extends State<TeamNotificationDetailPage> {
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
                        Text(widget.teamName.toUpperCase(), style: Body2_b.style),
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
                        const SizedBox(height: 120), // space above bottom button
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ),
          // Bottom fixed button
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: persist to backend
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text("UPDATE NOTIFICATIONS", style: Body2_b.style.copyWith(color: Colors.black)),
                ),
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
  State<PlayerNotificationDetailPage> createState() => _PlayerNotificationDetailPageState();
}

class _PlayerNotificationDetailPageState extends State<PlayerNotificationDetailPage> {
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
                        Text(widget.playerName.toUpperCase(), style: Body2_b.style),
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
                        const SizedBox(height: 120),
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
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: persist to backend
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text("UPDATE NOTIFICATIONS", style: Body2_b.style.copyWith(color: Colors.black)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============ 공통 스위치/버튼 UI ============

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
        activeColor: Colors.white,      // thumb
        activeTrackColor: Colors.green, // track
        inactiveThumbColor: Colors.white24,
        inactiveTrackColor: Colors.white10,
      ),
    ],
  );
}

Widget _masterSwitchRow({
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return _switchRow(label: label, value: value, onChanged: onChanged);
}