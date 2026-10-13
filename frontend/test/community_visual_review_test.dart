import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/profile/api/api_community_profile_repository.dart';
import 'package:onetouch/features/community/community_ban_dialog.dart';
import 'package:onetouch/features/community/community_delete_dialog.dart';
import 'package:onetouch/models/community_ban.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/comm_pages/profile_activity_screen.dart';
import 'package:onetouch/models/current_user_profile.dart';
import 'package:onetouch/models/profile_comment_activity.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/data/posts/post_draft_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/screens/CommunityScreen_utils/post_screen.dart';
import 'support/stub_post_comment_repository.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/post_comment.dart';
import 'package:onetouch/models/post_draft.dart';
import 'package:onetouch/screens/community_screen.dart';
import 'package:onetouch/screens/CommunityScreen_utils/add_post.dart';
import 'package:onetouch/screens/CommunityScreen_utils/ground_rules.dart';
import 'package:onetouch/screens/CommunityScreen_utils/report_dialog.dart';
import 'support/app_catalog.dart';
import 'support/stub_community_repository.dart';
import 'support/stub_profile_activity_repository.dart';
import 'support/fake_video_platform.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  setUpAppCatalog(favoriteTeamId: 9);
  testWidgets('community screens render at the 393px design width',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader('Archivo')
          ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf')))
        .load();
    await (FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'))
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final originalVideo = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = FakeVideoPlatform();
    addTearDown(() => VideoPlayerPlatform.instance = originalVideo);
    final boundary = GlobalKey();
    addTearDown(() => appLocaleController.value = const Locale('en'));
    late Future<void> Function(String) capture;
    Future<void> render(Widget screen, String name,
        {ThemeData? theme,
        Locale locale = const Locale('en'),
        double topInset = 47}) async {
      appLocaleController.value = locale;
      await tester.pumpWidget(MaterialApp(
          key: ValueKey(name),
          theme: theme ?? darktheme,
          locale: locale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          builder: (context, child) => RepaintBoundary(
              key: boundary,
              child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      padding: EdgeInsets.only(top: topInset, bottom: 34)),
                  child: child!)),
          home: screen));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(name);
    }

    // 캡처 저장은 검토할 때만 켜고, CI에서는 같은 화면의 레이아웃 오류를 확인해요.
    const output = String.fromEnvironment('COMMUNITY_CAPTURE_DIR');
    Future<void> save(String name) async {
      if (output.isEmpty) return;
      // SVG 파일을 읽는 비동기 작업이 끝난 뒤 캡처해요.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(output).create(recursive: true);
        await File('$output/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    capture = save;
    void expectCategoryVisible(String label) {
      final text = find.text(label);
      expect(text, findsOneWidget);
      // 표시 너비와 원래 글자 너비가 같아야 축소하거나 잘리지 않아요.
      expect(
          tester.getRect(text).width, closeTo(tester.getSize(text).width, .01));
      expect(tester.getSize(text).width, greaterThan(0));
    }

    await render(
        Community(
            teamId: 9,
            postRepository: MockPostRepository(posts: [_mediaPost, _post]),
            communityRepository: const StubCommunityRepository()),
        'feed');
    await render(
        Community(
            teamId: 9,
            postRepository: MockPostRepository(posts: [
              const Post(
                  postId: 1,
                  teamId: 9,
                  language: 'ko',
                  userId: 8,
                  category: PostCategory.general,
                  displayName: '리오넬 메시',
                  createdAt: '2026-10-08T00:00:00Z',
                  title: '[메시 인스타그램] 아르헨티나 대표팀 은퇴사',
                  body: 'https://www.instagram.com/p/example'),
            ]),
            communityRepository: const StubCommunityRepository()),
        'feed-light-ko',
        theme: whitetheme,
        locale: const Locale('ko'),
        topInset: 59);
    Widget detail(Post post) => PostDetailScreen(
        post: post,
        postRepository: MockPostRepository(posts: [post]),
        communityRepository: const StubCommunityRepository(),
        postCommentRepository: StubPostCommentRepository(
            comments: [_comment(1), _comment(2, reply: true)]));
    await render(detail(_post), 'detail');
    await render(detail(_mediaPost), 'detail-media');
    await tester.ensureVisible(
        find.byKey(const ValueKey('community-detail-media-open')));
    await tester.pumpAndSettle();
    await save('detail-media');
    await render(
        AddPost(
            teamId: 9,
            postRepository: MockPostRepository(),
            draftRepository: _Drafts()),
        'composer-empty');
    expectCategoryVisible('GENERAL');
    await tester.enterText(
        find.byKey(const ValueKey('community-post-title-input')), _post.title);
    await tester.enterText(
        find.byKey(const ValueKey('community-post-body-input')), _post.body);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await save('composer');
    await render(
        AddPost(
            teamId: 9,
            postRepository: MockPostRepository(),
            draftRepository: _Drafts()),
        'composer-light-ko',
        theme: whitetheme,
        locale: const Locale('ko'));
    expectCategoryVisible('자유');

    await render(
        ProfileActivityScreen(
            profile: CurrentUserProfile(
                userId: 8,
                username: 'member',
                displayName: 'Username',
                email: null,
                avatarUri: null,
                favoriteTeamId: 9,
                createdAt: DateTime.utc(2026)),
            repository: const _Activity()),
        'profile-posts');
    await tester
        .tap(find.byKey(const ValueKey('profile-activity-tab-comments')));
    await tester.pumpAndSettle();
    await save('profile-comments');
    await render(
        ProfileActivityScreen(
          userId: 8,
          repository: const _Activity(),
          publicProfileRepository: ApiCommunityProfileRepository(
              api: ApiClient(
            baseUri: Uri.parse('https://example.com/v1/'),
            requestHeaders: () => {},
            client: MockClient((request) async => http.Response(
                request.method == 'GET'
                    ? '{"user_id":8,"username":"member","display_name":"Username","is_self":false,"following":false}'
                    : '{"ok":true}',
                200)),
          )),
        ),
        'profile-follow');
    await tester.tap(find.byKey(const ValueKey('profile-activity-follow')));
    await tester.pumpAndSettle();
    await save('profile-following');
    await render(
        Scaffold(
            body: Builder(
                builder: (context) => Center(
                        child: CommunityAuthorMenu(
                      boundaryContext: context,
                      onEdit: () {},
                      onDelete: () {},
                    )))),
        'menu-background');
    await tester.tap(find.byType(CommunityAuthorMenu));
    await tester.pumpAndSettle();
    await save('author-menu');

    late BuildContext modalContext;
    await render(Builder(builder: (context) {
      modalContext = context;
      return const Scaffold();
    }), 'modal-background');
    showGroundRulesModal(modalContext,
        teamId: 9, repository: const StubCommunityRepository());
    await tester.pumpAndSettle();
    await save('rules');
    Navigator.pop(modalContext);
    await tester.pumpAndSettle();
    showReportDialog(modalContext, onSubmit: (_) async {});
    await tester.pumpAndSettle();
    await save('report');
    Navigator.pop(modalContext);
    await tester.pumpAndSettle();
    showThanksDialog(modalContext);
    await tester.pumpAndSettle();
    await save('thanks');
    Navigator.pop(modalContext);
    await tester.pumpAndSettle();
    final now = DateTime.utc(2026, 10, 10);
    showCommunityBanDialog(modalContext,
        ban: CommunityBanStatus(
            endsAt: now.add(const Duration(hours: 1, minutes: 23, seconds: 45)),
            reason: CommunityBanReason.spam),
        now: () => now);
    await tester.pumpAndSettle();
    await save('ban');
    Navigator.pop(modalContext);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

const _post = Post(
    postId: 1,
    teamId: 9,
    language: 'en',
    userId: 8,
    category: PostCategory.general,
    title: 'Title goes here',
    body:
        "FC Barcelona is more than just a football club; it's a symbol of passion and pride for its fans. The team's style of play, known as 'tiki-taka', showcases their commitment to teamwork and skill. With a rich history of success, including numerous La Liga and Champions League titles, Barcelona continues to inspire young athletes around the world.",
    createdAt: '2026-10-10T00:00:00Z',
    editedAt: '2026-10-10T01:00:00Z',
    commentCount: 2,
    displayName: 'Username');
PostComment _comment(int id, {bool reply = false}) => PostComment(
    commentId: id,
    postId: 1,
    userId: 8,
    replyToId: reply ? 1 : null,
    body:
        'First sentence goes here. Second sentence goes here. Third sentence goes here.',
    createdAt: '2026-10-10T00:00:00Z',
    editedAt: id == 1 ? '2026-10-10T01:00:00Z' : null,
    state: PostCommentState.active,
    username: 'member',
    displayName: 'Username',
    avatarUrl: null,
    authorDeleted: false,
    likeCount: 0,
    liked: false);

class _Drafts implements PostDraftRepository {
  @override
  Future<List<PostDraft>> loadDrafts({int limit = 50, int offset = 0}) async =>
      [
        PostDraft(
            postId: 41,
            teamId: 9,
            language: 'en',
            category: PostCategory.general,
            title: 'Saved',
            body: 'Saved',
            attachments: [],
            expiresAt: DateTime.utc(2026, 10, 17))
      ];
  @override
  Future<PostDraft> saveDraft(CreatePostInput input, {int? postId}) =>
      throw UnimplementedError();
  @override
  Future<int> publishDraft(int postId) => throw UnimplementedError();

  @override
  Future<void> deleteDraft(int postId) => throw UnimplementedError();
}

class _Activity extends StubProfileActivityRepository {
  const _Activity();
  @override
  Future<List<Post>> loadPosts({int limit = 50, int offset = 0}) async =>
      [_post, _post];
  @override
  Future<List<ProfileCommentActivity>> loadComments(
          {int limit = 50, int offset = 0}) async =>
      [ProfileCommentActivity(post: _post, comment: _comment(1))];
}

final _mediaPost = _post.copyWith(attachments: [
  for (var id = 1; id <= 3; id++)
    PostAttachment(
        attachmentId: id,
        position: id - 1,
        mediaUrl: 'https://example.com/v1/attachments/$id/content',
        contentType: 'video/mp4')
]);
