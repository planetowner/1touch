// ignore_for_file: file_names

import 'dart:async';

import "package:flutter/material.dart";
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/team_navigation.dart';
import 'package:onetouch/core/theme_controller.dart';
import 'package:onetouch/comm_pages/Profile_settings/TeamEdit.dart';
import 'package:onetouch/features/player/player_directory_widgets.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/data/profile/current_user_repository.dart';
import 'package:onetouch/data/profile/profile_activity_repository.dart';
import 'package:onetouch/data/profile/profile_activity_repository_provider.dart'
    as activity_provider;
import 'package:onetouch/data/profile/current_user_repository_provider.dart'
    as profile_provider;
import 'package:onetouch/data/auth/auth_repository_provider.dart'
    as auth_provider;
import 'package:onetouch/data/teams/following_teams_repository.dart';
import 'package:onetouch/data/teams/following_teams_repository_provider.dart'
    as following_teams_provider;
import 'package:onetouch/data/teams/team_page_eligibility_provider.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/current_user_profile.dart';
import 'package:onetouch/models/profile_activity_counts.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/data/betting/betting_repository_provider.dart';
import 'package:onetouch/data/notifications/notification_unread_controller_provider.dart';
import 'package:onetouch/features/notifications/unread_notification_bell_icon.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class Profile extends StatefulWidget {
  const Profile({
    super.key,
    this.repository,
    this.activityRepository,
    this.followingController,
    this.followingTeamsRepository,
    this.avatarRequestHeaders,
    this.loadPointBalance,
  });

  final CurrentUserRepository? repository;
  final ProfileActivityRepository? activityRepository;
  final PlayerFollowingController? followingController;
  final FollowingTeamsRepository? followingTeamsRepository;
  final Map<String, String>? avatarRequestHeaders;
  final Future<int> Function()? loadPointBalance;

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
  ProfileActivityCounts? _activityCounts;
  bool _isLoadingCounts = true;
  int _activityRequest = 0;
  int? _pointBalance;
  bool _isLoadingPoints = true;
  int _pointRequest = 0;

  CurrentUserRepository get _repository =>
      widget.repository ?? profile_provider.currentUserRepository;

  ProfileActivityRepository get _activityRepository =>
      widget.activityRepository ?? activity_provider.profileActivityRepository;

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
    if (authSession.isAuthenticated) {
      unawaited(notificationUnreadController.refresh());
    }
  }

  Future<void> _loadProfile() async {
    _loadActivityCounts();
    _loadPoints();
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

  Future<void> _loadActivityCounts() async {
    final request = ++_activityRequest;
    setState(() {
      _isLoadingCounts = true;
      _activityCounts = null;
    });
    ProfileActivityCounts? counts;
    try {
      counts = await _activityRepository.loadCounts();
    } on Object {
      // 조회 실패는 0건과 구분하고, 프로필 정보는 계속 보여줘요.
    }
    // 팀 변경 전 요청이 늦게 끝나도 최신 집계를 덮지 않아요.
    if (!mounted || request != _activityRequest) return;
    setState(() {
      _activityCounts = counts;
      _isLoadingCounts = false;
    });
  }

  Future<void> _openActivity(String tab) async {
    await context.push('/profile/activity?tab=$tab', extra: _profile);
    if (!mounted) return;
    await Future.wait([_loadActivityCounts(), _loadPoints()]);
  }

  Future<void> _loadPoints() async {
    final request = ++_pointRequest;
    setState(() {
      _isLoadingPoints = true;
      _pointBalance = null;
    });
    int? balance;
    try {
      balance = widget.loadPointBalance != null
          ? await widget.loadPointBalance!()
          : (await bettingRepository.initializeWallet()).balance;
    } on Object {
      // 조회 실패를 0점으로 표시하지 않아요.
    }
    if (!mounted || request != _pointRequest) return;
    setState(() {
      _pointBalance = balance;
      _isLoadingPoints = false;
    });
  }

  Future<void> _openProfileEditor(CurrentUserProfile profile) async {
    await context.push<bool>(
      '/profile/edit',
      extra: profile,
    );
    if (!mounted) return;
    // 소셜 연결은 저장 버튼 없이 즉시 반영되므로 뒤로 돌아올 때도 프로필을 갱신해요.
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
        body: const Center(child: FootballLoadingIndicator()),
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
                  child: SizedBox(
                    width: 32,
                    height: 24,
                    child: IconButton(
                      key: const ValueKey('profile-back-button'),
                      tooltip: tr(context, 'Back'),
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/home');
                        }
                      },
                      icon: Icon(Icons.arrow_back_ios_new,
                          color: appBarForeground),
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      children: [
                        ListenableBuilder(
                          listenable: notificationUnreadController,
                          builder: (context, _) => IconButton(
                            key: const ValueKey('profile-notifications-button'),
                            onPressed: () => context.push('/notifications'),
                            icon: UnreadNotificationBellIcon(
                              color: appBarForeground,
                              hasUnread: notificationUnreadController.hasUnread,
                              badgeKey:
                                  const ValueKey('profile-notification-badge'),
                            ),
                          ),
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
                            await _loadActivityCounts();
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
                      title: 'FOLLOWING PLAYERS',
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
          Text(
            profile.profileHeading,
            style: Heading5.style,
          ),
          if (profile.email != null)
            Opacity(
              opacity: 0.5,
              child: Text(
                profile.email!,
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: appColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                const dividerWidth = 2.0;
                const dividerGap = 10.0;
                final statWidth =
                    (constraints.maxWidth - dividerWidth * 2 - dividerGap * 2) /
                        3;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildStat(_pointBalance?.toString(), tr(context, "PTS"),
                        statKey: 'points',
                        width: statWidth,
                        tab: 'posts',
                        loading: _isLoadingPoints),
                    _verticalDivider('points-posts'),
                    const SizedBox(width: dividerGap),
                    _buildStat(_activityCounts?.postCount.toString(),
                        tr(context, "POSTS"),
                        statKey: 'posts',
                        width: statWidth,
                        tab: 'posts',
                        loading: _isLoadingCounts),
                    _verticalDivider('posts-comments'),
                    const SizedBox(width: dividerGap),
                    _buildStat(_activityCounts?.commentCount.toString(),
                        tr(context, "COMMENTS"),
                        statKey: 'comments',
                        width: statWidth,
                        tab: 'comments',
                        loading: _isLoadingCounts),
                  ],
                );
              },
            ),
            if (!_isLoadingCounts && _activityCounts == null) ...[
              const SizedBox(height: 12),
              Text(tr(context, 'Unable to load activity counts.')),
              TextButton(
                key: const ValueKey('profile-activity-counts-retry'),
                onPressed: _loadActivityCounts,
                child: Text(tr(context, 'Retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStat(
    String? value,
    String label, {
    required String statKey,
    required double width,
    required String tab,
    required bool loading,
  }) {
    return GestureDetector(
      key: ValueKey('profile-stat-$statKey'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _openActivity(tab),
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: width,
              height: MediaQuery.textScalerOf(context)
                      .scale(Heading3.style.fontSize!) *
                  Heading3.style.height!,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: value == null && loading
                    ? FootballLoadingIndicator(
                        key: ValueKey('profile-stat-$statKey-loading'),
                      )
                    : Text(value ?? '—',
                        textAlign: TextAlign.left, style: Heading3.style),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: width,
              height: Body2_b.style.fontSize! * Body2_b.style.height!,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(tr(context, label),
                    maxLines: 1, softWrap: false, style: Body2_b.style),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider(String dividerKey) {
    return Container(
      key: ValueKey('profile-stat-divider-$dividerKey'),
      width: 2,
      height: 51,
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
    final textScaler = MediaQuery.textScalerOf(context);
    final teamNameStyle = Body1_b.style;
    final competitionStyle = Eyebrow.style;
    final requiredCardHeight = 32 +
        80 +
        8 +
        textScaler.scale(teamNameStyle.fontSize!) *
            (teamNameStyle.height ?? 1) +
        4 +
        textScaler.scale(competitionStyle.fontSize!) *
            (competitionStyle.height ?? 1);
    final cardHeight =
        requiredCardHeight > 165 ? requiredCardHeight.ceilToDouble() : 165.0;

    return SizedBox(
      height: cardHeight,
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
                            style: teamNameStyle,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            tr(context, label),
                            style: competitionStyle,
                            maxLines: 1,
                            softWrap: false,
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
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.all(24),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        // TextButton's tap target adds about 16 px below the visible label.
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        title: Text(tr(dialogContext, 'Log out?')),
        content: Text(
          tr(dialogContext, 'You will need to sign in again to use 1touch.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr(dialogContext, 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr(dialogContext, 'Log out')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    await auth_provider.authService.logout();
    if (!mounted) return;
    context.go('/onboarding');
  }

  Widget _divider() => Divider(
        color: AppColors.of(context).divider,
        thickness: 2,
        height: 1,
        indent: 24,
        endIndent: 24,
      );

  Widget _settingItem(
      {required Key itemKey,
      required IconData icon,
      required String title,
      VoidCallback? onTap}) {
    return ListTile(
      key: itemKey,
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
          itemKey: const ValueKey('profile-setting-personal-info'),
          icon: Icons.badge_outlined,
          title: tr(context, 'Account'),
          onTap: widget.onPersonalInfo,
        ),
        _divider(),
        _settingItem(
          itemKey: const ValueKey('profile-setting-notification'),
          icon: Icons.notifications_none,
          title: tr(context, 'Notification'),
          onTap: () {
            context.push('/profile/notification');
          },
        ),
        _divider(),
        _settingItem(
          itemKey: const ValueKey('profile-setting-preferences'),
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
            key: const ValueKey('profile-setting-dark-theme'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.brightness_4_outlined),
            title: Text(tr(context, "Dark Theme"), style: Body1.style),
            trailing: const AppThemeSwitch(),
            onTap: appThemeController.toggle,
          ),
        ),
        _divider(),
        _settingItem(
          itemKey: const ValueKey('profile-setting-contact'),
          icon: Icons.chat_outlined,
          title: tr(context, 'Contact Us'),
          onTap: () {
            context.push('/profile/contact');
          },
        ),
        _divider(),
        _settingItem(
          itemKey: const ValueKey('profile-setting-about'),
          icon: Icons.info_outline,
          title: tr(context, 'About'),
          onTap: () {
            context.push('/profile/about');
          },
        ),
        _divider(),
        ListTile(
          key: const ValueKey('profile-logout'),
          leading: const Icon(Icons.logout),
          title: Text(
            tr(context, _isLoggingOut ? 'Logging out...' : 'Log out'),
            style: Body1.style,
          ),
          onTap: _isLoggingOut ? null : _logout,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ],
    );
  }
}
