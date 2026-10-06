import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/core/api_image_headers.dart';

// 선로딩·목록·상세·확대가 같은 이미지 키를 써야 다운로드와 디코딩을 반복하지 않아요.
NetworkImage communityImageProvider(String url) =>
    NetworkImage(url, headers: apiImageHeaders(url));

class CommunityPostImage extends StatefulWidget {
  const CommunityPostImage({
    super.key,
    required this.mediaUrl,
    this.previewUrl,
    this.imageKey,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.prepareOriginal = false,
    this.showOriginal = false,
  });

  final String mediaUrl;
  final String? previewUrl;
  final Key? imageKey;
  final BoxFit fit;
  final double? width;
  final double? height;
  final bool prepareOriginal;
  final bool showOriginal;

  @override
  State<CommunityPostImage> createState() => _CommunityPostImageState();
}

class _CommunityPostImageState extends State<CommunityPostImage> {
  String? _preparingUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepare();
  }

  @override
  void didUpdateWidget(CommunityPostImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepare();
  }

  void _prepare() {
    if (!widget.prepareOriginal || _preparingUrl == widget.mediaUrl) return;
    _preparingUrl = widget.mediaUrl;
    unawaited(_prepareOriginal(widget.mediaUrl, widget.previewUrl));
  }

  Future<void> _prepareOriginal(String original, String? preview) async {
    // 본문 사진부터 보여준 뒤 원본을 준비해, 두 다운로드가 표시를 늦추지 않게 해요.
    if (preview != null) {
      await precacheImage(communityImageProvider(preview), context,
          onError: (_, __) {});
    }
    if (!mounted || original != widget.mediaUrl) return;
    await precacheImage(communityImageProvider(original), context,
        onError: (_, __) {});
  }

  Widget _error() => Center(
        child: Icon(Icons.image_not_supported_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant, size: 32),
      );

  Widget _preview() => Image(
        key: widget.showOriginal && widget.previewUrl != null
            ? null
            : widget.imageKey,
        image: communityImageProvider(widget.previewUrl ?? widget.mediaUrl),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => _error(),
      );

  @override
  Widget build(BuildContext context) {
    if (!widget.showOriginal || widget.previewUrl == null) return _preview();
    return Image(
      key: widget.imageKey,
      image: communityImageProvider(widget.mediaUrl),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      // 확대를 눌렀을 때 원본이 덜 준비됐어도 본문에서 본 사진을 계속 보여줘요.
      frameBuilder: (_, child, frame, __) => frame == null ? _preview() : child,
      errorBuilder: (_, __, ___) => _preview(),
    );
  }
}
