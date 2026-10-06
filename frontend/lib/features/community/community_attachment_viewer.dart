import 'package:flutter/material.dart';
import 'package:onetouch/core/api_image_headers.dart';

Future<void> showCommunityAttachmentViewer(
  BuildContext context, {
  required String mediaUrl,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, __, ___) => CommunityAttachmentViewer(
        mediaUrl: mediaUrl,
      ),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: child,
      ),
    ),
  );
}

class CommunityAttachmentViewer extends StatefulWidget {
  const CommunityAttachmentViewer({
    super.key,
    required this.mediaUrl,
  });

  final String mediaUrl;

  @override
  State<CommunityAttachmentViewer> createState() =>
      _CommunityAttachmentViewerState();
}

class _CommunityAttachmentViewerState extends State<CommunityAttachmentViewer> {
  double _scale = 1;
  double _gestureStartScale = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('community-attachment-viewer'),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (_) => _gestureStartScale = _scale,
                  onScaleUpdate: (details) {
                    // 사진의 중심을 고정하고 핀치 배율만 반영해요.
                    final nextScale =
                        (_gestureStartScale * details.scale).clamp(1.0, 4.0);
                    if (nextScale != _scale) {
                      setState(() => _scale = nextScale);
                    }
                  },
                  child: Transform.scale(
                    key: const ValueKey('community-attachment-image-transform'),
                    scale: _scale,
                    alignment: Alignment.center,
                    child: Image.network(
                      widget.mediaUrl,
                      key: const ValueKey('community-attachment-full-image'),
                      headers: apiImageHeaders(widget.mediaUrl),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 12,
              child: IconButton(
                key: const ValueKey('community-attachment-close'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
