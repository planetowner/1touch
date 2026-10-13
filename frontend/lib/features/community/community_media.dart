import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:onetouch/core/api_image_headers.dart';
import 'package:onetouch/core/app_snack_bar.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/features/community/community_attachment_viewer.dart';
import 'package:onetouch/features/community/community_post_image.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/post.dart';

class CommunityMediaPreview extends StatelessWidget {
  const CommunityMediaPreview(
      {super.key,
      required this.attachment,
      this.imageKey,
      this.remaining = 0,
      this.onOpen});
  final PostAttachment attachment;
  final Key? imageKey;
  final int remaining;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        // 목록은 정해진 썸네일 크기를 쓰고, 상세 사진은 원본 비율로 높이를 정해요.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: attachment.isVideo ? null : onOpen,
          child: Stack(fit: StackFit.passthrough, children: [
            ColoredBox(
                color: AppPalette.darkGrey,
                child: attachment.isVideo
                    ? CommunityVideo(
                        key: ValueKey(attachment.mediaUrl),
                        url: attachment.mediaUrl!,
                        onOpen: onOpen)
                    : CommunityPostImage(
                        mediaUrl: attachment.mediaUrl!,
                        previewUrl: attachment.previewUrl,
                        imageKey: imageKey,
                        width: double.infinity,
                        fit: BoxFit.cover)),
            if (remaining > 0)
              Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFF0A0A0A),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text('+$remaining',
                        style: CommunityText.body(context, text: '+$remaining')
                            .copyWith(color: Colors.white, fontSize: 12)),
                  )),
          ]),
        ),
      );
}

class CommunityMediaGrid extends StatelessWidget {
  const CommunityMediaGrid({super.key, required this.attachments});
  final List<PostAttachment> attachments;
  @override
  Widget build(BuildContext context) {
    void openMedia(int index) {
      // 상세의 오류 안내가 전체 화면으로 따라가지 않게 닫아요.
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      showCommunityAttachmentViewer(context,
          mediaUrl: attachments[index].mediaUrl!,
          attachments: attachments,
          initialIndex: index);
    }

    Widget media(int index, double aspectRatio) {
      final preview = CommunityMediaPreview(
          key: ValueKey(index == 0
              ? 'community-detail-media-open'
              : 'community-detail-media-open-$index'),
          attachment: attachments[index],
          onOpen: () => openMedia(index),
          imageKey: ValueKey(index == 0
              ? 'community-detail-media'
              : 'community-detail-media-$index'));
      return AspectRatio(
        aspectRatio: aspectRatio,
        child: preview,
      );
    }

    Widget overflowTile() {
      return AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(fit: StackFit.expand, children: [
            CommunityMediaPreview(
              key: const ValueKey('community-detail-media-open-4'),
              attachment: attachments[4],
              onOpen: () => openMedia(4),
              imageKey: const ValueKey('community-detail-media-4'),
            ),
            IgnorePointer(
              child: ColoredBox(
                color: AppPalette.black.withValues(alpha: 0.72),
                child: Center(
                  child: Text(
                    '+${attachments.length - 5}',
                    style: CommunityText.bold(context)
                        .copyWith(color: AppPalette.white),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
    }

    Widget row(List<Widget> children) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const SizedBox(width: 12),
              Expanded(child: children[index]),
            ],
          ],
        );

    final count = attachments.length;
    if (count == 1) return media(0, 1);
    if (count == 2) return row([media(0, 3 / 4), media(1, 3 / 4)]);
    if (count == 3) {
      return Column(children: [
        media(0, 4 / 3),
        const SizedBox(height: 12),
        row([media(1, 4 / 3), media(2, 4 / 3)]),
      ]);
    }
    final firstRow = row([media(0, 1), media(1, 1)]);
    if (count == 4) {
      return Column(children: [
        firstRow,
        const SizedBox(height: 12),
        row([media(2, 1), media(3, 1)]),
      ]);
    }
    // 다섯 장은 전부 보여주고, 여섯 장부터 다섯 번째 사진 위에 남은 장수를 표시해요.
    return Column(children: [
      firstRow,
      const SizedBox(height: 12),
      row([
        media(2, 3 / 4),
        media(3, 3 / 4),
        count == 5 ? media(4, 3 / 4) : overflowTile(),
      ]),
    ]);
  }
}

class CommunityVideo extends StatefulWidget {
  const CommunityVideo({
    super.key,
    required this.url,
    this.controls = false,
    this.onOpen,
    this.onAspectRatioKnown,
  });
  final String url;
  final bool controls;
  final VoidCallback? onOpen;
  final ValueChanged<double>? onAspectRatioKnown;
  @override
  State<CommunityVideo> createState() => _CommunityVideoState();
}

class _CommunityVideoState extends State<CommunityVideo>
    with WidgetsBindingObserver {
  late final VideoPlayerController _controller;
  late final Future<void> _initialization;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url),
        httpHeaders: apiImageHeaders(widget.url) ?? {});
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {});
        final aspectRatio = _controller.value.aspectRatio;
        if (aspectRatio.isFinite && aspectRatio > 0) {
          widget.onAspectRatioKnown?.call(aspectRatio);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _open() async {
    await _initialization;
    if (!mounted) return;
    // 상세에서 영상을 눌렀을 때만 실패를 알리고, 열 수 없는 영상은 전체 화면으로 넘기지 않아요.
    if (_failed || _controller.value.hasError) {
      showAppSnackBar(context, tr(context, 'Unable to load video.'),
          replaceCurrent: true);
      return;
    }
    widget.onOpen!();
  }

  @override
  void didUpdateWidget(CommunityVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controls && !widget.controls) _controller.pause();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controls) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen == null ? null : _open,
        child: Stack(fit: StackFit.expand, children: [
          IgnorePointer(child: _content()),
          const Center(
              child: CommunityIcon('play', size: 40, color: Colors.white)),
        ]),
      );
    }
    return _content();
  }

  Widget _loadingBall() => Theme(
        data: ThemeData.dark(),
        child: const Center(child: FootballLoadingIndicator()),
      );

  Widget _content() {
    if (_failed) return const SizedBox.expand();
    if (!_controller.value.isInitialized) {
      return _loadingBall();
    }
    final video = FittedBox(
        fit: widget.controls ? BoxFit.contain : BoxFit.cover,
        child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller)));
    final videoWithLoading = ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _controller,
      builder: (context, value, _) => Stack(
        fit: StackFit.expand,
        children: [
          video,
          if (value.isBuffering) _loadingBall(),
        ],
      ),
    );
    if (!widget.controls) return videoWithLoading;
    return Stack(fit: StackFit.expand, children: [
      videoWithLoading,
      GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _controller.value.isPlaying
            ? _controller.pause()
            : _controller.play(),
      ),
      ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _controller,
          builder: (context, value, _) => value.isPlaying
              ? const SizedBox.shrink()
              : const IgnorePointer(
                  key: ValueKey('community-video-play-overlay'),
                  child: Center(
                      child: CommunityIcon('play',
                          size: 40, color: Colors.white)))),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: VideoProgressIndicator(
          _controller,
          key: const ValueKey('community-video-progress'),
          allowScrubbing: true,
          padding: const EdgeInsets.only(top: 12),
          colors: const VideoProgressColors(
            playedColor: Colors.white,
            bufferedColor: Colors.white38,
            backgroundColor: Colors.white24,
          ),
        ),
      ),
    ]);
  }
}
