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
    Widget media(int index) {
      final preview = CommunityMediaPreview(
          attachment: attachments[index],
          imageKey: ValueKey(index == 0
              ? 'community-detail-media'
              : 'community-detail-media-$index'));
      return GestureDetector(
        key: ValueKey(index == 0
            ? 'community-detail-media-open'
            : 'community-detail-media-open-$index'),
        onTap: () => showCommunityAttachmentViewer(context,
            mediaUrl: attachments[index].mediaUrl!,
            attachments: attachments,
            initialIndex: index),
        child: attachments[index].isVideo
            ? AspectRatio(
                aspectRatio: index == 0 ? 16 / 9 : 4 / 3, child: preview)
            : preview,
      );
    }

    return Column(children: [
      media(0),
      for (var index = 1; index < attachments.length; index += 2)
        Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: media(index)),
              const SizedBox(width: 15),
              Expanded(
                  child: index + 1 < attachments.length
                      ? media(index + 1)
                      : const SizedBox.shrink()),
            ])),
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
