import 'package:onetouch/core/app_system_ui.dart';
import 'package:onetouch/core/app_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/features/community/community_attachment_actions.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/features/community/community_media.dart';
import 'package:onetouch/features/community/community_post_image.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'package:onetouch/l10n/app_localizations.dart';

Future<void> showCommunityAttachmentViewer(
  BuildContext context, {
  required String mediaUrl,
  String? previewUrl,
  List<PostAttachment> attachments = const [],
  int initialIndex = 0,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: const Color(0x80090A0A),
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, __, ___) => ScaffoldMessenger(
        child: CommunityAttachmentViewer(
          mediaUrl: mediaUrl,
          previewUrl: previewUrl,
          attachments: attachments,
          initialIndex: initialIndex,
        ),
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
  bool _busy = false;
  final Map<int, double> _videoAspectRatios = {};

  Future<void> _chooseAction() async {
    if (_busy) return;
    try {
      final action = await chooseCommunityAttachmentAction(
        saveLabel: tr(context, 'Save to photos'),
        shareLabel: tr(context, 'Share'),
      );
      if (!mounted || action == null) return;
      setState(() => _busy = true);
      await handleCommunityAttachmentAction(_attachments[_index], action);
      if (mounted && action == 'save') {
        showAppSnackBar(
          context,
          tr(context, 'Saved to photos.'),
          duration: const Duration(seconds: 5),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 54, 8),
          alignCloseIconWithText: true,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
            context, tr(context, 'Unable to save or share attachment.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSystemUi(
      iconBrightness: Brightness.light,
      child: Scaffold(
        key: const ValueKey('community-attachment-viewer'),
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final aspectRatio = _attachments[_index].isVideo
                  ? (_videoAspectRatios[_index] ?? 3 / 4)
                  : 3 / 4;
              final width = (constraints.maxWidth - 48)
                  .clamp(0.0, (constraints.maxHeight - 50) * aspectRatio);
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: width,
                        child: AspectRatio(
                          aspectRatio: aspectRatio,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFF090A0A),
                                border:
                                    Border.all(color: const Color(0xFF3D3D3D)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(children: [
                                Positioned.fill(
                                  child: PageView.builder(
                                    controller: _pages,
                                    physics: _scale > 1
                                        ? const NeverScrollableScrollPhysics()
                                        : null,
                                    itemCount: _attachments.length,
                                    onPageChanged: (index) => setState(() {
                                      _index = index;
                                      _scale = 1;
                                    }),
                                    itemBuilder: (context, index) {
                                      final attachment = _attachments[index];
                                      return attachment.isVideo
                                          ? CommunityVideo(
                                              key:
                                                  ValueKey(attachment.mediaUrl),
                                              url: attachment.mediaUrl!,
                                              controls: index == _index,
                                              onAspectRatioKnown: (ratio) {
                                                if (mounted &&
                                                    _videoAspectRatios[index] !=
                                                        ratio) {
                                                  setState(() =>
                                                      _videoAspectRatios[
                                                          index] = ratio);
                                                }
                                              })
                                          : GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onScaleStart: (_) =>
                                                  _gestureStartScale = _scale,
                                              onScaleUpdate: (details) {
                                                // 사진 중심을 고정하고 핀치 배율만 반영해요.
                                                final nextScale =
                                                    (_gestureStartScale *
                                                            details.scale)
                                                        .clamp(1.0, 4.0);
                                                if (nextScale != _scale) {
                                                  setState(
                                                      () => _scale = nextScale);
                                                }
                                              },
                                              child: Transform.scale(
                                                key: const ValueKey(
                                                    'community-attachment-image-transform'),
                                                scale: _scale,
                                                alignment: Alignment.center,
                                                child: CommunityPostImage(
                                                  mediaUrl:
                                                      attachment.mediaUrl!,
                                                  previewUrl:
                                                      attachment.previewUrl,
                                                  showOriginal: true,
                                                  imageKey: const ValueKey(
                                                      'community-attachment-full-image'),
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            );
                                    },
                                  ),
                                ),
                                Positioned(
                                  top: 16,
                                  left: 16,
                                  child: _ViewerAction(
                                    actionKey: const ValueKey(
                                        'community-attachment-actions'),
                                    onTap: _busy ? null : _chooseAction,
                                    icon: const CommunityIcon('share',
                                        color: Colors.white),
                                  ),
                                ),
                                Positioned(
                                  top: 16,
                                  right: 16,
                                  child: _ViewerAction(
                                    actionKey: const ValueKey(
                                        'community-attachment-close'),
                                    onTap: () => Navigator.of(context).pop(),
                                    icon: const CommunityIcon('close',
                                        color: Colors.white),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        key: const ValueKey('community-attachment-index'),
                        height: 34,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090A0A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${_index + 1}/${_attachments.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Archivo',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ViewerAction extends StatelessWidget {
  const _ViewerAction(
      {required this.actionKey, required this.onTap, required this.icon});

  final Key actionKey;
  final VoidCallback? onTap;
  final Widget icon;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0x80090A0A),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          key: actionKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(padding: const EdgeInsets.all(8), child: icon),
        ),
      );
}
