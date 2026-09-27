import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/api_image_headers.dart';
import 'package:onetouch/features/community/community_feed_widgets.dart';
import 'package:onetouch/features/community/post_detail_content.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/post_comment.dart';
import 'package:share_plus/share_plus.dart';
import 'support/stub_community_repository.dart';

void main() {
  testWidgets('community media sends auth to the API attachment endpoint',
      (tester) async {
    final previousToken = authSession.accessToken;
    authSession.establish('community-media-token');
    addTearDown(() {
      authSession.clear();
      if (previousToken != null) authSession.establish(previousToken);
    });
    final mediaUrl =
        apiClient.baseUri.resolve('attachments/7/content').toString();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityPostList(
            posts: [
              Post(
                postId: 7,
                teamId: 9,
                userId: 1,
                category: PostCategory.general,
                title: 'Photo post',
                body: 'Attached photo',
                mediaUrl: mediaUrl,
                createdAt: '2026-09-27T12:00:00Z',
              ),
            ],
            onPostTap: (_) {},
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('community-post-7-media')),
    );
    final provider = image.image as NetworkImage;
    expect(
      provider.headers,
      const {'Authorization': 'Bearer community-media-token'},
    );

    await tester.tap(
      find.byKey(const ValueKey('community-post-7-media-open')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('community-attachment-viewer')),
      findsOneWidget,
    );
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('community-attachment-close')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('community-attachment-viewer')),
      findsNothing,
    );
  });

  test('does not send the session token to an external media host', () {
    final previousToken = authSession.accessToken;
    authSession.establish('private-token');
    addTearDown(() {
      authSession.clear();
      if (previousToken != null) authSession.establish(previousToken);
    });

    expect(apiImageHeaders('https://images.example.org/photo.jpg'), isNull);
  });

  testWidgets('community comment avatars authenticate API image requests',
      (tester) async {
    final previousToken = authSession.accessToken;
    authSession.establish('avatar-token');
    addTearDown(() {
      authSession.clear();
      if (previousToken != null) authSession.establish(previousToken);
    });
    final avatarUrl = apiClient.baseUri.resolve('users/1/avatar').toString();
    const post = Post(
      postId: 12,
      teamId: 9,
      userId: 1,
      category: PostCategory.general,
      title: 'Post',
      body: 'Body',
      createdAt: '2026-09-27T12:00:00Z',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              PostDetailContent(
                post: post,
                liked: false,
                likeCount: 0,
                commentCount: 1,
                onLike: null,
                communityRepository: const StubCommunityRepository(),
                comments: [
                  PostComment(
                    commentId: 5,
                    postId: 12,
                    userId: 1,
                    replyToId: null,
                    body: 'Comment',
                    createdAt: '2026-09-27T12:01:00Z',
                    editedAt: null,
                    state: PostCommentState.active,
                    username: 'supporter',
                    avatarUrl: avatarUrl,
                    authorDeleted: false,
                    likeCount: 0,
                    liked: false,
                  ),
                ],
                commentsLoading: false,
                commentsError: null,
                onRetryComments: () {},
                onReply: null,
                onReport: null,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final avatar = tester.widget<CircleAvatar>(
      find.byKey(const ValueKey('community-comment-avatar-5')),
    );
    final provider = avatar.backgroundImage! as NetworkImage;
    expect(provider.headers, const {'Authorization': 'Bearer avatar-token'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('post share opens the native share client with post content',
      (tester) async {
    ShareParams? sharedParams;
    const post = Post(
      postId: 12,
      teamId: 9,
      userId: 1,
      category: PostCategory.general,
      title: 'Match reaction',
      body: 'A community post worth sharing.',
      createdAt: '2026-09-27T12:00:00Z',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              PostDetailContent(
                post: post,
                liked: false,
                likeCount: 0,
                commentCount: 0,
                onLike: null,
                communityRepository: const StubCommunityRepository(),
                comments: const [],
                commentsLoading: false,
                commentsError: null,
                onRetryComments: () {},
                onReply: null,
                onReport: null,
                shareInvoker: (params) async {
                  sharedParams = params;
                  return ShareResult.unavailable;
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('community-detail-share-action')),
    );
    await tester.pump();

    expect(sharedParams?.title, '1Touch');
    expect(sharedParams?.subject, post.title);
    expect(sharedParams?.text, '${post.title}\n\n${post.body}');
    expect(sharedParams?.sharePositionOrigin, isNotNull);
    expect(sharedParams!.sharePositionOrigin!.isEmpty, isFalse);
    expect(tester.takeException(), isNull);
  });
}
