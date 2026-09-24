import "package:flutter/material.dart";
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/team_navigation.dart';
import 'package:onetouch/core/theme_controller.dart';
import 'package:onetouch/comm_pages/Profile_settings/TeamEdit.dart';
import 'package:onetouch/features/player/player_directory_widgets.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/data/profile/current_user_repository.dart';
import 'package:onetouch/data/profile/current_user_repository_provider.dart'
    as profile_provider;
import 'package:onetouch/data/teams/following_teams_repository.dart';
import 'package:onetouch/data/teams/following_teams_repository_provider.dart'
    as following_teams_provider;
import 'package:onetouch/data/teams/team_page_eligibility_provider.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/current_user_profile.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class Profile extends StatefulWidget {
  const Profile({
    super.key,
    this.repository,
    this.followingController,
    this.followingTeamsRepository,
    this.avatarRequestHeaders,
  });

  final CurrentUserRepository? repository;
  final PlayerFollowingController? followingController;
  final FollowingTeamsRepository? followingTeamsRepository;
  final Map<String, String>? avatarRequestHeaders;

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;
  CurrentUserProfile? _profile;
  List<Team> _followingTeams = const [];
  int? _favoriteTeamId;
  bool _isLoading = true;

  CurrentUserRepository get _repository =>
      widget.repository ?? profile_provider.currentUserRepository;

  FollowingTeamsRepository get _followingTeamsRepository =>
      widget.followingTeamsRepository ??
      following_teams_provider.followingTeamsRepository;

  Map<String, String> get _avatarRequestHeaders =>
      widget.avatarRequestHeaders ??
      (widget.repository == null
          ? profile_provider.currentUserMediaRequestHeaders
          : const {});

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _profile = null;
        _followingTeams = const [];
        _favoriteTeamId = null;
      });
    }

    try {
      final results = await Future.wait<Object>([
        _repository.load(),
        _followingTeamsRepository.load(),
      ]);
      final profile = results[0] as CurrentUserProfile;
      final followingTeams = (results[1] as List<Team>)
          .where((team) => teamPageEligibility.supports(team.teamId))
          .toList(growable: false);
      if (!teamPageEligibility.supports(profile.favoriteTeamId) ||
          !followingTeams
              .any((team) => team.teamId == profile.favoriteTeamId)) {
        throw StateError(
          'Favorite team ${profile.favoriteTeamId} is not an available '
          'current Big Five team.',
        );
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _followingTeams = followingTeams;
        _favoriteTeamId = profile.favoriteTeamId;
        _isLoading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _profile = null;
        _followingTeams = const [];
        _favoriteTeamId = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _openProfileEditor(CurrentUserProfile profile) async {
    final avatarChanged = await context.push<bool>(
      '/profile/edit',
      extra: profile,
    );
    if (!mounted || avatarChanged != true) return;
    await _loadProfile();
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
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final profileBackground =
        isLight ? AppPalette.lightGreyBox : appColors.pageBackground;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: profileBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return Scaffold(
        backgroundColor: profileBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr(context, 'Unable to load Profile.')),
              const SizedBox(height: 12),
              TextButton(
                key: const ValueKey('profile-retry-button'),
                onPressed: _loadProfile,
                child: Text(tr(context, 'Retry')),
              ),
            ],
          ),
        ),
      );
    }

    final appBarForeground = colors.onSurface;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: profileBackground,
      body: Stack(
        children: [
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
                  padding: const EdgeInsets.only(left: 24),
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
                    padding: const EdgeInsets.only(right: 8),
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
                  _buildProfileHeader(context, profile),
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
                            tr(context, "FOLLOWING TEAMS"),
                            style: Body2_b.style,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.border_color,
                              color: colors.onSurface, size: 20),
                          onPressed: () async {
                            final result = await showModalBottomSheet<
                                FollowingTeamsEditResult>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => EditFollowingTeamsSheet(
                                repository: _followingTeamsRepository,
                                initialTeams: _followingTeams,
                                initialFavoriteTeamId: _favoriteTeamId!,
                              ),
                            );
                            if (!mounted || result == null) return;
                            final supportedTeams = result.teams
                                .where((team) =>
                                    teamPageEligibility.supports(team.teamId))
                                .toList(growable: false);
                            if (!supportedTeams.any((team) =>
                                team.teamId == result.favoriteTeamId)) {
                              await _loadProfile();
                              return;
                            }
                            setState(() {
                              _followingTeams = supportedTeams;
                              _favoriteTeamId = result.favoriteTeamId;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTeamList(),
                  const SizedBox(height: 48),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: PlayerFavorites(
                      title: tr(context, 'FOLLOWING PLAYERS'),
                      controller: widget.followingController ??
                          playerFollowingController,
                      searchRepository: null,
                    ),
                  ),
                  const SizedBox(height: 48),

                  _buildSectionLabel(tr(context, "SETTINGS")),
                  const SizedBox(height: 16),
                  SettingsList(
                    onPersonalInfo: () => _openProfileEditor(profile),
                  ),
                  const SizedBox(height: 48),
                ]),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    CurrentUserProfile profile,
  ) {
    final appColors = AppColors.of(context);
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _openProfileEditor(profile),
            child: CircleAvatar(
              radius: 54,
              backgroundColor: appColors.subtleBackground,
              child: ClipOval(
                child: profile.avatarUri == null
                    ? Image.asset(
                        'assets/profileAvatar.png',
                        key: const ValueKey('profile-avatar-fallback'),
                        width: 108,
                        height: 108,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        profile.avatarUri.toString(),
                        key: const ValueKey('profile-avatar-network'),
                        headers: _avatarRequestHeaders,
                        width: 108,
                        height: 108,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/profileAvatar.png',
                          key: const ValueKey('profile-avatar-fallback'),
                          width: 108,
                          height: 108,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(profile.displayName, style: Heading5.style),
          Opacity(
            opacity: 0.5,
            child: Text(
              profile.email ?? '@${profile.username}',
              style: Body2.style,
            ),
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
            _buildStat('—', tr(context, "PTS")),
            _verticalDivider(),
            _buildStat('—', tr(context, "POSTS")),
            _verticalDivider(),
            _buildStat('—', tr(context, "COMMENTS")),
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
            Text(tr(context, label), style: Body2_b.style),
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
      child: Text(tr(context, title), style: Body2_b.style),
    );
  }

  Widget _buildTeamList() {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final teams = _followingTeams;
    final favoriteId = _favoriteTeamId!;

    return SizedBox(
      height: 165,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: teams.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final team = teams[index];
          final isFavorite = team.teamId == favoriteId;
          final label = teamCompetitionLabel(
              context, teamCompetitionContextResolver.resolve(team.teamId));

          return Semantics(
            button: true,
            label: tr(context, 'Open {name}',
                {'name': teamNameLabel(context, team.teamId, team.name)}),
            child: GestureDetector(
              key: ValueKey('profile-following-team-${team.teamId}'),
              behavior: HitTestBehavior.opaque,
              onTap: isTeamPageSupported(team.teamId)
                  ? () => openTeamPage(context, team.teamId)
                  : null,
              child: Stack(
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
                            teamNameLabel(context, team.teamId, team.name),
                            style: Body1_b.style,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            tr(context, label),
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
                      child:
                          Icon(Icons.star, color: colors.onSurface, size: 18),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SettingsList extends StatefulWidget {
  const SettingsList({
    super.key,
    required this.onPersonalInfo,
  });

  final VoidCallback onPersonalInfo;

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
      title: Text(tr(context, title), style: Body1.style),
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
          title: tr(context, 'Personal Info'),
          onTap: widget.onPersonalInfo,
        ),
        _divider(),
        _settingItem(
          icon: Icons.notifications_none,
          title: tr(context, 'Notification'),
          onTap: () {
            context.push('/profile/notification');
          },
        ),
        _divider(),
        _settingItem(
          icon: Icons.language_rounded,
          title: tr(context, 'Preferences'),
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
            title: Text(tr(context, "Dark Theme"), style: Body1.style),
            trailing: const AppThemeSwitch(),
          ),
        ),
        _divider(),
        _settingItem(
          icon: Icons.chat_outlined,
          title: tr(context, 'Contact Us'),
          onTap: () {
            context.push('/profile/contact');
          },
        ),
        _divider(),
        _settingItem(
          icon: Icons.info_outline,
          title: tr(context, 'About'),
          onTap: () {
            context.push('/profile/about');
          },
        ),
      ],
    );
  }
}
