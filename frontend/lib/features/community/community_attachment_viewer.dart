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

class CommunityAttachmentViewer extends StatelessWidget {
  const CommunityAttachmentViewer({
    super.key,
    required this.mediaUrl,
  });

  final String mediaUrl;

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
                  child: Image.network(
                    mediaUrl,
                    key: const ValueKey('community-attachment-full-image'),
                    headers: apiImageHeaders(mediaUrl),
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
