import "package:flutter/material.dart";
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/theme_controller.dart';
import 'package:onetouch/comm_pages/Profile_settings/TeamEdit.dart';
import 'package:onetouch/comm_pages/Profile_settings/PlayerEdit.dart';
import 'package:onetouch/core/favorite_team.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/community/mock/community_catalog.dart';
import 'package:onetouch/data/players/mock_player_repository.dart';
import 'package:onetouch/data/teams/mock/team_catalog.dart';
import 'package:onetouch/features/player_image.dart';
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

    _user = mockUserById(_currentUserId);
    _userProfile = mockUserProfileById(_currentUserId);

    _teamColor = Color(mockTeamById(FavoriteTeam.id.value).primaryColor);
    currentUserPreferences.favoriteTeamId.addListener(_onPreferencesChanged);
    currentUserPreferences.followedTeamIds.addListener(_onPreferencesChanged);
    playerRepository.followedPlayerIds.addListener(_onPreferencesChanged);
  }

  void _onPreferencesChanged() {
    if (!mounted) return;
    setState(() {
      _teamColor = Color(mockTeamById(FavoriteTeam.id.value).primaryColor);
    });
  }

  @override
  void dispose() {
    currentUserPreferences.favoriteTeamId.removeListener(_onPreferencesChanged);
    currentUserPreferences.followedTeamIds
        .removeListener(_onPreferencesChanged);
    playerRepository.followedPlayerIds.removeListener(_onPreferencesChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Logic copied from HomeScreen to fade out the gradient
    double opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final profileBackground =
        isLight ? AppPalette.lightGreyBox : appColors.pageBackground;
    final gradientHeight = isLight
        ? (MediaQuery.sizeOf(context).height * 0.62)
            .clamp(420.0, 560.0)
            .toDouble()
        : 550.0;
    final appBarForeground =
        Color.lerp(AppPalette.white, colors.onSurface, opacityFactor)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: profileBackground,
      body: Stack(
        children: [
          // Background Gradient with AnimatedOpacity
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: gradientHeight,
            child: AnimatedOpacity(
              opacity: (1 - opacityFactor), // Fades out as you scroll down
              duration:
                  const Duration(milliseconds: 0), // Instant update with scroll
              child: Container(
                key: const ValueKey('profile-background-gradient'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isLight
                        ? [_teamColor, profileBackground]
                        : [
                            _teamColor,
                            appColors.pageBackground.withValues(alpha: 0),
                          ],
                    stops: isLight ? const [0.0, 0.9] : const [0.0, 0.6],
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
                    Colors.transparent, profileBackground, opacityFactor),
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
                    colorFilter:
                        ColorFilter.mode(appBarForeground, BlendMode.srcIn),
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
                              icon: Icon(Icons.notifications_none_rounded,
                                  size: 32, color: appBarForeground),
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
                          icon: Icon(Icons.search,
                              size: 32, color: appBarForeground),
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
                        Expanded(
                          child: Text(
                            "FOLLOWING TEAMS",
                            style: Body2_b.style,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.border_color,
                              color: colors.onSurface, size: 20),
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
                        Expanded(
                          child: Text(
                            "FOLLOWING PLAYERS",
                            style: Body2_b.style,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.border_color,
                              color: colors.onSurface, size: 20),
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
    final appColors = AppColors.of(context);
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              context.push('/profile/edit');
            },
            child: CircleAvatar(
              radius: 54,
              backgroundColor: appColors.subtleBackground,
              backgroundImage: AssetImage(
                _user.avatarAsset ?? 'assets/profileAvatar.png',
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
    final appColors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        key: const ValueKey('profile-stat-card'),
        height: 70,
        decoration: BoxDecoration(
          color: appColors.cardBackground,
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
      color: AppColors.of(context).divider,
    );
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(title, style: Body2_b.style),
    );
  }

  Widget _buildTeamList() {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final teamIds = currentUserPreferences.followedTeamIds.value;
    final favoriteId = FavoriteTeam.id.value;

    return SizedBox(
      height: 165,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: teamIds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final team = mockTeamById(teamIds[index]);
          final isFavorite = team.teamId == favoriteId;
          final label = teamLeagueLabel(team.teamId);

          return Stack(
            children: [
              Container(
                width: 135,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: appColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      team.imagePath ?? '',
                      height: 80,
                      width: 80,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox(height: 80, width: 80),
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
                Positioned(
                  top: 12,
                  right: 12,
                  child: Icon(Icons.star, color: colors.onSurface, size: 18),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayerList() {
    final appColors = AppColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final players = playerRepository.favorites;

    return SizedBox(
      key: const ValueKey('profile-following-player-list'),
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
                  SizedBox(
                    width: 74,
                    height: 74,
                    child: ClipOval(child: PlayerImage(player: player)),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: CircleAvatar(
                      key: ValueKey('profile-player-jersey-${player.id}'),
                      radius: 16,
                      backgroundColor: isLight
                          ? AppPalette.white
                          : appColors.subtleBackground,
                      child: Text(
                        player.jerseyNumber.toString(),
                        style: Body2_b.style.copyWith(
                          color: isLight ? AppPalette.black : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 80,
                child: Text(
                  player.fullName,
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
  Widget _divider() => Divider(
        color: AppColors.of(context).divider,
        thickness: 2,
        height: 1,
        indent: 24,
        endIndent: 24,
      );

  Widget _settingItem(
      {required IconData icon, required String title, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: Body1.style),
      trailing: const Icon(Icons.arrow_forward_ios),
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
            leading: const Icon(Icons.brightness_4_outlined),
            title: Text("Dark Theme", style: Body1.style),
            trailing: const AppThemeSwitch(),
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
