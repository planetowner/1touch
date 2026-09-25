import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/community/community_repository.dart';
import 'package:onetouch/data/community/community_repository_provider.dart'
    as community_providers;
import 'package:onetouch/data/post_comments/post_comment_repository.dart';
import 'package:onetouch/data/post_comments/post_comment_repository_provider.dart'
    as comment_providers;
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/data/posts/post_repository_provider.dart'
    as post_providers;
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

  const PostDetailScreen({
    super.key,
    required this.post,
    this.postRepository,
    this.communityRepository,
    this.postCommentRepository,
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
  List<PostComment> _comments = const [];
  bool _commentsLoading = true;
  Object? _commentsError;
  int _commentsRequestGeneration = 0;

  PostRepository get _postRepository =>
      widget.postRepository ?? post_providers.postRepository;

  CommunityRepository get _communityRepository =>
      widget.communityRepository ?? community_providers.communityRepository;

  PostCommentRepository get _postCommentRepository =>
      widget.postCommentRepository ?? comment_providers.postCommentRepository;

  @override
  void initState() {
    super.initState();
    _syncEngagementFromPost();
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
    if (widget.post.postId != oldWidget.post.postId) {
      _syncEngagementFromPost();
      _isUpdatingLike = false;
      _isCreatingComment = false;
      _replyTarget = null;
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
    final post = widget.post;

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
                  onRetryComments: _loadComments,
                  onReply: !canParticipate || _isCreatingComment
                      ? null
                      : (comment) => setState(() => _replyTarget = comment),
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
                onCancelReply: () => setState(() => _replyTarget = null),
                onSubmit: _submitComment,
              )
            : const CommunityReadOnlyNotice(),
      ),
    );
  }
}
