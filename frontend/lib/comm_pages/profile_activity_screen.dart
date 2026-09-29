import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/app_segmented_toggle.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/profile/current_user_repository_provider.dart';
import 'package:onetouch/features/community/community_feed_widgets.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/user_name_labels.dart';
import 'package:onetouch/models/current_user_profile.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/post_comment.dart';
import 'package:onetouch/screens/CommunityScreen_utils/PostScreen.dart';

enum ProfileActivityTab { posts, comments }

class ProfileCommentActivity {
  const ProfileCommentActivity({required this.post, required this.comment});

  final Post post;
  final PostComment comment;
}

class ProfileActivityScreen extends StatefulWidget {
  const ProfileActivityScreen({
    super.key,
    this.profile,
    this.initialTab = ProfileActivityTab.posts,
    this.posts = const [],
    this.comments = const [],
  });

  final CurrentUserProfile? profile;
  final ProfileActivityTab initialTab;
  final List<Post> posts;
  final List<ProfileCommentActivity> comments;

  @override
  State<ProfileActivityScreen> createState() => _ProfileActivityScreenState();
}

class _ProfileActivityScreenState extends State<ProfileActivityScreen> {
  late ProfileActivityTab _selectedTab = widget.initialTab;
  late final Future<CurrentUserProfile> _profileFuture = widget.profile == null
      ? currentUserRepository.load()
      : Future.value(widget.profile!);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final background = Theme.of(context).brightness == Brightness.light
        ? AppPalette.lightGreyBox
        : appColors.pageBackground;

    return Scaffold(
      key: const ValueKey('profile-activity-screen'),
      backgroundColor: background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: background,
        toolbarHeight: 80,
        titleSpacing: 24,
        title: SvgPicture.asset(
          'assets/app_logo.svg',
          width: 120,
          height: 23,
          colorFilter: ColorFilter.mode(colors.onSurface, BlendMode.srcIn),
        ),
        actions: [
          IconButton(
            key: const ValueKey('profile-activity-notifications'),
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_none_rounded, size: 32),
          ),
          IconButton(
            key: const ValueKey('profile-activity-search'),
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search, size: 32),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<CurrentUserProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(
                  child: Text(tr(context, 'Unable to load Profile.')));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data!;
          return Column(
            children: [
              const SizedBox(height: 48),
              CircleAvatar(
                radius: 54,
                backgroundColor: appColors.subtleBackground,
                child: ClipOval(
                  child: profile.avatarUri == null
                      ? Image.asset('assets/profileAvatar.png',
                          width: 108, height: 108, fit: BoxFit.cover)
                      : Image.network(
                          profile.avatarUri.toString(),
                          headers: currentUserMediaRequestHeaders,
                          width: 108,
                          height: 108,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/profileAvatar.png',
                            width: 108,
                            height: 108,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                userNameLabel(
                  locale: Localizations.localeOf(context),
                  firstName: profile.firstName,
                  lastName: profile.lastName,
                ),
                style: Heading5.style,
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AppSegmentedToggle<ProfileActivityTab>(
                  containerKey: const ValueKey('profile-activity-toggle'),
                  indicatorSurfaceKey:
                      const ValueKey('profile-activity-toggle-indicator'),
                  value: _selectedTab,
                  options: [
                    AppSegmentedToggleOption(
                      value: ProfileActivityTab.posts,
                      label: tr(context, 'POSTS'),
                      contentKey: const ValueKey('profile-activity-tab-posts'),
                    ),
                    AppSegmentedToggleOption(
                      value: ProfileActivityTab.comments,
                      label: tr(context, 'COMMENTS'),
                      contentKey:
                          const ValueKey('profile-activity-tab-comments'),
                    ),
                  ],
                  onChanged: (tab) => setState(() => _selectedTab = tab),
                ),
              ),
              const SizedBox(height: 32),
              Expanded(child: _buildActivity(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActivity(BuildContext context) {
    if (_selectedTab == ProfileActivityTab.posts) {
      if (widget.posts.isEmpty) {
        return _emptyState(context, 'No posts yet.');
      }
      return CommunityPostList(
        posts: widget.posts,
        onPostTap: _openPost,
      );
    }
    if (widget.comments.isEmpty) {
      return _emptyState(context, 'No comments yet.');
    }
    return ListView.separated(
      key: const ValueKey('profile-activity-comments-list'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: widget.comments.length,
      separatorBuilder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Divider(height: 1, color: AppColors.of(context).divider),
      ),
      itemBuilder: (context, index) {
        final activity = widget.comments[index];
        return InkWell(
          key: ValueKey(
              'profile-activity-comment-${activity.comment.commentId}'),
          onTap: () => _openPost(activity.post),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(activity.post.title, style: Body1_b.style),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(left: 16),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      width: 2,
                      color: AppColors.of(context).divider,
                    ),
                  ),
                ),
                child: Text(activity.comment.body, style: Body1.style),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState(BuildContext context, String message) => Center(
        child: Text(
          tr(context, message),
          key: ValueKey('profile-activity-empty-${_selectedTab.name}'),
          style: Body1.style
              .copyWith(color: AppColors.of(context).mutedForeground),
        ),
      );

  void _openPost(Post post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PostDetailScreen(post: post)),
    );
  }
}
