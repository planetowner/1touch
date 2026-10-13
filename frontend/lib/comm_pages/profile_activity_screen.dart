import 'package:onetouch/core/app_action_button.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/profile/api/api_community_profile_repository.dart';
import 'package:onetouch/data/profile/api/api_profile_activity_repository.dart';
import 'package:onetouch/models/community_profile.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'package:onetouch/features/community/community_header_slivers.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/core/app_snack_bar.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/features/media/profile_avatar.dart';
import 'package:onetouch/features/media/avatar_image_cache.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/app_segmented_toggle.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/profile/current_user_repository_provider.dart';
import 'package:onetouch/data/profile/profile_activity_repository.dart';
import 'package:onetouch/data/profile/profile_activity_repository_provider.dart';
import 'package:onetouch/features/community/community_feed_widgets.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/current_user_profile.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/profile_comment_activity.dart';
import 'package:onetouch/screens/CommunityScreen_utils/post_screen.dart';

enum ProfileActivityTab { posts, comments }

class ProfileActivityScreen extends StatefulWidget {
  const ProfileActivityScreen({
    super.key,
    this.profile,
    this.initialTab = ProfileActivityTab.posts,
    this.repository,
    this.userId,
    this.publicProfileRepository,
  });

  final int? userId;
  final ApiCommunityProfileRepository? publicProfileRepository;
  final CurrentUserProfile? profile;
  final ProfileActivityTab initialTab;
  final ProfileActivityRepository? repository;

  @override
  State<ProfileActivityScreen> createState() => _ProfileActivityScreenState();
}

class _ProfileActivityScreenState extends State<ProfileActivityScreen> {
  late ProfileActivityTab _selectedTab = widget.initialTab;
  int _activityRevision = 0;
  late final ProfileActivityRepository _repository = widget.repository ??
      (widget.userId == null
          ? profileActivityRepository
          : ApiProfileActivityRepository(
              api: apiClient, userId: widget.userId));
  late final _publicProfiles = widget.publicProfileRepository ??
      ApiCommunityProfileRepository(api: apiClient);
  late Future<CommunityProfile> _profileFuture = _loadProfile();
  bool? _following;
  bool _updatingFollow = false;
  Future<CommunityProfile> _loadProfile() async {
    if (widget.userId != null) return _publicProfiles.load(widget.userId!);
    final profile = widget.profile ?? await currentUserRepository.load();
    return CommunityProfile(
        userId: profile.userId,
        username: profile.username,
        displayName: profile.displayName,
        avatarUri: profile.avatarUri,
        isSelf: true);
  }

