import 'package:onetouch/core/app_system_ui.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/features/community/community_media.dart';
import 'package:onetouch/features/community/community_post_image.dart';

Future<void> showCommunityAttachmentViewer(
  BuildContext context, {
  required String mediaUrl,
  String? previewUrl,
  List<PostAttachment> attachments = const [],
  int initialIndex = 0,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, __, ___) => CommunityAttachmentViewer(
        mediaUrl: mediaUrl,
        previewUrl: previewUrl,
        attachments: attachments,
        initialIndex: initialIndex,
      ),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    ),
  );
}

class CommunityAttachmentViewer extends StatefulWidget {
  const CommunityAttachmentViewer({
    super.key,
    required this.mediaUrl,
    this.previewUrl,
    this.attachments = const [],
    this.initialIndex = 0,
  });

  final String mediaUrl;
  final String? previewUrl;
  final List<PostAttachment> attachments;
  final int initialIndex;

  @override
  State<CommunityAttachmentViewer> createState() =>
      _CommunityAttachmentViewerState();
}

class _CommunityAttachmentViewerState extends State<CommunityAttachmentViewer> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  List<PostAttachment> get _attachments => widget.attachments.isNotEmpty
      ? widget.attachments
      : [
          PostAttachment(
              attachmentId: 0,
              position: 0,
              mediaUrl: widget.mediaUrl,
              previewUrl: widget.previewUrl)
        ];
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  double _scale = 1;
  double _gestureStartScale = 1;

  @override
  Widget build(BuildContext context) {
    return AppSystemUi(
      iconBrightness: Brightness.light,
      child: Scaffold(
        key: const ValueKey('community-attachment-viewer'),
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: PageView.builder(
                  controller: _pages,
                  physics:
                      _scale > 1 ? const NeverScrollableScrollPhysics() : null,
                  itemCount: _attachments.length,
                  onPageChanged: (index) => setState(() {
                    _index = index;
                    _scale = 1;
                  }),
                  itemBuilder: (context, index) {
                    final attachment = _attachments[index];
                    return attachment.isVideo
                        ? CommunityVideo(
                            key: ValueKey(attachment.mediaUrl),
                            url: attachment.mediaUrl!,
                            controls: index == _index)
                        : ClipRect(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onScaleStart: (_) => _gestureStartScale = _scale,
                              onScaleUpdate: (details) {
                                // 사진의 중심을 고정하고 핀치 배율만 반영해요.
                                final nextScale =
                                    (_gestureStartScale * details.scale)
                                        .clamp(1.0, 4.0);
                                if (nextScale != _scale) {
                                  setState(() => _scale = nextScale);
                                }
                              },
                              child: Transform.scale(
                                key: const ValueKey(
                                    'community-attachment-image-transform'),
                                scale: _scale,
                                alignment: Alignment.center,
                                child: CommunityPostImage(
                                  mediaUrl: attachment.mediaUrl!,
                                  previewUrl: attachment.previewUrl,
                                  showOriginal: true,
                                  imageKey: const ValueKey(
                                      'community-attachment-full-image'),
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          );
                  },
                ),
              ),
              if (_attachments.length > 1)
                Positioned(
                    top: 24,
                    left: 24,
                    child: Text('${_index + 1} / ${_attachments.length}',
                        style: const TextStyle(color: Colors.white))),
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
      ),
    );
  }
}
