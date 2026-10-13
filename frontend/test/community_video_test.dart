import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/features/community/community_attachment_viewer.dart';
import 'package:onetouch/features/community/community_feed_widgets.dart';
import 'package:onetouch/features/community/community_media.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
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

  testWidgets('video shows the football while preparing or buffering',
      (tester) async {
    video = FakeVideoPlatform(autoInitialize: false);
    VideoPlayerPlatform.instance = video;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 100,
                height: 100,
                child: CommunityVideo(url: _attachment(1).mediaUrl!)))));
    await tester.pump();
    expect(find.byType(FootballLoadingIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    video.streams[0]!.add(VideoEvent(
        eventType: VideoEventType.initialized,
        size: const Size(292, 292),
        duration: const Duration(seconds: 8)));
    await tester.pumpAndSettle();
    expect(find.byType(FootballLoadingIndicator), findsNothing);

    video.streams[0]!.add(VideoEvent(eventType: VideoEventType.bufferingStart));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FootballLoadingIndicator), findsOneWidget);

    video.streams[0]!.add(VideoEvent(eventType: VideoEventType.bufferingEnd));
    await tester.pumpAndSettle();
    expect(find.byType(FootballLoadingIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 640), const Size(430, 932)]) {
    testWidgets('viewer overlays playback and progress on video at $size',
        (tester) async {
      video = FakeVideoPlatform(autoInitialize: false);
      VideoPlayerPlatform.instance = video;
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final attachment = _attachment(1);
      await tester.pumpWidget(MaterialApp(
          home: CommunityAttachmentViewer(
              mediaUrl: attachment.mediaUrl!, attachments: [attachment])));
      await tester.pump();
      video.streams[0]!.add(VideoEvent(
          eventType: VideoEventType.initialized,
          size: const Size(900, 1600),
          duration: const Duration(seconds: 8)));
      await tester.pumpAndSettle();

      final videoFinder = find.byType(CommunityVideo);
      final progressFinder =
          find.byKey(const ValueKey('community-video-progress'));
      final videoSize = tester.getSize(videoFinder);
      expect(videoSize.width / videoSize.height, closeTo(9 / 16, 0.001));
      expect(videoSize.width, lessThanOrEqualTo(size.width - 48));
      expect(videoSize.height, lessThanOrEqualTo(size.height - 50));
      expect(find.byKey(const ValueKey('community-video-play-overlay')),
          findsOneWidget);
      expect(progressFinder, findsOneWidget);
      expect(tester.getRect(progressFinder).bottom,
          closeTo(tester.getRect(videoFinder).bottom, 0.01));
      expect(tester.getSize(progressFinder).height, lessThanOrEqualTo(20));
      expect(find.byType(IconButton), findsNothing);

      await tester.tapAt(tester.getCenter(videoFinder));
      await tester.pump();
      expect(video.playing, contains(0));
      expect(find.byKey(const ValueKey('community-video-play-overlay')),
          findsNothing);

      await tester.tapAt(tester.getCenter(videoFinder));
      await tester.pump();
      expect(video.playing, isEmpty);
      expect(find.byKey(const ValueKey('community-video-play-overlay')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final fullScreen in [false, true]) {
    testWidgets(
        'video load failure stays silent outside detail, fullScreen: $fullScreen',
        (tester) async {
      VideoPlayerPlatform.instance = FakeVideoPlatform(
          initializationError: PlatformException(
              code: 'VideoError', message: 'Video loading failed'));
      final attachment = _attachment(1);
      await tester.pumpWidget(MaterialApp(
          home: fullScreen
              ? CommunityAttachmentViewer(
                  mediaUrl: attachment.mediaUrl!, attachments: [attachment])
              : Scaffold(
                  body: SizedBox(
                      width: 119,
                      height: 148,
                      child: CommunityMediaPreview(attachment: attachment)))));
      await tester.pumpAndSettle();
      expect(find.text('Unable to load video.'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('detail reports failure only when a video is opened',
      (tester) async {
    VideoPlayerPlatform.instance = FakeVideoPlatform(
        initializationError: PlatformException(
            code: 'VideoError', message: 'Video loading failed'));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 345,
                child: CommunityMediaGrid(attachments: [
                  for (var id = 1; id <= 3; id++) _attachment(id)
                ])))));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load video.'), findsNothing);
    for (final key in [
      'community-detail-media-open',
      'community-detail-media-open-1',
      'community-detail-media-open-2',
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityAttachmentViewer), findsNothing);
      expect(find.text('Unable to load video.'), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('app-rule-notice-close')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    await tester.tap(find.byKey(const ValueKey('community-detail-media-open')));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load video.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-rule-notice-close')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening a ready video does not carry a detail error fullscreen',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 345,
                child: CommunityMediaGrid(
                    attachments: [_attachment(1), _attachment(2)])))));
    await tester.pumpAndSettle();
    video.streams[0]!.addError(
        PlatformException(code: 'VideoError', message: 'Video loading failed'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-detail-media-open')));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load video.'), findsOneWidget);
    await tester
        .tap(find.byKey(const ValueKey('community-detail-media-open-1')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityAttachmentViewer), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('Unable to load video.'), findsNothing);
    expect(video.playing, isEmpty);
    expect(tester.takeException(), isNull);
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
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pump();
    expect(video.playing, {0});
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
    expect(video.playing, isEmpty);
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
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
