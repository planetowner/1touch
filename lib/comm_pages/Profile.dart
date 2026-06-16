import "package:flutter/material.dart";
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/comm_pages/Profile_settings/TeamEdit.dart';
import 'package:onetouch/comm_pages/Profile_settings/PlayerEdit.dart';
import 'package:onetouch/models/mock_data.dart';
import 'package:onetouch/models/user.dart';
import 'package:onetouch/models/user_profile.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  static const _currentUserId = 1001;

  late ScrollController _scrollController;
  double _scrollOffset = 0.0;
  Color _teamColor = const Color(0xFFD82457);
  late User _user;
  late UserProfile _userProfile;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });

    _user        = mockUserById(_currentUserId);
    _userProfile = mockUserProfileById(_currentUserId);

    final favoriteTeamId = _userProfile.favoriteTeamId;
    if (favoriteTeamId != null) {
      _teamColor = Color(mockTeamById(favoriteTeamId).primaryColor);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Logic copied from HomeScreen to fade out the gradient
    double opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          const Color(0xFF0E0E0E), // Dark background behind the gradient
      body: Stack(
        children: [
          // Background Gradient with AnimatedOpacity
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 550,
            child: AnimatedOpacity(
              opacity: (1 - opacityFactor), // Fades out as you scroll down
              duration:
                  const Duration(milliseconds: 0), // Instant update with scroll
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_teamColor, _teamColor.withAlpha(0)],
                    stops: const [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                automaticallyImplyLeading: false,
                // App bar becomes dark as you scroll down
                backgroundColor: Color.lerp(
                    Colors.transparent, const Color(0xFF0E0E0E), opacityFactor),
                elevation: 0,
                floating: true,
                snap: true,
                toolbarHeight: 80,
                centerTitle: false,
                titleSpacing: 0,
                clipBehavior: Clip.antiAlias,
                title: Padding(
                  padding: const EdgeInsets.only(left: 24, top: 30),
                  child: SvgPicture.asset(
                    'assets/app_logo.svg',
                    height: 23,
                    width: 120,
                    clipBehavior: Clip.antiAlias,
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 30),
                    child: Row(
                      children: [
                        // Bell icon with unread badge
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              onPressed: () => context.push('/notifications'),
                              icon: const Icon(Icons.notifications_none_rounded,
                                  size: 32, color: Colors.white),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD82457),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => context.push('/search'),
                          icon: const Icon(Icons.search,
                              size: 32, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 48),
                  _buildProfileHeader(context),
                  const SizedBox(height: 48),
                  _buildStatRow(),
                  const SizedBox(height: 48),

                  // FOLLOWING TEAMS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "FOLLOWING TEAMS",
                          style: Body2_b.style,
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: Colors.white, size: 20),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) =>
                                  const EditFollowingTeamsSheet(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTeamList(),
                  const SizedBox(height: 48),

                  // FOLLOWING PLAYERS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "FOLLOWING PLAYERS",
                          style: Body2_b.style,
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: Colors.white, size: 20),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) =>
                                  const EditFollowingPlayersSheet(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPlayerList(),
                  const SizedBox(height: 48),

                  _buildSectionLabel("SETTINGS"),
                  const SizedBox(height: 16),
                  const SettingsList(),
                  const SizedBox(height: 48),
                ]),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              context.push('/profile/edit');
            },
            child: CircleAvatar(
              radius: 54,
              backgroundColor: const Color(0xFF3D3D3D),
              backgroundImage: AssetImage(
                _user.avatarAsset ?? 'assets/profileavatar.png',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(_user.displayName, style: Heading5.style),
          Opacity(
            opacity: 0.5,
            child: Text(_user.email, style: Body2.style),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFF2B2B2B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildStat(_userProfile.pts.toString(), "PTS"),
            _verticalDivider(),
            _buildStat(_userProfile.postCount.toString(), "POSTS"),
            _verticalDivider(),
            _buildStat(_userProfile.commentCount.toString(), "COMMENTS"),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Heading4.style),
            const SizedBox(height: 4),
            Text(label, style: Body2_b.style),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white24,
    );
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(title, style: Body2_b.style),
    );
  }

  Widget _buildTeamList() {
    final teamIds  = followingTeamIds(_currentUserId);
    final favoriteId = _userProfile.favoriteTeamId;

    return SizedBox(
      height: 165,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: teamIds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final team       = mockTeamById(teamIds[index]);
          final isFavorite = team.teamId == favoriteId;
          final label      = teamLeagueLabel(team.teamId);

          return Stack(
            children: [
              Container(
                width: 135,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B2B2B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      team.imagePath ?? '',
                      height: 80,
                      width: 80,
                      errorBuilder: (_, __, ___) => const SizedBox(height: 80, width: 80),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        team.name,
                        style: Body1_b.style,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        label,
                        style: Eyebrow.style,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              if (isFavorite)
                const Positioned(
                  top: 12,
                  right: 12,
                  child: Icon(Icons.star, color: Colors.white, size: 18),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayerList() {
    final players = followingPlayersByUser(_currentUserId);

    return SizedBox(
      height: 120,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final player = players[index];

          return Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 37,
                    backgroundImage: player.imageUrl != null
                        ? NetworkImage(player.imageUrl!)
                        : const AssetImage('assets/playerAvatar.png') as ImageProvider,
                    backgroundColor: const Color(0xFF272828),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF3D3D3D),
                      child: Text(
                        player.jerseyNumber.toString(),
                        style: Body2_b.style,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 80,
                child: Text(
                  player.playerName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Body1.style,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SettingsList extends StatefulWidget {
  const SettingsList({super.key});

  @override
  State<SettingsList> createState() => _SettingsListState();
}

class _SettingsListState extends State<SettingsList> {
  bool isDarkTheme = false;

  Widget _divider() => const Divider(
        color: Color(0xFF3A3A3A),
        thickness: 2,
        height: 1,
        indent: 24,
        endIndent: 24,
      );

  Widget _settingItem(
      {required IconData icon, required String title, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: Body1.style),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _settingItem(
          icon: Icons.badge_outlined,
          title: 'Personal Info',
          onTap: () {
            context.push('/profile/edit');
          },
        ),
        _divider(),
        _settingItem(
          icon: Icons.notifications_none,
          title: 'Notification',
          onTap: () {
            context.push('/profile/notification');
          },
        ),
        _divider(),
        _settingItem(
          icon: Icons.language_rounded,
          title: 'Preferences',
          onTap: () {
            context.push('/profile/preference');
          },
        ),
        _divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.brightness_4_outlined, color: Colors.white),
            title: Text("Dark Theme", style: Body1.style),
            trailing: Switch(
              value: isDarkTheme,
              activeThumbColor: Colors.white,
              activeTrackColor: Colors.white30,
              inactiveTrackColor: Colors.white10,
              inactiveThumbColor: Colors.white24,
              onChanged: (value) {
                setState(() {
                  isDarkTheme = value;
                });
              },
            ),
          ),
        ),
        _divider(),
        _settingItem(
          icon: Icons.chat_outlined,
          title: 'Contact Us',
          onTap: () {
            context.push('/profile/contact');
          },
        ),
        _divider(),
        _settingItem(
          icon: Icons.info_outline,
          title: 'About',
          onTap: () {
            context.push('/profile/about');
          },
        ),
      ],
    );
  }
}
