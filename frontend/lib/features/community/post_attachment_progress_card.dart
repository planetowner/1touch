import 'dart:io';
import 'dart:math' as math;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/features/media/attachment_transfer_progress.dart';
import 'package:onetouch/features/community/local_video_thumbnail.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class PostAttachmentProgressCard extends StatelessWidget {
  const PostAttachmentProgressCard({
    super.key,
    required this.file,
    required this.progress,
  });

  final XFile file;
  final AttachmentTransferProgress progress;

  @override
  Widget build(BuildContext context) {
    final isVideo = file.mimeType?.startsWith('video/') == true;
    final fraction = progress.fraction?.clamp(0.0, 1.0);
    final stage = switch (progress.phase) {
      AttachmentTransferPhase.preparing => tr(context, 'Preparing attachment…'),
      AttachmentTransferPhase.encoding => tr(context, 'Encoding…'),
      AttachmentTransferPhase.verifying => tr(context, 'Verifying video…'),
      AttachmentTransferPhase.uploading => tr(context, 'Uploading…'),
      AttachmentTransferPhase.saving => tr(context, 'Publishing…'),
    };

    return Semantics(
      label: '$stage ${progress.percent ?? ''}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 345 / 194,
          child: Stack(fit: StackFit.expand, children: [
            if (isVideo)
              LocalVideoThumbnail(path: file.path)
            else
              Image.file(
                File(file.path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF001A27)),
              ),
            const ColoredBox(color: Color(0x55000000)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 48,
                    child: fraction == null
                        ? SvgPicture.asset('assets/match_info/soccer_ball.svg')
                        : ClipPath(
                            clipper: _BallFillClipper(fraction),
                            child: SvgPicture.asset(
                                'assets/match_info/soccer_ball.svg'),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progress.percent == null
                        ? stage
                        : '$stage ${progress.percent}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Archivo',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BallFillClipper extends CustomClipper<Path> {
  const _BallFillClipper(this.fraction);

  final double fraction;

  @override
  Path getClip(Size size) {
    if (fraction <= 0) return Path();
    if (fraction >= 1) return Path()..addRect(Offset.zero & size);
    final center = Offset(size.width / 2, size.height / 2);
    final radius =
        math.sqrt(size.width * size.width + size.height * size.height);
    return Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
      )
      ..close();
  }

  @override
  bool shouldReclip(_BallFillClipper oldClipper) =>
      oldClipper.fraction != fraction;
}
