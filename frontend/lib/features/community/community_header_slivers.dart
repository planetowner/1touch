import 'package:onetouch/features/notifications/unread_notification_bell_icon.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/favorite_team.dart';
import 'package:onetouch/data/notifications/notification_unread_controller_provider.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/core/app_header.dart';
import 'package:onetouch/core/app_section_tab_bar.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/features/match_info/live_match_motion.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class CommunitySliverAppBar extends StatelessWidget {
  const CommunitySliverAppBar({
    super.key,
    required this.pageBackground,
    required this.opacityFactor,
    required this.onSearch,
    required this.onNotifications,
    required this.onActivity,
    required this.hasUnreadNotifications,
  });

  final Color pageBackground;
  final double opacityFactor;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onActivity;
  final bool hasUnreadNotifications;

  @override
  Widget build(BuildContext context) {
    return AppBrandSliverHeader(
      pageBackground: pageBackground,
      opacityFactor: opacityFactor,
      logoKey: const ValueKey('community-app-logo'),
      actions: CommunityHeaderActions(
          onSearch: onSearch,
          onNotifications: onNotifications,
          onActivity: onActivity,
          hasUnread: hasUnreadNotifications),
    );
  }
}

class CommunityTeamHeader extends StatelessWidget {
  const CommunityTeamHeader({
    super.key,
    required this.team,
    required this.isLive,
    required this.followerCount,
    required this.onTeamTap,
  });

  final Team team;
  final bool isLive;
  final int? followerCount;
  final VoidCallback? onTeamTap;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;

    return SliverToBoxAdapter(
      child: Padding(
        key: const ValueKey('community-team-header-padding'),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              key: const ValueKey('community-team-logo'),
              onTap: onTeamTap,
              child: team.imagePath != null
                  ? Image.network(
                      team.imagePath!,
                      height: 52,
                      width: 52,
                      errorBuilder: (_, __, ___) =>
                          teamLogoFallback(team.teamId, size: 52),
                    )
                  : const Icon(
                      Icons.shield,
                      color: Colors.white54,
                      size: 52,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          teamNameLabel(context, team.teamId, team.name),
                          key: const ValueKey('community-team-name'),
                          style: Heading3.style.copyWith(
                            color: foreground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLive) ...[
                        const SizedBox(width: 8),
                        Container(
                          key: const ValueKey('community-live-badge'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5C5C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LivePulseDot(
                                size: 7,
                                color: AppPalette.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                trUpper(context, 'Live'),
                                style: Body2_b.style.copyWith(
                                  color: AppPalette.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatFollowers(context, followerCount),
                    key: const ValueKey('community-follower-count'),
                    style: CommunityText.secondary(context)
                        .copyWith(color: foreground),
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<int>(
                valueListenable: FavoriteTeam.id,
                builder: (context, favorite, _) => favorite == team.teamId
                    ? const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: CommunityIcon('star', size: 32))
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

class CommunityPostTabHeader extends StatelessWidget {
  // 전체 탭만 분류 없이 조회하고, 나머지는 글쓰기와 같은 분류 목록을 써요.
  static const categories = <PostCategory?>[null, ...PostCategory.values];

  const CommunityPostTabHeader({
    super.key,
    required this.controller,
    required this.onTap,
  });

  final TabController controller;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      floating: true,
      pinned: false,
      delegate: _CommunityTabBarDelegate(
        appSectionTabBar(
          context,
          controller: controller,
          endPadding: 10,
          onTap: onTap,
          labels: [
            for (final category in categories)
              tr(context, category?.label ?? 'All'),
          ],
        ),
      ),
    );
  }
}

String _formatFollowers(BuildContext context, int? count) {
  if (count == null) return tr(context, 'Followers');
  final label = count >= 1000000
      ? '${(count / 1000000).toStringAsFixed(1)}M'
      : count >= 1000
          ? '${(count / 1000).toStringAsFixed(1)}K'
          : '$count';
  return tr(context, '{count} Followers', {'count': label});
}

class _CommunityTabBarDelegate extends SliverPersistentHeaderDelegate {
  _CommunityTabBarDelegate(this.tabBar);

  final PreferredSizeWidget tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return tabBar;
  }

  @override
  bool shouldRebuild(_CommunityTabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar;
}

// 목록·상세·글쓰기·프로필에서 같은 이동과 알림 상태를 사용해요.
class CommunityHeaderActions extends StatelessWidget {
  const CommunityHeaderActions(
      {super.key,
      this.onSearch,
      this.onNotifications,
      this.onActivity,
      this.hasUnread,
      this.showActivity = true});
  final VoidCallback? onSearch, onNotifications, onActivity;
  final bool? hasUnread;
  final bool showActivity;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: notificationUnreadController,
      builder: (context, _) => AppHeaderActions(children: [
            _button(
                context,
                'search',
                onSearch ?? () => context.push('/search'),
                const Icon(Icons.search)),
            _button(
                context,
                'notifications',
                onNotifications ?? () => context.push('/notifications'),
                UnreadNotificationBellIcon(
                  color: Theme.of(context).colorScheme.onSurface,
                  hasUnread:
                      hasUnread ?? notificationUnreadController.hasUnread,
                  badgeKey: const ValueKey('community-notification-badge'),
                )),
            if (showActivity) ...[
              _button(
                  context,
                  'activity',
                  onActivity ??
                      () => context.push('/profile/activity?tab=posts'),
                  const CommunityIcon('activity', size: 32))
            ],
          ]));
  Widget _button(
          BuildContext context, String name, VoidCallback onTap, Widget icon) =>
      AppHeaderIconButton(
          key: ValueKey('community-$name-button'),
          onPressed: onTap,
          tooltip: tr(
              context,
              name == 'activity'
                  ? 'My activity'
                  : name == 'search'
                      ? 'Search'
                      : 'Notifications'),
          icon: icon);
}
