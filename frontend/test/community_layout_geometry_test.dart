import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/SignComps/auth_widgets.dart';
import 'package:onetouch/core/app_action_button.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/features/community/community_feed_widgets.dart';
import 'package:onetouch/features/community/post_detail_content.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/post_comment.dart';
import 'support/stub_community_repository.dart';

void main() {
  tearDown(() => appLocaleController.value = const Locale('en'));

  for (final language in ['en', 'ko']) {
    testWidgets('$language shared buttons retain dimensions while submitting',
        (tester) async {
      appLocaleController.value = Locale(language);
      Future<void> render(bool loading) => tester.pumpWidget(MaterialApp(
            theme: darktheme,
            home: Scaffold(
                body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                AuthPrimaryButton(
                  label: 'Continue',
                  onPressed: () {},
                  loading: loading,
                  buttonKey: const ValueKey('auth'),
                ),
                AppActionButton(
                  label: language == 'ko' ? '게시' : 'POST',
                  onPressed: () {},
                  loading: loading,
                  buttonKey: const ValueKey('community'),
                ),
              ]),
            )),
          ));
      await render(false);
      final auth = tester.getRect(find.byKey(const ValueKey('auth')));
      final community = tester.getRect(find.byKey(const ValueKey('community')));
      expect(auth.height, 56);
      expect(
          community.height,
          inInclusiveRange(
              language == 'ko' ? 54 : 50, language == 'ko' ? 55 : 51));
      await render(true);
      expect(tester.getRect(find.byKey(const ValueKey('auth'))), auth);
      expect(
          tester.getRect(find.byKey(const ValueKey('community'))), community);
      expect(
          tester
              .widget<ButtonStyleButton>(
                  find.byKey(const ValueKey('community')))
              .onPressed,
          isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('right media follows the card width inside a narrower parent',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
          width: 260,
          child: CommunityPostCard(
            key: const ValueKey('card'),
            post: _post.copyWith(attachments: const [
              PostAttachment(
                attachmentId: 1,
                position: 0,
                contentType: 'image/png',
                mediaUrl: 'https://example.com/photo.png',
              )
            ]),
            onTap: () {},
          )),
    ))));
    final card = tester.getRect(find.byKey(const ValueKey('card')));
    final media = tester
        .getRect(find.byKey(const ValueKey('community-post-1-media-open')));
    expect(media.right, card.right);
    expect(media.top, card.top);
    expect(media.bottom, card.bottom);
    expect(media.width, closeTo(260 * 119 / 345, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('new comment groups and replies have distinct spacing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: darktheme,
        home: Scaffold(
            body: CustomScrollView(slivers: [
          PostDetailContent(
            post: _post,
            liked: false,
            likeCount: 0,
            commentCount: 3,
            onLike: null,
            communityRepository: const StubCommunityRepository(),
            comments: [_comment(1), _comment(2, replyTo: 1), _comment(3)],
            commentsLoading: false,
            commentsError: null,
            onRetryComments: () {},
            onReply: null,
            onReport: null,
          ),
        ]))));
    await tester.pumpAndSettle();
    Rect comment(int id) =>
        tester.getRect(find.byKey(ValueKey('community-comment-$id')));
    expect(comment(2).top - comment(1).bottom, 24);
    expect(comment(3).top - comment(2).bottom, 48);
    expect(comment(2).left - comment(1).left, 24);
    expect(tester.takeException(), isNull);
  });
}

const _post = Post(
    postId: 1,
    teamId: 9,
    language: 'en',
    userId: 8,
    category: PostCategory.general,
    title: 'Title',
    body: 'Body',
    createdAt: '2026-10-10T00:00:00Z',
    displayName: 'Username');
PostComment _comment(int id, {int? replyTo}) => PostComment(
    commentId: id,
    postId: 1,
    userId: 8,
    replyToId: replyTo,
    body: 'Comment body',
    createdAt: '2026-10-10T00:00:00Z',
    editedAt: null,
    state: PostCommentState.active,
    username: 'member',
    displayName: 'Username',
    avatarUrl: null,
    authorDeleted: false,
    likeCount: 0,
    liked: false);
