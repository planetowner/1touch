import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/community/community_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/screens/CommunityScreen_utils/All.dart';

class CommunityPostBody extends StatelessWidget {
  const CommunityPostBody({
    super.key,
    required this.teamId,
    required this.posts,
    required this.postRepository,
    required this.communityRepository,
    required this.selectedSort,
    required this.isLoading,
    required this.loadError,
    required this.onRetry,
    required this.onPostDetailClosed,
    required this.onSortChanged,
  });

  final int teamId;
  final List<Post> posts;
  final PostRepository postRepository;
  final CommunityRepository communityRepository;
  final PostSort selectedSort;
  final bool isLoading;
  final Object? loadError;
  final VoidCallback onRetry;
  final Future<void> Function() onPostDetailClosed;
  final ValueChanged<PostSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          key: ValueKey('community-posts-loading'),
        ),
      );
    }
    if (loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Unable to load community posts.',
                style: Body1.style,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const ValueKey('community-posts-retry'),
                onPressed: onRetry,
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }
    return All(
      teamId: teamId,
      posts: posts,
      postRepository: postRepository,
      communityRepository: communityRepository,
      selectedSort: selectedSort,
      onPostDetailClosed: onPostDetailClosed,
      onSortChanged: onSortChanged,
    );
  }
}
