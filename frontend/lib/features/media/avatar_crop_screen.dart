import 'dart:io';
import 'dart:math' as math;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:insta_assets_crop/insta_assets_crop.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class AvatarCropScreen extends StatefulWidget {
  const AvatarCropScreen({
    super.key,
    required this.originalFile,
    required this.imageSize,
    required this.image,
  });

  final File originalFile;
  final Size imageSize;
  final Widget image;

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  final _cropKey = GlobalKey<CropState>();
  bool _isSaving = false;

  Future<void> _save() async {
    if (_isSaving) return;
    final area = _cropKey.currentState?.area;
    if (area == null) return;

    setState(() => _isSaving = true);
    try {
      final sampled = await InstaAssetsCrop.sampleImage(
        file: widget.originalFile,
        preferredSize: 1080,
      );
      final cropped = await InstaAssetsCrop.cropImage(
        file: sampled,
        area: area,
      );
      if (sampled.path != widget.originalFile.path) {
        try {
          await sampled.delete();
        } on FileSystemException {
          // The exported crop is still usable if temporary cleanup fails.
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(XFile(cropped.path));
    } on Object {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr(
                context, 'Unable to update profile photo. Please try again.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            key: const ValueKey('avatar-crop-cancel'),
            icon: const Icon(Icons.close),
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          ),
          actions: [
            TextButton(
              key: const ValueKey('avatar-crop-save'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white54,
              ),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(tr(context, 'Done')),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final side = math.min(constraints.maxWidth, constraints.maxHeight);
            return Center(
              child: SizedBox.square(
                dimension: side,
                child: Crop(
                  key: _cropKey,
                  size: widget.imageSize,
                  aspectRatio: 1,
                  disableResize: true,
                  child: widget.image,
                ),
              ),
            );
          },
        ),
      );
}
