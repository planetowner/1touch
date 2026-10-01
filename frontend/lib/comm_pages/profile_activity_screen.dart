import 'package:flutter/material.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/app_segmented_toggle.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/profile/current_user_repository_provider.dart';
import 'package:onetouch/data/profile/profile_activity_repository.dart';
import 'package:onetouch/data/profile/profile_activity_repository_provider.dart';
import 'package:onetouch/features/community/community_feed_widgets.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/current_user_profile.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/profile_comment_activity.dart';
import 'package:onetouch/screens/CommunityScreen_utils/PostScreen.dart';

enum ProfileActivityTab { posts, comments }

class ProfileActivityScreen extends StatefulWidget {
  const ProfileActivityScreen({
    super.key,
    this.profile,
    this.initialTab = ProfileActivityTab.posts,
    this.repository,
  });

  final CurrentUserProfile? profile;
  final ProfileActivityTab initialTab;
  final ProfileActivityRepository? repository;

  @override
  State<ProfileActivityScreen> createState() => _ProfileActivityScreenState();
}

class _ProfileActivityScreenState extends State<ProfileActivityScreen> {
  late ProfileActivityTab _selectedTab = widget.initialTab;
  int _activityRevision = 0;
  ProfileActivityRepository get _repository =>
      widget.repository ?? profileActivityRepository;
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
            return const Center(child: FootballLoadingIndicator());
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
                profile.profileHeading,
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
      return _ActivityList<Post>(
        key: ValueKey((_selectedTab, _activityRevision)),
        tab: _selectedTab,
        loadPage: _repository.loadPosts,
        emptyMessage: 'No posts yet.',
        errorMessage: 'Unable to load community posts.',
        buildList: (items) => CommunityPostList(
          posts: items,
          onPostTap: _openPost,
          physics: const AlwaysScrollableScrollPhysics(),
        ),
      );
    }
    return _ActivityList<ProfileCommentActivity>(
      key: ValueKey((_selectedTab, _activityRevision)),
      tab: _selectedTab,
      loadPage: _repository.loadComments,
      emptyMessage: 'No comments yet.',
      errorMessage: 'Unable to load comments.',
      buildList: _buildComments,
    );
  }

  Widget _buildComments(List<ProfileCommentActivity> comments) {
    return ListView.separated(
      key: const ValueKey('profile-activity-comments-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: comments.length,
      separatorBuilder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Divider(height: 1, color: AppColors.of(context).divider),
      ),
      itemBuilder: (context, index) {
        final activity = comments[index];
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

  Future<void> _openPost(Post post) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PostDetailScreen(post: post)),
    );
    // 상세에서 바뀐 좋아요와 댓글 수를 돌아온 목록에도 반영해요.
    if (mounted) setState(() => _activityRevision++);
  }
}

// 게시글과 댓글은 항목 UI만 다르고 조회·새로고침·페이지·오류 처리는 같아요.
class _ActivityList<T> extends StatefulWidget {
  const _ActivityList({
    super.key,
    required this.tab,
    required this.loadPage,
    required this.emptyMessage,
    required this.errorMessage,
    required this.buildList,
  });

  final ProfileActivityTab tab;
  final Future<List<T>> Function({int limit, int offset}) loadPage;
  final String emptyMessage;
  final String errorMessage;
  final Widget Function(List<T>) buildList;

  @override
  State<_ActivityList<T>> createState() => _ActivityListState<T>();
}

class _ActivityListState<T> extends State<_ActivityList<T>> {
  static const _pageSize = 50;
  List<T> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
      if (refresh) _items = [];
    });
    try {
      final page = await widget.loadPage(
        limit: _pageSize,
        offset: _items.length,
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...page];
        _hasMore = page.length == _pageSize;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Widget _error() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Expanded(
                child:
                    Text(tr(context, widget.errorMessage), style: Body1.style)),
            TextButton(
              key: ValueKey('profile-activity-retry-${widget.tab.name}'),
              onPressed: () => _load(),
              child: Text(tr(context, 'Retry')),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final loading = Center(
      child: FootballLoadingIndicator(
        key: ValueKey('profile-activity-loading-${widget.tab.name}'),
      ),
    );
    if (_items.isEmpty && _loading) return loading;
    if (_items.isEmpty && _failed) {
      return Center(child: SingleChildScrollView(child: _error()));
    }
    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.depth == 0 &&
                  (notification is ScrollUpdateNotification ||
                      notification is OverscrollNotification) &&
                  notification.metrics.extentAfter < 200 &&
                  _hasMore &&
                  !_failed) {
                _load();
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              child: _items.isEmpty
                  ? CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              tr(context, widget.emptyMessage),
                              key: ValueKey(
                                  'profile-activity-empty-${widget.tab.name}'),
                              style: Body1.style.copyWith(
                                  color: AppColors.of(context).mutedForeground),
                            ),
                          ),
                        ),
                      ],
                    )
                  : widget.buildList(_items),
            ),
          ),
        ),
        if (_failed) _error(),
        if (_loading) SizedBox(height: 48, child: loading),
      ],
    );
  }
}
