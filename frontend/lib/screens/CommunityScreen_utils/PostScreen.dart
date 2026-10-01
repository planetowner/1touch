import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/community/community_repository.dart';
import 'package:onetouch/data/community/community_repository_provider.dart'
    as community_providers;
import 'package:onetouch/data/post_comments/post_comment_repository.dart';
import 'package:onetouch/data/post_comments/post_comment_repository_provider.dart'
    as comment_providers;
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/data/posts/post_repository_provider.dart'
    as post_providers;
import 'package:onetouch/data/profile/current_user_repository_provider.dart'
    as profile_providers;
import 'package:onetouch/features/community/community_delete_dialog.dart';
import 'package:onetouch/screens/CommunityScreen_utils/AddPost.dart';
import 'package:onetouch/features/community/post_detail_content.dart';
import 'package:onetouch/features/community/community_access.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/post_comment.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  final PostRepository? postRepository;
  final CommunityRepository? communityRepository;
  final PostCommentRepository? postCommentRepository;
  final int? currentUserId;
  final Future<void> Function()? onPostUpdated;

  const PostDetailScreen({
    super.key,
    required this.post,
    this.postRepository,
    this.communityRepository,
    this.postCommentRepository,
    this.currentUserId,
    this.onPostUpdated,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  // 1. Add Scroll Controller and Offset variable
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;
  late bool _liked;
  late int _likeCount;
  late int _commentCount;
  bool _isUpdatingLike = false;
  bool _isCreatingComment = false;
  PostComment? _replyTarget;
  PostComment? _editingComment;
  List<PostComment> _comments = const [];
  bool _commentsLoading = true;
  Object? _commentsError;
  int _commentsRequestGeneration = 0;
  late Post _post;
  int? _currentUserId;
  bool _isDeletingPost = false;
  bool _isEditingPost = false;
  bool _isRefreshingPost = false;
  bool _postRefreshFailed = false;
  final Set<int> _deletingCommentIds = {};

  PostRepository get _postRepository =>
      widget.postRepository ?? post_providers.postRepository;

  CommunityRepository get _communityRepository =>
      widget.communityRepository ?? community_providers.communityRepository;

  PostCommentRepository get _postCommentRepository =>
      widget.postCommentRepository ?? comment_providers.postCommentRepository;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _syncEngagementFromPost();
    _currentUserId = widget.currentUserId;
    if (_currentUserId == null && authSession.isAuthenticated) {
      unawaited(_loadCurrentUserId());
    }
    unawaited(_loadComments(showLoading: false));
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });
  }

  @override
  void didUpdateWidget(PostDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post != oldWidget.post) _post = widget.post;
    if (widget.post.postId != oldWidget.post.postId) {
      _syncEngagementFromPost();
      _isUpdatingLike = false;
      _isCreatingComment = false;
      _replyTarget = null;
      _editingComment = null;
      _comments = const [];
      _commentsLoading = true;
      _commentsError = null;
      unawaited(_loadComments(showLoading: false));
    } else if (widget.postCommentRepository !=
        oldWidget.postCommentRepository) {
      unawaited(_loadComments());
    }
  }

  void _syncEngagementFromPost() {
    _liked = widget.post.liked;
    _likeCount = widget.post.likeCount;
    _commentCount = widget.post.commentCount;
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final profile = await profile_providers.currentUserRepository.load();
      if (mounted) setState(() => _currentUserId = profile.userId);
    } catch (_) {
      // Keep author-only actions hidden until the current account is known.
    }
  }

  Future<void> _deletePost() async {
    if (_isDeletingPost ||
        _currentUserId == null ||
        widget.post.userId != _currentUserId) {
      return;
    }
    if (!await confirmCommunityDelete(context, isPost: true) || !mounted) {
      return;
    }
    setState(() => _isDeletingPost = true);
    try {
      await _postRepository.deletePost(postId: widget.post.postId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(context, 'Unable to delete post. Please try again.')),
      ));
    } finally {
      if (mounted) setState(() => _isDeletingPost = false);
    }
  }

  Future<void> _editPost() async {
    if (_isEditingPost ||
        _isRefreshingPost ||
        _currentUserId == null ||
        _post.userId != _currentUserId) {
      return;
    }
    setState(() => _isEditingPost = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final update = await Navigator.of(context).push<UpdatePostInput>(
      MaterialPageRoute(
        builder: (_) => AddPost(
          editingPost: _post,
          postRepository: _postRepository,
        ),
      ),
    );
    if (!mounted) return;
    if (update == null) {
      setState(() => _isEditingPost = false);
      return;
    }
    final previousAttachments = {
      for (final attachment in _post.attachments)
        attachment.attachmentId: attachment,
    };
    setState(() {
      _post = _post.copyWith(
        category: update.category,
        title: update.title,
        body: update.body,
        editedAt: DateTime.now().toUtc().toIso8601String(),
        attachments: [
          for (final (position, id) in update.attachmentIds.indexed)
            PostAttachment(
              attachmentId: id,
              position: position,
              linkUrl: previousAttachments[id]?.linkUrl,
              mediaUrl: previousAttachments[id]?.mediaUrl,
              contentType: previousAttachments[id]?.contentType,
              byteSize: previousAttachments[id]?.byteSize,
            ),
        ],
      );
      _isEditingPost = false;
      _isRefreshingPost = true;
      _postRefreshFailed = false;
    });
    if (widget.onPostUpdated != null) {
      unawaited(widget.onPostUpdated!());
    }
    await _refreshUpdatedPost();
  }

  Future<void> _refreshUpdatedPost() async {
    if (!_isRefreshingPost) {
      setState(() {
        _isRefreshingPost = true;
        _postRefreshFailed = false;
      });
    }
    try {
      final repository = _postRepository;
      final Post updatedPost;
      if (repository is PostDetailRepository) {
        updatedPost =
            await (repository as PostDetailRepository).loadPost(_post.postId);
      } else {
        updatedPost = (await repository.loadPosts(teamId: _post.teamId))
            .firstWhere((post) => post.postId == _post.postId);
      }
      if (mounted) {
        setState(() {
          _post = updatedPost;
          _postRefreshFailed = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _postRefreshFailed = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(tr(context, 'Unable to load updated post. Please try again.')),
      ));
    } finally {
      if (mounted) setState(() => _isRefreshingPost = false);
    }
  }

  Future<void> _deleteComment(PostComment comment) async {
    if (_currentUserId == null ||
        comment.userId != _currentUserId ||
        comment.state != PostCommentState.active ||
        _deletingCommentIds.contains(comment.commentId)) {
      return;
    }
    if (!await confirmCommunityDelete(context, isPost: false) || !mounted) {
      return;
    }
    setState(() => _deletingCommentIds.add(comment.commentId));
    try {
      await _postCommentRepository.deleteComment(commentId: comment.commentId);
      if (!mounted) return;
      setState(() {
        if (_commentCount > 0) _commentCount--;
        if (_replyTarget?.commentId == comment.commentId) _replyTarget = null;
        if (_editingComment?.commentId == comment.commentId) {
          _editingComment = null;
        }
      });
      await _loadComments(showLoading: false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(tr(context, 'Unable to delete comment. Please try again.')),
      ));
    } finally {
      if (mounted) {
        setState(() => _deletingCommentIds.remove(comment.commentId));
      }
    }
  }

  void _editComment(PostComment comment) {
    if (_currentUserId == null ||
        comment.userId != _currentUserId ||
        comment.state != PostCommentState.active) {
      return;
    }
    setState(() {
      _replyTarget = null;
      _editingComment = comment;
    });
  }

  Future<void> _submitEditedComment(String body) async {
    final comment = _editingComment;
    if (comment == null) return;
    await _postCommentRepository.updateComment(
      commentId: comment.commentId,
      body: body,
    );
    if (!mounted) return;
    setState(() => _editingComment = null);
    await _loadComments(showLoading: false);
  }

  Future<void> _loadComments({bool showLoading = true}) async {
    final requestGeneration = ++_commentsRequestGeneration;
    if (showLoading && mounted) {
      setState(() {
        _commentsLoading = true;
        _commentsError = null;
      });
    }

    try {
      final comments = await _postCommentRepository.loadForPost(
        postId: widget.post.postId,
      );
      if (!mounted || requestGeneration != _commentsRequestGeneration) return;
      setState(() {
        _comments = comments;
        _commentsLoading = false;
        _commentsError = null;
      });
    } catch (error) {
      if (!mounted || requestGeneration != _commentsRequestGeneration) return;
      setState(() {
        _comments = const [];
        _commentsLoading = false;
        _commentsError = error;
      });
    }
  }

  Future<void> _togglePostLike() async {
    if (_isUpdatingLike) return;

    final previousLiked = _liked;
    final previousCount = _likeCount;
    final nextLiked = !previousLiked;
    setState(() {
      _isUpdatingLike = true;
      _liked = nextLiked;
      _likeCount = nextLiked
          ? previousCount + 1
          : (previousCount > 0 ? previousCount - 1 : 0);
    });

    var failed = false;
    try {
      await _postRepository.setPostLiked(
        postId: widget.post.postId,
        liked: nextLiked,
      );
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;

    setState(() {
      _isUpdatingLike = false;
      if (failed) {
        _liked = previousLiked;
        _likeCount = previousCount;
      }
    });
    if (failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(tr(context, 'Unable to update like. Please try again.')),
        ),
      );
    }
  }

  Future<void> _submitComment(String body) async {
    if (_isCreatingComment) return;
    final replyTarget = _replyTarget;
    setState(() => _isCreatingComment = true);

    try {
      await _postCommentRepository.createComment(
        postId: widget.post.postId,
        body: body,
        replyToId: replyTarget?.commentId,
      );
      if (!mounted) return;
      setState(() {
        _commentCount++;
        _replyTarget = null;
      });
      await _loadComments();
    } finally {
      if (mounted) setState(() => _isCreatingComment = false);
    }
  }

  @override
  void dispose() {
    _commentsRequestGeneration++;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 2. Calculate opacity (0.0 at top, 1.0 when scrolled down 150px)
    double opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);
    final post = _post;

    final pageBackground = mainPageBackground(context);
    final colors = Theme.of(context).colorScheme;

    return CommunityAccessBuilder(
      teamId: post.teamId,
      builder: (context, canParticipate) => Scaffold(
        backgroundColor: pageBackground,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController, // Bind the controller
              slivers: [
                SliverAppBar(
                  // 4. Fade AppBar background to black as you scroll
                  backgroundColor: Color.lerp(
                    Colors.transparent,
                    pageBackground,
                    opacityFactor,
                  ),
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: colors.onSurface,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  toolbarHeight: 80,
                  flexibleSpace: ColoredBox(color: pageBackground),
                  floating: true,
                  snap: true,
                ),
                PostDetailContent(
                  post: post,
                  liked: _liked,
                  likeCount: _likeCount,
                  commentCount: _commentCount,
                  onLike: !canParticipate || _isUpdatingLike
                      ? null
                      : _togglePostLike,
                  communityRepository: _communityRepository,
                  comments: _comments,
                  commentsLoading: _commentsLoading,
                  commentsError: _commentsError,
                  currentUserId: _currentUserId,
                  showMedia: !_isEditingPost,
                  mediaLoading: _isRefreshingPost,
                  mediaLoadFailed: _postRefreshFailed,
                  onRetryMedia: _refreshUpdatedPost,
                  onEditPost:
                      _isDeletingPost || _isEditingPost || _isRefreshingPost
                          ? null
                          : _editPost,
                  onDeletePost: _isDeletingPost ? null : _deletePost,
                  onEditComment: _editComment,
                  onDeleteComment: (comment) {
                    if (!_deletingCommentIds.contains(comment.commentId)) {
                      _deleteComment(comment);
                    }
                  },
                  onRetryComments: _loadComments,
                  onReply: !canParticipate || _isCreatingComment
                      ? null
                      : (comment) => setState(() {
                            _editingComment = null;
                            _replyTarget = comment;
                          }),
                  onReport: !canParticipate
                      ? null
                      : (reason) => _postRepository.reportPost(
                            postId: post.postId,
                            reason: reason,
                          ),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: canParticipate
            ? PostDetailReplyBar(
                replyTarget: _replyTarget,
                editingTarget: _editingComment,
                onCancelReply: () => setState(() => _replyTarget = null),
                onCancelEdit: () => setState(() => _editingComment = null),
                onSubmit: _editingComment == null
                    ? _submitComment
                    : _submitEditedComment,
              )
            : const CommunityReadOnlyNotice(),
      ),
    );
  }
}
