import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/data/injuries/team_injury_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/data/transfers/transfer_repository.dart';
import 'package:onetouch/features/community/community_post_image.dart';
import 'package:onetouch/features/player/player_image_cache.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/team_injury_report.dart';
import 'package:onetouch/models/team_transfer_window.dart';

class SelectedTeamMediaPreloader extends StatefulWidget {
  const SelectedTeamMediaPreloader({
    super.key,
    required this.teamId,
    required this.postRepository,
    required this.injuryRepository,
    required this.transferRepository,
    required this.child,
  });

  final int teamId;
  final PostRepository postRepository;
  final TeamInjuryRepository injuryRepository;
  final TransferRepository transferRepository;
  final Widget child;

  Iterable<Listenable> get _cacheChanges sync* {
    if (postRepository case CachedPostRepository repository) {
      yield repository.cachedFeeds;
    }
    yield injuryRepository.cachedReports;
    yield transferRepository.cachedWindows;
  }

  @override
  State<SelectedTeamMediaPreloader> createState() =>
      _SelectedTeamMediaPreloaderState();
}

class _SelectedTeamMediaPreloaderState
    extends State<SelectedTeamMediaPreloader> {
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _listen(widget);
    _scheduleLoad();
  }

  void _listen(SelectedTeamMediaPreloader source) {
    for (final changes in source._cacheChanges) {
      changes.addListener(_prepareCachedImages);
    }
  }

  void _unlisten(SelectedTeamMediaPreloader source) {
    for (final changes in source._cacheChanges) {
      changes.removeListener(_prepareCachedImages);
    }
  }

  @override
  void didUpdateWidget(SelectedTeamMediaPreloader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final repositoriesChanged =
        oldWidget.postRepository != widget.postRepository ||
            oldWidget.injuryRepository != widget.injuryRepository ||
            oldWidget.transferRepository != widget.transferRepository;
    if (repositoriesChanged) {
      _unlisten(oldWidget);
      _listen(widget);
    }
    if (oldWidget.teamId != widget.teamId || repositoriesChanged) {
      _scheduleLoad();
    }
  }

  void _scheduleLoad() {
    final generation = ++_generation;
    // 현재 탭의 첫 화면은 기다리지 않고, 뒤에서 선택한 팀의 사진을 준비해요.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      _prepareCachedImages();
      final teamId = widget.teamId;
      // 한 목록이 늦거나 없어도 다른 목록의 사진은 먼저 준비해요.
      unawaited(_load(() => widget.postRepository.loadPosts(teamId: teamId),
          _postImages, generation));
      unawaited(_load(() => widget.injuryRepository.loadForTeam(teamId),
          _injuryImages, generation));
      unawaited(_load(() => widget.transferRepository.loadForTeam(teamId),
          _transferImages, generation));
    });
  }

  Future<void> _load<T>(Future<T> Function() load,
      Iterable<ImageProvider> Function(T) images, int generation) async {
    try {
      final data = await load();
      if (!mounted || generation != _generation) return;
      await _prepare(images(data), generation);
    } on Object {
      // 선로딩 실패는 화면 이동을 막지 않고 해당 화면에서 다시 조회해요.
    }
  }

  void _prepareCachedImages() {
    final posts = switch (widget.postRepository) {
      CachedPostRepository repository =>
        repository.cachedFeed(teamId: widget.teamId),
      _ => null,
    };
    final injuries = widget.injuryRepository.cachedForTeam(widget.teamId);
    final transfers = widget.transferRepository.cachedForTeam(widget.teamId);
    unawaited(_prepare([
      if (posts != null) ..._postImages(posts),
      if (injuries != null) ..._injuryImages(injuries),
      if (transfers != null) ..._transferImages(transfers),
    ], _generation));
  }

  Iterable<ImageProvider> _postImages(List<Post> posts) sync* {
    // 커뮤니티는 첫 화면 주변의 미리보기만 준비해 원본 다운로드를 줄여요.
    for (final post in posts.take(6)) {
      final contentType = post.mediaAttachment?.contentType;
      if (contentType != null && !contentType.startsWith('image/')) continue;
      final url = post.mediaPreviewUrl ?? post.mediaUrl;
      if (url != null) yield communityImageProvider(url);
    }
  }

  Iterable<ImageProvider> _injuryImages(TeamInjuryReport report) =>
      _playerImages(report.players.map((player) => player.playerImage));

  Iterable<ImageProvider> _transferImages(TeamTransferWindow window) =>
      // 영입·방출 전환 때도 사진을 기다리지 않도록 양쪽을 함께 준비해요.
      _playerImages([
        ...window.incoming.map((player) => player.playerImage),
        ...window.outgoing.map((player) => player.playerImage),
      ]);

  Iterable<ImageProvider> _playerImages(Iterable<String?> urls) sync* {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    for (final url
        in urls.whereType<String>().map((url) => url.trim()).toSet()) {
      if (url.isNotEmpty) {
        yield PlayerImageCache.portraitProvider(url,
            devicePixelRatio: pixelRatio);
      }
    }
  }

  Future<void> _prepare(Iterable<ImageProvider> images, int generation) async {
    if (!mounted || generation != _generation) return;
    // 사진별로 바로 시작하고, 겹치는 요청은 Flutter 이미지 캐시에서 공유해요.
    await Future.wait(images
        .toSet()
        .map((image) => precacheImage(image, context, onError: (_, __) {})));
  }

  @override
  void dispose() {
    _unlisten(widget);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
