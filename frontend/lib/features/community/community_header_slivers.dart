import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/models/team.dart';

class CommunitySliverAppBar extends StatelessWidget {
  const CommunitySliverAppBar({
    super.key,
    required this.pageBackground,
    required this.opacityFactor,
    required this.onSearch,
    required this.onProfile,
  });

  final Color pageBackground;
  final double opacityFactor;
  final VoidCallback onSearch;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return SliverAppBar(
      backgroundColor: Color.lerp(
        Colors.transparent,
        pageBackground,
        opacityFactor,
      ),
      foregroundColor: foreground,
      elevation: 0,
      floating: true,
      snap: true,
      toolbarHeight: 80,
      centerTitle: false,
      titleSpacing: 0,
      flexibleSpace: ColoredBox(color: pageBackground),
      title: Padding(
        padding: const EdgeInsets.only(left: 24, top: 30),
        child: SvgPicture.asset(
          'assets/app_logo.svg',
          height: 23,
          width: 120,
          colorFilter: ColorFilter.mode(
            foreground,
            BlendMode.srcIn,
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8, top: 30),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('community-search-button'),
                onPressed: onSearch,
                icon: Icon(
                  Icons.search,
                  size: 32,
                  color: foreground,
                ),
              ),
              IconButton(
                key: const ValueKey('community-profile-button'),
                onPressed: onProfile,
                icon: Icon(
                  Icons.account_circle_outlined,
                  size: 32,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ],
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final foreground = Theme.of(context).colorScheme.onSurface;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
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
                          team.name,
                          key: const ValueKey('community-team-name'),
                          style: Heading4.style.copyWith(
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
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'LIVE',
                            style: Body2_b.style.copyWith(
                              color:
                                  isLight ? AppPalette.black : AppPalette.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatFollowers(followerCount),
                    key: const ValueKey('community-follower-count'),
                    style: Body2.style.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CommunityPostTabHeader extends StatelessWidget {
  const CommunityPostTabHeader({
    super.key,
    required this.controller,
    required this.onTap,
  });

  final TabController controller;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);

    return SliverPersistentHeader(
      floating: true,
      pinned: false,
      delegate: _CommunityTabBarDelegate(
        TabBar(
          controller: controller,
          onTap: onTap,
          isScrollable: true,
          labelColor: colors.onSurface,
          unselectedLabelColor: appColors.mutedForeground,
          indicatorColor: colors.onSurface,
          labelStyle: Heading5.style,
          unselectedLabelStyle: Heading5.style,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          padding: const EdgeInsets.only(left: 8),
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(color: colors.onSurface, width: 2),
          ),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'General'),
            Tab(text: 'Analysis'),
            Tab(text: 'News & Insights'),
          ],
          tabAlignment: TabAlignment.start,
        ),
      ),
    );
  }
}

String _formatFollowers(int? count) {
  if (count == null) return 'Followers';
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M Followers';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K Followers';
  }
  return '$count Followers';
}

class _CommunityTabBarDelegate extends SliverPersistentHeaderDelegate {
  _CommunityTabBarDelegate(this.tabBar);

  final TabBar tabBar;

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
  bool shouldRebuild(_CommunityTabBarDelegate oldDelegate) => false;
}
