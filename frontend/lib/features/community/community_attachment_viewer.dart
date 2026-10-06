import 'package:flutter/material.dart';
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

class CommunityAttachmentViewer extends StatelessWidget {
  const CommunityAttachmentViewer({
    super.key,
    required this.mediaUrl,
    this.previewUrl,
  });

  final String mediaUrl;
  final String? previewUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('community-attachment-viewer'),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                boundaryMargin: const EdgeInsets.all(40),
                child: Center(
                  child: CommunityPostImage(
                    mediaUrl: mediaUrl,
                    previewUrl: previewUrl,
                    showOriginal: true,
                    imageKey: const ValueKey('community-attachment-full-image'),
                    fit: BoxFit.contain,
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
