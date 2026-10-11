import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/comm_pages/profile_activity_screen.dart';
import 'package:onetouch/data/posts/api/api_post_draft_repository.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/data/posts/post_draft_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/data/post_comments/api/api_post_comment_repository.dart';
import 'package:onetouch/data/profile/api/api_community_profile_repository.dart';
import 'package:onetouch/features/community/community_feed_widgets.dart';
import 'package:onetouch/features/community/community_attachment_viewer.dart';
import 'package:onetouch/features/community/post_detail_content.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/post_comment.dart';
import 'package:onetouch/models/post_draft.dart';
import 'package:onetouch/screens/CommunityScreen_utils/add_post.dart';
import 'support/stub_community_repository.dart';
import 'support/stub_profile_activity_repository.dart';

ApiClient api(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
        client: MockClient(handler),
        baseUri: Uri.parse('https://example.com/v1/'),
        requestHeaders: () => {'Authorization': 'Bearer test-session'});

void main() {
  test('draft save retains ownership context and publish uses the saved ID',
      () async {
    final requests = <http.Request>[];
    final repository = ApiPostDraftRepository(api: api((request) async {
      requests.add(request);
      expect(request.headers['Authorization'], 'Bearer test-session');
      if (request.url.path.endsWith('/publish')) {
        return http.Response('{"post_id":41}', 200);
      }
      return http.Response(
          jsonEncode(request.method == 'GET'
              ? {
                  'items': [_draftJson]
                }
              : _draftJson),
          request.method == 'POST' ? 201 : 200);
    }));
    final drafts = await repository.loadDrafts();
    expect(drafts.single.attachments.single.mediaUrl,
        'https://example.com/v1/attachments/2/content');
    final input = CreatePostInput(
        teamId: 6,
        language: 'ko',
        category: PostCategory.analysis,
        title: '',
        body: '',
        attachmentIds: [2]);
    await repository.saveDraft(input);
    await repository.saveDraft(input, postId: 41);
    expect(await repository.publishDraft(41), 41);
    expect(jsonDecode(requests[1].body), {
      'team_id': 6,
      'language': 'ko',
      'category': 'analysis',
      'title': '',
      'body': '',
      'attachment_ids': [2]
    });
    expect(jsonDecode(requests[2].body), {
      'category': 'analysis',
      'title': '',
      'body': '',
      'attachment_ids': [2]
    });
    expect(requests[2].url.path, '/v1/post-drafts/41');
    expect(requests[3].url.path, '/v1/post-drafts/41/publish');
  });

  test('comment like, unlike and report use authenticated comment endpoints',
      () async {
    final calls = <String>[];
    var invalidations = 0;
    final repository = ApiPostCommentRepository(api: api((request) async {
      calls.add('${request.method} ${request.url.path}');
      expect(request.headers['Authorization'], 'Bearer test-session');
      if (request.method == 'POST') {
        expect(jsonDecode(request.body), {'reason': 'Spam'});
      }
      return http.Response('{"ok":true}', 200);
    }), onMutation: () async {
      invalidations++;
    });
    await repository.setCommentLiked(commentId: 12, liked: true);
    await repository.setCommentLiked(commentId: 12, liked: false);
    await repository.reportComment(commentId: 12, reason: 'Spam');
    expect(calls, [
      'PUT /v1/comments/12/like',
      'DELETE /v1/comments/12/like',
      'POST /v1/comments/12/report'
    ]);
    expect(invalidations, 2);
  });

  testWidgets(
      'a saved draft resumes with attachments and publishes without creating another post',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final drafts = _Drafts();
    await tester.pumpWidget(MaterialApp(
        theme: darktheme,
        home: AddPost(
            teamId: 6,
            postRepository: MockPostRepository(),
            draftRepository: drafts)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-resume-draft')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved title'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(
                find.byKey(const ValueKey('community-post-title-input')))
            .controller!
            .text,
        'Saved title');
    expect(find.byKey(const ValueKey('community-existing-attachment-remove-0')),
        findsOneWidget);
    await tester
        .ensureVisible(find.byKey(const ValueKey('community-post-submit')));
    await tester.tap(find.byKey(const ValueKey('community-post-submit')));
    await tester.pumpAndSettle();
    expect(drafts.savedId, 41);
    expect(drafts.saved?.attachmentIds, [2]);
    expect(drafts.publishedId, 41);
  });

  testWidgets('multiple media thumbnail and count badge open the post',
      (tester) async {
    var opens = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body:
                CommunityPostList(posts: [_post], onPostTap: (_) => opens++))));
    await tester.pumpAndSettle();
    expect(find.text('+2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('community-post-1-media-open')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityAttachmentViewer), findsNothing);
    expect(opens, 1);
    await tester.tap(find.text('+2'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityAttachmentViewer), findsNothing);
    expect(opens, 2);
  });

  testWidgets(
      'deleted comments retain author and time while active comments expose like and report',
      (tester) async {
    var liked = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CustomScrollView(slivers: [
      PostDetailContent(
          post: _post.copyWith(
              state: PostState.deleted, title: '', body: '', attachments: []),
          liked: false,
          likeCount: 2,
          commentCount: 1,
          onLike: null,
          communityRepository: const StubCommunityRepository(),
          comments: [
            _comment(PostCommentState.deleted, 1),
            _comment(PostCommentState.active, 2)
          ],
          commentsLoading: false,
          commentsError: null,
          onRetryComments: () {},
          onReply: null,
          onReport: null,
          currentUserId: 1,
          onLikeComment: (_) => liked++,
          onReportComment: (_, __) async {}),
    ]))));
    await tester.pumpAndSettle();
    expect(find.text('This post was deleted.'), findsOneWidget);
    await tester
        .ensureVisible(find.byKey(const ValueKey('community-comment-1')));
    expect(find.text('This comment was deleted.'), findsOneWidget);
    expect(find.text('Member'), findsWidgets);
    expect(
        find.byKey(const ValueKey('community-comment-like-1')), findsNothing);
    final like = find.byKey(const ValueKey('community-comment-like-2'));
    await tester.ensureVisible(like);
    await tester.tap(like);
    expect(liked, 1);
    await tester.tap(find.byKey(const ValueKey('community-comment-menu-2')));
    await tester.pumpAndSettle();
    expect(find.text('Copy Text'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets(
      'another member profile toggles Follow without showing own camera',
      (tester) async {
    final calls = <String>[];
    final publicProfiles =
        ApiCommunityProfileRepository(api: api((request) async {
      calls.add(request.method);
      return http.Response(
          request.method == 'GET'
              ? '{"user_id":8,"username":"member","display_name":"Member","avatar_url":null,"is_self":false,"following":false}'
              : '{"ok":true}',
          200);
    }));
    await tester.pumpWidget(MaterialApp(
        theme: darktheme,
        home: ProfileActivityScreen(
            userId: 8,
            repository: const StubProfileActivityRepository(),
            publicProfileRepository: publicProfiles)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-activity-camera')), findsNothing);
    expect(find.text('FOLLOW'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-activity-follow')));
    await tester.pumpAndSettle();
    expect(find.text('FOLLOWING'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-activity-follow')));
    await tester.pumpAndSettle();
    expect(calls, ['GET', 'PUT', 'DELETE']);
  });
}

final _draftJson = {
  'post_id': 41,
  'team_id': 6,
  'language': 'en',
  'category': 'general',
  'title': 'Saved title',
  'body': 'Saved body',
  'expires_at': '2026-10-17T00:00:00Z',
  'attachments': [
    {
      'attachment_id': 2,
      'position': 0,
      'link_url': null,
      'media_url': '/v1/attachments/2/content',
      'preview_url': null,
      'content_type': 'image/png',
      'byte_size': 24
    }
  ]
};
final _post = Post(
    postId: 1,
    teamId: 6,
    language: 'en',
    userId: 8,
    category: PostCategory.general,
    title: 'Post title',
    body: 'Body text',
    createdAt: '2026-10-01T00:00:00Z',
    displayName: 'Member',
    attachments: [
      for (var id = 1; id <= 3; id++)
        PostAttachment(
            attachmentId: id,
            position: id - 1,
            mediaUrl: 'https://example.com/$id.png',
            contentType: 'image/png')
    ]);
PostComment _comment(PostCommentState state, int id) => PostComment(
    commentId: id,
    postId: 1,
    userId: 8,
    replyToId: null,
    body: state == PostCommentState.deleted ? '' : 'Comment body',
    createdAt: '2026-10-01T00:00:00Z',
    editedAt: null,
    state: state,
    username: 'member',
    displayName: 'Member',
    avatarUrl: null,
    authorDeleted: false,
    likeCount: 2,
    liked: false);

class _Drafts implements PostDraftRepository {
  CreatePostInput? saved;
  int? savedId, publishedId;
  final draft = PostDraft(
      postId: 41,
      teamId: 6,
      language: 'en',
      category: PostCategory.general,
      title: 'Saved title',
      body: 'Saved body',
      expiresAt: DateTime.utc(2026, 10, 17),
      attachments: const [
        PostAttachment(
            attachmentId: 2,
            position: 0,
            mediaUrl: 'https://example.com/image.png',
            contentType: 'image/png')
      ]);
  @override
  Future<List<PostDraft>> loadDrafts({int limit = 50, int offset = 0}) async =>
      [draft];
  @override
  Future<PostDraft> saveDraft(CreatePostInput input, {int? postId}) async {
    saved = input;
    savedId = postId;
    return draft;
  }

  @override
  Future<int> publishDraft(int postId) async {
    publishedId = postId;
    return postId;
  }
}
