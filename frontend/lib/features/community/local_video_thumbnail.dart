import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 선택한 로컬 영상의 첫 프레임을 재생 없이 썸네일로 보여줘요.
class LocalVideoThumbnail extends StatefulWidget {
  const LocalVideoThumbnail({super.key, required this.path});

  final String path;

  @override
  State<LocalVideoThumbnail> createState() => _LocalVideoThumbnailState();
}

class _LocalVideoThumbnailState extends State<LocalVideoThumbnail> {
  late VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final controller = VideoPlayerController.file(File(widget.path));
    _controller = controller;
    _failed = false;
    controller.initialize().then((_) {
      if (mounted && identical(_controller, controller)) setState(() {});
    }).catchError((Object _) {
      if (mounted && identical(_controller, controller)) {
        setState(() => _failed = true);
      }
    });
  }

  @override
  void didUpdateWidget(LocalVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path == widget.path) return;
    final oldController = _controller;
    _load();
    oldController.dispose();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized || _failed) {
      return const ColoredBox(color: Color(0xFF001A27));
    }
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}
