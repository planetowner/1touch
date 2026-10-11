import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/features/community/community_attachment_viewer.dart';
import 'package:onetouch/features/community/community_feed_widgets.dart';
import 'package:onetouch/features/community/community_media.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'package:onetouch/models/post.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'support/fake_video_platform.dart';

void main() {
  late FakeVideoPlatform video;
  setUp(() {
    final original = VideoPlayerPlatform.instance;
    video = FakeVideoPlatform();
    VideoPlayerPlatform.instance = video;
    addTearDown(() => VideoPlayerPlatform.instance = original);
  });

  testWidgets(
      'gallery authenticates videos and pauses when leaving a page or the app',
      (tester) async {
    final token = authSession.accessToken;
    authSession.establish('community-video-token');
    addTearDown(() {
      authSession.clear();
      if (token != null) authSession.establish(token);
    });
    final attachments = [for (var id = 1; id <= 2; id++) _attachment(id)];
    await tester.pumpWidget(MaterialApp(
        home: CommunityAttachmentViewer(
            mediaUrl: attachments.first.mediaUrl!, attachments: attachments)));
    await tester.pumpAndSettle();
    expect(video.playing, isEmpty);
    expect(video.sources.first.httpHeaders['Authorization'],
        'Bearer community-video-token');
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(video.playing, {0});
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(video.playing, isEmpty);
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(video.playing, {1});
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(video.playing, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    // 플랫폼 해제는 위젯 제거 뒤 비동기로 끝나요.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(video.disposed, {0, 1});
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'feed video play overlay opens the post without opening or playing media',
      (tester) async {
    var openedPosts = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CommunityPostList(posts: [
      Post(
          language: 'en',
          postId: 1,
          teamId: 83,
          userId: 1,
          category: PostCategory.general,
          title: 'Video post',
          body: 'Post body',
          createdAt: '2026-10-06T12:00:00Z',
          attachments: [_attachment(1)]),
    ], onPostTap: (_) => openedPosts++))));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate(
        (widget) => widget is CommunityIcon && widget.name == 'play'));
    await tester.pumpAndSettle();
    expect(openedPosts, 1);
    expect(find.byType(CommunityAttachmentViewer), findsNothing);
    expect(video.playing, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reused feed previews replace the video when the attachment changes',
      (tester) async {
    Widget preview(int id) => MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 119,
                height: 148,
                child: CommunityMediaPreview(attachment: _attachment(id)))));
    await tester.pumpWidget(preview(1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(preview(2));
    await tester.pumpAndSettle();
    expect(video.sources.map((source) => source.uri),
        [_attachment(1).mediaUrl, _attachment(2).mediaUrl]);
    // 플랫폼 해제는 위젯 제거 뒤 비동기로 끝나요.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(video.disposed, {0});
    expect(video.playing, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    // 플랫폼 해제는 위젯 제거 뒤 비동기로 끝나요.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(video.disposed, {0, 1});
  });
}

PostAttachment _attachment(int id) => PostAttachment(
    attachmentId: id,
    position: id - 1,
    mediaUrl: apiClient.baseUri.resolve('attachments/$id/content').toString(),
    contentType: 'video/mp4');
