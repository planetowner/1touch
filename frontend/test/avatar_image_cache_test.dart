import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/session/clear_session_data.dart';
import 'package:onetouch/features/media/avatar_image_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const url = 'https://api.example.test/v1/users/1/avatar';
  const headers = {'Authorization': 'Bearer first-session'};
  late Directory directory;
  late CacheManager manager;
  late MockClient client;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) respond;
  late List<int> bytes;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  CacheManager createManager() => CacheManager(Config(
        'avatar-cache-test',
        repo: JsonCacheInfoRepository(path: '${directory.path}/cache.json'),
        fileService: HttpFileService(httpClient: client),
      ));

  Future<List<FileInfo>> files(CachedNetworkImageProvider image) => manager
      .getFileStream(image.url, key: image.cacheKey, headers: image.headers)
      .where((result) => result is FileInfo)
      .cast<FileInfo>()
      .toList();

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('avatar-cache-');
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    bytes = await File('assets/profileAvatar.png').readAsBytes();
    requests = [];
    respond = (_) async => http.Response.bytes(bytes, 200, headers: {
          'content-type': 'image/png',
          'cache-control': 'private, no-cache',
          'etag': 'first-photo',
        });
    client = MockClient((request) async {
      requests.add(request);
      return respond(request);
    });
    manager = createManager();
    AvatarImageCache.manager = manager;
  });

  tearDown(() async {
    await AvatarImageCache.clear();
    await manager.dispose();
    messenger.setMockMethodCallHandler(channel, null);
    client.close();
    await directory.delete(recursive: true);
  });

  test('restart displays the saved photo before the network responds',
      () async {
    final image = AvatarImageCache.provider(url, headers: headers);
    await files(image);
    expect(requests.single.url.queryParameters['thumbnail'], 'true');
    expect(requests.single.headers['authorization'], headers['Authorization']);

    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await manager.dispose();
    manager = createManager();
    AvatarImageCache.manager = manager;
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    respond = (request) {
      expect(request.headers['if-none-match'], 'first-photo');
      started.complete();
      return pending.future;
    };

    final restored = AvatarImageCache.provider(url, headers: headers);
    await _resolveImage(restored);
    await started.future;
    expect(pending.isCompleted, isFalse);
    expect(restored.cacheKey, image.cacheKey);
    expect(requests, hasLength(2));
    // 오프라인이어도 이미 표시한 파일을 그대로 유지해야 해요.
    final finished = files(restored);
    pending.completeError(const SocketException('offline'));
    expect(await finished, hasLength(1));
    expect(await manager.getFileFromCache(restored.cacheKey!), isNotNull);
  });

  test('revalidation replaces a saved photo and sends its previous ETag',
      () async {
    final image = AvatarImageCache.provider(url, headers: headers);
    await files(image);
    final replacement = await File('assets/highlight1.png').readAsBytes();
    respond = (request) async {
      expect(request.headers['if-none-match'], 'first-photo');
      return http.Response.bytes(replacement, 200, headers: {
        'content-type': 'image/png',
        'cache-control': 'private, no-cache',
        'etag': 'second-photo',
      });
    };
    final results = await files(image);
    expect(results.map((file) => file.source),
        [FileSource.Cache, FileSource.Online]);
    expect(await results.last.file.readAsBytes(), replacement);
  });

  test('photo edits evict disk and decoded images before the next download',
      () async {
    respond = (_) async => http.Response.bytes(bytes, 200, headers: {
          'content-type': 'image/png',
          'cache-control': 'private, max-age=3600',
        });
    final image = AvatarImageCache.provider(url, headers: headers);
    await _resolveImage(image);
    expect(PaintingBinding.instance.imageCache.containsKey(image), isTrue);
    await AvatarImageCache.evict(url, headers: headers);
    expect(await manager.getFileFromCache(image.cacheKey!), isNull);
    expect(PaintingBinding.instance.imageCache.containsKey(image), isFalse);
    await _resolveImage(AvatarImageCache.provider(url, headers: headers));
    expect(requests, hasLength(2));
  });

  test('different login sessions cannot reuse each other’s avatar file',
      () async {
    final first = AvatarImageCache.provider(url, headers: headers);
    await files(first);
    final second = AvatarImageCache.provider(url,
        headers: const {'Authorization': 'Bearer second-session'});
    expect(first.cacheKey, isNot(second.cacheKey));
    expect(first.cacheKey, isNot(contains('first-session')));
    expect(await manager.getFileFromCache(second.cacheKey!), isNull);
    await files(second);
    expect(requests, hasLength(2));
    expect(requests.last.headers['authorization'], 'Bearer second-session');
    expect(requests.last.headers['if-none-match'], isNull);
  });

  test('session cleanup removes avatar files and decoded images', () async {
    respond = (_) async => http.Response.bytes(bytes, 200, headers: {
          'content-type': 'image/png',
          'cache-control': 'private, max-age=3600',
        });
    final image = AvatarImageCache.provider(url, headers: headers);
    await _resolveImage(image);
    await clearSessionData();
    expect(await manager.getFileFromCache(image.cacheKey!), isNull);
    expect(PaintingBinding.instance.imageCache.containsKey(image), isFalse);
  });
}

Future<void> _resolveImage(ImageProvider image) async {
  final ready = Completer<void>();
  final stream = image.resolve(ImageConfiguration.empty);
  final listener = ImageStreamListener((info, _) {
    expect(info.image.width, greaterThan(0));
    info.dispose();
    if (!ready.isCompleted) ready.complete();
  }, onError: (Object error, StackTrace? stack) {
    if (!ready.isCompleted) ready.completeError(error, stack);
  });
  stream.addListener(listener);
  try {
    await ready.future;
  } finally {
    stream.removeListener(listener);
  }
}
