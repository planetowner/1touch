import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/community/post_attachment_progress_card.dart';
import 'package:onetouch/features/media/attachment_transfer_progress.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(430, 932)]) {
    testWidgets('transfer card fits ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: PostAttachmentProgressCard(
              file: XFile('clip.mp4', mimeType: 'video/mp4'),
              progress: const AttachmentTransferProgress(
                phase: AttachmentTransferPhase.uploading,
                fileIndex: 0,
                fileCount: 1,
                fraction: .42,
              ),
            ),
          ),
        ),
      ));

      expect(find.text('Uploading… 42%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(PostAttachmentProgressCard)).width,
          size.width - 48);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: PostAttachmentProgressCard(
              file: XFile('clip.mp4', mimeType: 'video/mp4'),
              progress: const AttachmentTransferProgress(
                phase: AttachmentTransferPhase.verifying,
                fileIndex: 0,
                fileCount: 1,
                fraction: .42,
              ),
            ),
          ),
        ),
      ));
      expect(find.text('Verifying video… 42%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
