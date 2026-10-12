import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:onetouch/core/api_image_headers.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/features/community/community_attachment_viewer.dart';
import 'package:onetouch/features/community/community_post_image.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/post.dart';

class CommunityMediaPreview extends StatelessWidget {
  const CommunityMediaPreview(
      {super.key, required this.attachment, this.imageKey, this.remaining = 0});
  final PostAttachment attachment;
  final Key? imageKey;
  final int remaining;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        // 목록은 정해진 썸네일 크기를 쓰고, 상세 사진은 원본 비율로 높이를 정해요.
        child: Stack(fit: StackFit.passthrough, children: [
          ColoredBox(
              color: AppPalette.darkGrey,
              child: attachment.isVideo
                  ? CommunityVideo(
                      key: ValueKey(attachment.mediaUrl),
                      url: attachment.mediaUrl!)
                  : CommunityPostImage(
                      mediaUrl: attachment.mediaUrl!,
                      previewUrl: attachment.previewUrl,
                      imageKey: imageKey,
                      width: double.infinity,
                      fit: BoxFit.cover)),
          if (attachment.isVideo)
            const Center(
                child: CommunityIcon('play', size: 40, color: Colors.white)),
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
      );
}

class CommunityMediaGrid extends StatelessWidget {
  const CommunityMediaGrid({super.key, required this.attachments});
  final List<PostAttachment> attachments;
  @override
  Widget build(BuildContext context) {
    void openMedia(int index) => showCommunityAttachmentViewer(context,
        mediaUrl: attachments[index].mediaUrl!,
        attachments: attachments,
        initialIndex: index);

    Widget media(int index, double aspectRatio) {
      final preview = CommunityMediaPreview(
          attachment: attachments[index],
          imageKey: ValueKey(index == 0
              ? 'community-detail-media'
              : 'community-detail-media-$index'));
      return AspectRatio(
        aspectRatio: aspectRatio,
        child: GestureDetector(
          key: ValueKey(index == 0
              ? 'community-detail-media-open'
              : 'community-detail-media-open-$index'),
          onTap: () => openMedia(index),
          child: preview,
        ),
      );
    }

    Widget overflowTile() {
      return AspectRatio(
        aspectRatio: 3 / 4,
        child: GestureDetector(
          key: const ValueKey('community-detail-media-open-4'),
          onTap: () => openMedia(4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(fit: StackFit.expand, children: [
              CommunityMediaPreview(
                attachment: attachments[4],
                imageKey: const ValueKey('community-detail-media-4'),
              ),
              ColoredBox(color: AppPalette.black.withValues(alpha: 0.72)),
              Center(
                child: Text(
                  '+${attachments.length - 5}',
                  style: CommunityText.bold(context)
                      .copyWith(color: AppPalette.white),
                ),
              ),
            ]),
          ),
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
  const CommunityVideo({super.key, required this.url, this.controls = false});
  final String url;
  final bool controls;
  @override
  State<CommunityVideo> createState() => _CommunityVideoState();
}

class _CommunityVideoState extends State<CommunityVideo>
    with WidgetsBindingObserver {
  late final VideoPlayerController _controller;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url),
        httpHeaders: apiImageHeaders(widget.url) ?? {});
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
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
    if (_failed) {
      return Center(
          child: Text(tr(context, 'Unable to load video.'),
              textAlign: TextAlign.center));
    }
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final video = FittedBox(
        fit: widget.controls ? BoxFit.contain : BoxFit.cover,
        child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller)));
    if (!widget.controls) return IgnorePointer(child: video);
    return Column(children: [
      Expanded(child: video),
      ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _controller,
          builder: (context, value, _) => IconButton(
              tooltip: tr(context, value.isPlaying ? 'Pause' : 'Play'),
              onPressed: () =>
                  value.isPlaying ? _controller.pause() : _controller.play(),
              icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white, size: 40))),
      VideoProgressIndicator(_controller,
          allowScrubbing: true, padding: const EdgeInsets.all(16)),
    ]);
  }
}