  Future<void> _follow(CommunityProfile profile) async {
    if (_updatingFollow) return;
    setState(() => _updatingFollow = true);
    final next = !(_following ?? profile.following);
    try {
      await _publicProfiles.setFollowing(profile.userId, next);
      if (mounted) setState(() => _following = next);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
            context, tr(context, 'Unable to update follow. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => _updatingFollow = false);
    }
  }

  Future<void> _editProfile() async {
    await context.push('/profile/edit');
    if (mounted) {
      setState(() => _profileFuture = currentUserRepository.load().then(
          (profile) => CommunityProfile(
              userId: profile.userId,
              username: profile.username,
              displayName: profile.displayName,
              avatarUri: profile.avatarUri,
              isSelf: true)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final background = Theme.of(context).brightness == Brightness.light
        ? AppPalette.lightGreyBox
        : communityPageBackground(context);

    const placeholder =
        CommunityIcon('profile', size: 108, originalColors: true);

    return Scaffold(
      key: const ValueKey('profile-activity-screen'),
      backgroundColor: background,
      appBar: AppBar(
          backgroundColor: background,
          toolbarHeight: 56,
          leading: IconButton(
              icon: const CommunityIcon('back'),
              onPressed: () => Navigator.pop(context)),
          actions: const [CommunityHeaderActions(showActivity: false)]),
      body: FutureBuilder<CommunityProfile>(
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
          final following = _following ?? profile.following;
          final listBottomPadding =
              profile.isSelf ? 0.0 : MediaQuery.paddingOf(context).bottom + 104;
          return Column(
            children: [
              const SizedBox(height: 24),
              SizedBox.square(
                  dimension: 108,
                  child: ProfileAvatar(
                    actionKey: const ValueKey('profile-activity-camera'),
                    onEdit: profile.isSelf ? _editProfile : null,
                    child: ClipOval(
                        child: ColoredBox(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppPalette.lightGrey
                                    : appColors.subtleBackground,
                            child: profile.avatarUri == null
                                ? placeholder
                                : Image(
                                    image: AvatarImageCache.provider(
                                      profile.avatarUri.toString(),
                                      headers: currentUserMediaRequestHeaders,
                                    ),
                                    width: 108,
                                    height: 108,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        placeholder))),
                  )),
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
                      label: trUpper(context, 'Comments'),
                      contentKey:
                          const ValueKey('profile-activity-tab-comments'),
                    ),
                  ],
                  onChanged: (tab) => setState(() => _selectedTab = tab),
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                  child: Stack(children: [
                Positioned.fill(
                    child: _buildActivity(context,
                        bottomPadding: listBottomPadding)),
                if (!profile.isSelf) ...[
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                        child: SizedBox(
                      height: 225,
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            background.withValues(alpha: 0),
                            background.withValues(alpha: .7)
                          ],
                        ),
                      )),
                    )),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 16,
                    child: SafeArea(
                      top: false,
                      left: false,
                      right: false,
                      child: AppActionButton(
                        buttonKey: const ValueKey('profile-activity-follow'),
                        label: trUpper(
                            context, following ? 'Following' : 'Follow'),
                        loading: _updatingFollow,
                        onPressed: () => _follow(profile),
                        backgroundColor: following
                            ? Theme.of(context).brightness == Brightness.light
                                ? AppPalette.lightGrey
                                : AppPalette.lightModeDarkGrey
                            : colors.onSurface,
                        foregroundColor: following
                            ? Theme.of(context).brightness == Brightness.light
                                ? AppPalette.white
                                : AppPalette.black
                            : colors.surface,
                      ),
                    ),
                  ),
                ],
              ])),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActivity(BuildContext context, {double bottomPadding = 0}) {
    if (_selectedTab == ProfileActivityTab.posts) {
      return _ActivityList<Post>(
        key: ValueKey((_selectedTab, _activityRevision)),
        tab: _selectedTab,
        loadPage: _repository.loadPosts,
        emptyMessage: 'No posts yet.',
        errorMessage: 'Unable to load community posts.',
        buildList: (items) => CommunityPostList(
          posts: items,
          bottomPadding: bottomPadding,
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
      buildList: (items) => _buildComments(items, bottomPadding: bottomPadding),
    );
  }

  Widget _buildComments(List<ProfileCommentActivity> comments,
      {double bottomPadding = 0}) {
    return ListView.separated(
      key: const ValueKey('profile-activity-comments-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding),
      itemCount: comments.length,
      separatorBuilder: (context, _) => const CommunityPostSeparator(),
      itemBuilder: (context, index) {
        final activity = comments[index];
        return InkWell(
          key: ValueKey(
              'profile-activity-comment-${activity.comment.commentId}'),
          onTap: () => _openPost(activity.post),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 댓글 탭의 원문은 본문 한 줄만 보여주고 좋아요 행은 생략해요.
              CommunityPostCard(
                  post: activity.post,
                  onTap: () => _openPost(activity.post),
                  bodyMaxLines: 1,
                  showEngagement: false),
              const SizedBox(height: 16),
              CommunityReplyIndent(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CommunityAuthorHeader(
                          userId: activity.comment.userId,
                          username: activity.comment.username,
                          displayName: activity.comment.displayName,
                          avatarUrl: activity.comment.avatarUrl,
                          authorDeleted: activity.comment.authorDeleted,
                          createdAt: activity.comment.createdAt,
                          editedAt: activity.comment.editedAt),
                      const SizedBox(height: 8),
                      Text(activity.comment.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: CommunityText.body(context,
                              text: activity.comment.body)),
                    ]),
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
