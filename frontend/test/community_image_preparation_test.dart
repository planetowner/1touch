import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/injuries/api/api_team_injury_repository.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/data/transfers/mock/mock_transfer_repository.dart';
import 'package:onetouch/features/community/community_feed_widgets.dart';
import 'package:onetouch/features/media/selected_team_media_preloader.dart';
import 'package:onetouch/features/community/community_post_image.dart';
import 'package:onetouch/features/community/post_detail_content.dart';
import 'package:onetouch/models/post.dart';

import 'support/stub_community_repository.dart';

void main() {
  testWidgets(
      'prepares before tab entry and keeps the photo through detail and zoom',
      (tester) async {
    final previewBytes = (await tester.runAsync(() => _png(40, 30)))!;
    final originalBytes = (await tester.runAsync(() => _png(400, 300)))!;
    final previewRequested = Completer<void>();
    final originalRequested = Completer<void>();
    final releaseOriginal = Completer<void>();
    final requests = <String, int>{};
    final client = _PhotoHttpClient((uri) {
      final path = uri.path;
      requests.update(path, (count) => count + 1, ifAbsent: () => 1);
      final isPreview = path.endsWith('/preview');
      if (isPreview) {
        if (!previewRequested.isCompleted) previewRequested.complete();
      } else {
        if (!originalRequested.isCompleted) originalRequested.complete();
      }
      return isPreview
          ? Future.value(_PhotoResponse(previewBytes))
          : releaseOriginal.future.then((_) => _PhotoResponse(originalBytes));
    });
    debugNetworkImageHttpClientProvider = () => client;
    final showFeed = ValueNotifier(false);
    addTearDown(() async {
      if (!releaseOriginal.isCompleted) releaseOriginal.complete();
      debugNetworkImageHttpClientProvider = null;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      showFeed.dispose();
    });
    const original = 'https://images.example.test/attachments/9/content';
    const preview = 'https://images.example.test/attachments/9/preview';
    final post = Post(
      postId: 9,
      teamId: 83,
      userId: 1,
      category: PostCategory.general,
      title: 'Photo post',
      body: 'Post body',
      mediaUrl: original,
      createdAt: '2026-10-06T12:00:00Z',
      attachments: [
        PostAttachment(
            attachmentId: 9,
            position: 0,
            mediaUrl: original,
            previewUrl: preview,
            contentType: 'image/jpeg'),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: SelectedTeamMediaPreloader(
        teamId: 83,
        injuryRepository: ApiTeamInjuryRepository(
          api: ApiClient(
            client: MockClient((_) async => http.Response(
                '{"team_id":83,"season_id":1,"players":[]}', 200)),
            baseUri: Uri.parse('https://api.example.test/v1/'),
            requestHeaders: () => const {},
          ),
        ),
        transferRepository: MockTransferRepository(transfers: const []),
        postRepository: MockPostRepository(posts: [
          const Post(
            postId: 10,
            teamId: 83,
            userId: 1,
            category: PostCategory.general,
            title: 'Video post',
            body: '',
            mediaUrl: 'https://images.example.test/video.mp4',
            createdAt: '2026-10-06T12:01:00Z',
            attachments: [
              PostAttachment(
                attachmentId: 10,
                position: 0,
                mediaUrl: 'https://images.example.test/video.mp4',
                contentType: 'video/mp4',
              )
            ],
          ),
          post,
        ]),
        child: Scaffold(
          body: Builder(
              builder: (context) => ValueListenableBuilder(
                    valueListenable: showFeed,
                    builder: (_, visible, __) => visible
                        ? CommunityPostList(
                            posts: [post],
                            onPostTap: (_) {
                              Navigator.of(context)
                                  .push(MaterialPageRoute<void>(
                                builder: (_) => Scaffold(
                                  body: CustomScrollView(slivers: [
                                    PostDetailContent(
                                      post: post,
                                      liked: false,
                                      likeCount: 0,
                                      commentCount: 0,
                                      onLike: null,
                                      communityRepository:
                                          const StubCommunityRepository(),
                                      comments: const [],
                                      commentsLoading: false,
                                      commentsError: null,
                                      onRetryComments: () {},
                                      onReply: null,
                                      onReport: null,
                                    ),
                                  ]),
                                ),
                              ));
                            })
                        : const Text('Another tab'),
                  )),
        ),
      ),
    ));
    await tester.pump();
    await tester.runAsync(() async {
      await previewRequested.future.timeout(const Duration(seconds: 5));
      await _decoded(preview);
    });
    await tester.pump();
    expect(find.text('Another tab'), findsOneWidget);
    expect(requests, {'/attachments/9/preview': 1});

    showFeed.value = true;
    await tester.pump();
    _expectPhoto(tester, 40);
    await tester.tap(find.byKey(const ValueKey('community-post-9-media-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-detail-media-open')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('community-attachment-viewer')),
        findsNothing);
    _expectPhoto(tester, 40);
    await tester.runAsync(
        () => originalRequested.future.timeout(const Duration(seconds: 5)));

    await tester.ensureVisible(
        find.byKey(const ValueKey('community-detail-media-open')));
    await tester.tap(find.byKey(const ValueKey('community-detail-media-open')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    _expectPhoto(tester, 40);
    expect(
        requests, {'/attachments/9/preview': 1, '/attachments/9/content': 1});

    releaseOriginal.complete();
    await tester.pump();
    await tester.runAsync(() => _decoded(original));
    await tester.pump();
    _expectPhoto(tester, 400);
    await tester.tap(find.byKey(const ValueKey('community-attachment-close')));
    await tester.pumpAndSettle();
    _expectPhoto(tester, 40);
    await tester.tap(find.byKey(const ValueKey('community-detail-media-open')));
    await tester.pumpAndSettle();
    _expectPhoto(tester, 400);
    expect(
        requests, {'/attachments/9/preview': 1, '/attachments/9/content': 1});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugNetworkImageHttpClientProvider = null;
  });
}

class _PhotoHttpClient extends Fake implements HttpClient {
  _PhotoHttpClient(this.respond);
  final Future<HttpClientResponse> Function(Uri) respond;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _PhotoRequest(respond(url));
}

class _PhotoRequest extends Fake implements HttpClientRequest {
  _PhotoRequest(this.response);
  final Future<HttpClientResponse> response;
  @override
  Future<HttpClientResponse> close() => response;
}

class _PhotoResponse extends Fake implements HttpClientResponse {
  _PhotoResponse(this.bytes);
  final List<int> bytes;
  @override
  int get statusCode => HttpStatus.ok;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream.value(bytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
}

void _expectPhoto(WidgetTester tester, int width) {
  final photos = tester.widgetList<RawImage>(find.byType(RawImage));
  expect(photos.any((image) => image.image?.width == width), isTrue);
}

Future<void> _decoded(String url) async {
  final ready = Completer<void>();
  final stream = communityImageProvider(url).resolve(ImageConfiguration.empty);
  final listener = ImageStreamListener((info, _) {
    info.dispose();
    if (!ready.isCompleted) ready.complete();
  }, onError: ready.completeError);
  stream.addListener(listener);
  try {
    await ready.future.timeout(const Duration(seconds: 5));
  } finally {
    stream.removeListener(listener);
  }
}

Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.blue);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}
