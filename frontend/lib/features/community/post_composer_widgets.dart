import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/post.dart';

class PostComposerFields extends StatelessWidget {
  const PostComposerFields({
    super.key,
    required this.selectedCategory,
    required this.titleController,
    required this.bodyController,
    required this.mediaFiles,
    required this.onCategoryChanged,
    required this.onPickMedia,
    required this.onRemoveMedia,
  });

  final PostCategory selectedCategory;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final List<XFile> mediaFiles;
  final ValueChanged<PostCategory> onCategoryChanged;
  final VoidCallback onPickMedia;
  final ValueChanged<int> onRemoveMedia;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedCategoryLabel =
        tr(context, selectedCategory.label).toUpperCase();
    final categoryLabelPainter = TextPainter(
      text: TextSpan(
        text: selectedCategoryLabel,
        style: Body1_b.style.copyWith(color: Colors.black),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final categoryFilterWidth = categoryLabelPainter.width + 64;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(tr(context, 'POST TO'), style: Body2_b.style),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: categoryFilterWidth,
              height: AppDropdownTokens.height,
              child: PopupMenuButton<PostCategory>(
                initialValue: selectedCategory,
                position: PopupMenuPosition.under,
                offset: const Offset(0, 4),
                color: AppPalette.white,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                constraints: const BoxConstraints(
                  minWidth: 160,
                  maxWidth: 220,
                ),
                onSelected: onCategoryChanged,
                itemBuilder: (context) => PostCategory.values
                    .map(
                      (category) => PopupMenuItem<PostCategory>(
                        value: category,
                        child: Text(
                          tr(context, category.label).toUpperCase(),
                          style: Body1_b.style.copyWith(color: Colors.black),
                        ),
                      ),
                    )
                    .toList(),
                child: Container(
                  key: const ValueKey('community-category-filter'),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppPalette.white,
                    borderRadius:
                        BorderRadius.circular(AppDropdownTokens.radius),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedCategoryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Body1_b.style.copyWith(color: Colors.black),
                        ),
                      ),
                      const SizedBox(width: AppDropdownTokens.gap),
                      const AppDropdownChevron(color: Colors.black),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: titleController,
          style: Heading4.style.copyWith(color: colors.onSurface),
          cursorColor: colors.onSurface,
          maxLines: null,
          decoration: InputDecoration(
            hintText: tr(context, 'Title...'),
            hintStyle: Heading4.style.copyWith(
              color: appColors.mutedForeground,
            ),
            border: InputBorder.none,
            filled: false,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: bodyController,
          style: Body2.style.copyWith(color: colors.onSurface),
          cursorColor: colors.onSurface,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            hintText: tr(context, 'Write something...'),
            hintStyle: Body2.style.copyWith(
              color: appColors.mutedForeground,
            ),
            border: InputBorder.none,
            filled: false,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 24),
        if (mediaFiles.isNotEmpty) ...[
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: mediaFiles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(mediaFiles[index].path),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => onRemoveMedia(index),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        DottedBorder(
          color: isDark ? Colors.white54 : appColors.mutedForeground,
          strokeWidth: 1,
          dashPattern: const [6, 6],
          borderType: BorderType.RRect,
          radius: const Radius.circular(12),
          child: GestureDetector(
            onTap: onPickMedia,
            child: Container(
              key: const ValueKey('community-media-picker'),
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: isDark ? AppPalette.lightGrey : const Color(0xFFC8C8C8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: colors.onSurface, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      tr(context, 'Add photo or video'),
                      style: Body2.style.copyWith(color: colors.onSurface),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class PostComposerSubmitBar extends StatelessWidget {
  const PostComposerSubmitBar({
    super.key,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          key: const ValueKey('community-post-submit'),
          onPressed: isSubmitting ? null : onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.onSurface,
            foregroundColor: colors.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: isSubmitting
              ? SizedBox(
                  key: const ValueKey('community-post-submitting'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.onPrimary,
                  ),
                )
              : Text(
                  tr(context, 'POST'),
                  style: Body1_b.style.copyWith(color: colors.onPrimary),
                ),
        ),
      ),
    );
  }
}
