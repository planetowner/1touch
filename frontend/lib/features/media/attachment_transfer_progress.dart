enum AttachmentTransferPhase {
  preparing,
  encoding,
  verifying,
  uploading,
  saving,
}

class AttachmentTransferProgress {
  const AttachmentTransferProgress({
    required this.phase,
    required this.fileIndex,
    required this.fileCount,
    this.fraction,
  });

  final AttachmentTransferPhase phase;
  final int fileIndex;
  final int fileCount;
  final double? fraction;

  int? get percent =>
      fraction == null ? null : (fraction!.clamp(0, 1) * 100).round();
}
