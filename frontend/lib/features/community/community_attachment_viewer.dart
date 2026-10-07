import 'package:flutter/material.dart';
import 'package:onetouch/core/interactive_back_page.dart';
import 'package:onetouch/features/community/community_post_image.dart';

Future<void> showCommunityAttachmentViewer(
  BuildContext context, {
  required String mediaUrl,
  String? previewUrl,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, __, ___) => CommunityAttachmentViewer(
        mediaUrl: mediaUrl,
        previewUrl: previewUrl,
      ),
      transitionsBuilder: (context, animation, _, child) {
        final route = ModalRoute.of(context)! as PageRoute<dynamic>;
        return InteractiveBackTransition(
          route: route,
          child: AnimatedBuilder(
            animation: animation,
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            ),
            builder: (context, child) => Transform.translate(
              offset: Offset(
                route.popGestureInProgress
                    ? (1 - animation.value) * MediaQuery.sizeOf(context).width
                    : 0,
                0,
              ),
              child: child,
            ),
          ),
        );
      },
    ),
  );
}

class CommunityAttachmentViewer extends StatefulWidget {
  const CommunityAttachmentViewer({
    super.key,
    required this.mediaUrl,
    this.previewUrl,
  });

  final String mediaUrl;
  final String? previewUrl;

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
                    child: CommunityPostImage(
                      mediaUrl: widget.mediaUrl,
                      previewUrl: widget.previewUrl,
                      showOriginal: true,
                      imageKey:
                          const ValueKey('community-attachment-full-image'),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
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
