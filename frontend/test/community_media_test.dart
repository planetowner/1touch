import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/api_image_headers.dart';
import 'package:onetouch/features/community/community_attachment_viewer.dart';
import 'package:onetouch/features/community/community_feed_widgets.dart';
import 'package:onetouch/features/community/post_detail_content.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/post_comment.dart';
import 'package:share_plus/share_plus.dart';
import 'support/stub_community_repository.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets('post blank space opens the post at width $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var opens = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CommunityPostList(
            posts: [
              Post(
                postId: 8,
                teamId: 9,
                userId: 1,
                category: PostCategory.general,
                title: 'Short title',
                body: 'Short body',
                createdAt: '2026-09-27T12:00:00Z',
              ),
            ],
            onPostTap: (_) => opens++,
          ),
        ),
      ));

      final card = find
          .ancestor(
            of: find.text('Short title'),
            matching: find.byType(GestureDetector),
          )
          .first;
      final bounds = tester.getRect(card);
      await tester.tapAt(Offset(bounds.right - 8, bounds.top + 42));
      expect(opens, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('post link opens the post at width $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var opens = 0;
      const body = 'Read https://example.com/path';
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CommunityPostList(
            posts: [
              Post(
                postId: 8,
                teamId: 9,
                userId: 1,
                category: PostCategory.general,
                title: 'Link post',
                body: body,
                createdAt: '2026-09-27T12:00:00Z',
              ),
            ],
            onPostTap: (_) => opens++,
          ),
        ),
      ));

      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text(body), matching: find.byType(RichText)),
      );
      final urlStart = body.indexOf('https://');
      final linkBounds = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: urlStart, extentOffset: urlStart + 5),
          )
          .first;
      await tester.tapAt(paragraph.localToGlobal(linkBounds.toRect().center));
      expect(opens, 1);
      expect(tester.takeException(), isNull);
    });
  }

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
    var openedPosts = 0;

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
            onPostTap: (_) => openedPosts++,
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
    expect(find.byType(InteractiveViewer), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('community-attachment-close')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('community-attachment-viewer')),
      findsNothing,
    );
    expect(openedPosts, 0);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets(
        'attachment stays centered while pinching and dragging at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(
        home: CommunityAttachmentViewer(
          mediaUrl: 'https://example.com/photo.jpg',
        ),
      ));
      await tester.pump();

      final image =
          find.byKey(const ValueKey('community-attachment-full-image'));
      final transform =
          find.byKey(const ValueKey('community-attachment-image-transform'));
      final imageWidget = tester.widget<Image>(image);
      expect(imageWidget.fit, BoxFit.contain);
      expect(tester.getSize(image), size);
      expect(
          tester.widget<Transform>(transform).transform.getMaxScaleOnAxis(), 1);

      final center = size.center(Offset.zero);
      final left =
          await tester.startGesture(center + const Offset(-40, 0), pointer: 1);
      final right =
          await tester.startGesture(center + const Offset(40, 0), pointer: 2);
      await left.moveBy(const Offset(-40, 0));
      await right.moveBy(const Offset(40, 0));
      await tester.pump();
      final zoomedScale =
          tester.widget<Transform>(transform).transform.getMaxScaleOnAxis();
      expect(zoomedScale, greaterThan(1));
      expect(tester.getCenter(image), center);
      await left.up();
      await right.up();

      final drag = await tester.startGesture(center, pointer: 3);
      await drag.moveBy(const Offset(70, 60));
      await drag.up();
      await tester.pump();
      expect(tester.widget<Transform>(transform).transform.getMaxScaleOnAxis(),
          closeTo(zoomedScale, 0.001));
      expect(tester.getCenter(image), center);

      final inwardLeft =
          await tester.startGesture(center + const Offset(-80, 0), pointer: 4);
      final inwardRight =
          await tester.startGesture(center + const Offset(80, 0), pointer: 5);
      await inwardLeft.moveBy(const Offset(40, 0));
      await inwardRight.moveBy(const Offset(-40, 0));
      await tester.pump();
      final reducedScale =
          tester.widget<Transform>(transform).transform.getMaxScaleOnAxis();
      expect(reducedScale, lessThan(zoomedScale));
      expect(reducedScale, greaterThanOrEqualTo(1));
      expect(tester.getCenter(image), center);
      await inwardLeft.up();
      await inwardRight.up();
    });
  }

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

    expect(sharedParams?.title, '1touch');
    expect(sharedParams?.subject, post.title);
    expect(
        sharedParams?.uri, Uri.parse('https://1touch.football/community/12'));
    expect(sharedParams?.text, isNull);
    expect(sharedParams?.sharePositionOrigin, isNotNull);
    expect(sharedParams!.sharePositionOrigin!.isEmpty, isFalse);
    expect(tester.takeException(), isNull);
  });
}
