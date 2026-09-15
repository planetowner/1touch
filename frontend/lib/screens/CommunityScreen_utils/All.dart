import 'package:flutter/material.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/features/community/community_feed_widgets.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/screens/CommunityScreen_utils/GroundRules.dart';
import 'package:onetouch/screens/CommunityScreen_utils/PostScreen.dart';

class All extends StatelessWidget {
  const All({
    super.key,
    required this.posts,
    required this.postRepository,
    required this.selectedSort,
    required this.onSortChanged,
  });

  final List<Post> posts;
  final PostRepository postRepository;
  final PostSort selectedSort;
  final ValueChanged<PostSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: CommunitySortFilters(
            selectedSort: selectedSort,
            onChanged: onSortChanged,
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: CommunityGroundRulesCard(
            onTap: () => showGroundRulesModal(context),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: CommunityPostList(
            posts: posts,
            onPostTap: (post) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostDetailScreen(
                    post: post,
                    postRepository: postRepository,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
