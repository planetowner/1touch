import 'package:onetouch/core/app_action_button.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:cross_file/cross_file.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/api_image_headers.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/post.dart';

class PostComposerFields extends StatelessWidget {
  const PostComposerFields({
    super.key,
    required this.selectedCategory,
    required this.titleController,
    required this.bodyController,
    required this.mediaFiles,
    this.existingAttachments = const [],
    required this.onCategoryChanged,
    required this.onPickMedia,
    required this.onRemoveMedia,
    this.onRemoveExistingAttachment,
  });

  final PostCategory selectedCategory;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final List<XFile> mediaFiles;
  final List<PostAttachment> existingAttachments;
  final ValueChanged<PostCategory> onCategoryChanged;
  final VoidCallback? onPickMedia;
  final ValueChanged<int> onRemoveMedia;
  final ValueChanged<int>? onRemoveExistingAttachment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryStyle = CommunityText.secondary(context)
        .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0);
    final selectedCategoryLabel =
        tr(context, selectedCategory.label).toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(tr(context, 'POST TO'), style: categoryStyle),
            AppDropdown<PostCategory>(
              key: const ValueKey('community-category-filter'),
              value: selectedCategory,
              selectedLabel: selectedCategoryLabel,
              triggerHeight: 48,
              // 폭 측정은 공통 드롭다운에 맡겨 선택 문구가 잘리지 않게 해요.
              triggerPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              backgroundColor: isDark ? AppPalette.lightGrey : AppPalette.white,
              foregroundColor: colors.onSurface,
              textStyle: categoryStyle,
              options: PostCategory.values
                  .map(
                    (category) => AppDropdownOption<PostCategory>(
                      value: category,
                      label: tr(context, category.label).toUpperCase(),
                    ),
                  )
                  .toList(),
              onChanged: onCategoryChanged,
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          key: const ValueKey('community-post-title-input'),
          controller: titleController,
          style: CommunityText.title(context).copyWith(color: colors.onSurface),
          cursorColor: colors.onSurface,
          maxLines: null,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: tr(context, 'Title...'),
            counterText: '',
            hintStyle: CommunityText.title(context).copyWith(
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
          key: const ValueKey('community-post-body-input'),
          controller: bodyController,
          style: CommunityText.body(context).copyWith(color: colors.onSurface),
          cursorColor: colors.onSurface,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          maxLength: 10000,
          decoration: InputDecoration(
            hintText: tr(context, 'Write something...'),
            counterText: '',
            hintStyle: CommunityText.body(context).copyWith(
              color: appColors.mutedForeground,
            ),
            border: InputBorder.none,
            filled: false,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 28),
        if (existingAttachments.isNotEmpty || mediaFiles.isNotEmpty) ...[
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: existingAttachments.length + mediaFiles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final existing = index < existingAttachments.length;
                final attachment = existing ? existingAttachments[index] : null;
                final file = existing
                    ? null
                    : mediaFiles[index - existingAttachments.length];
                final mediaUrl = attachment?.mediaUrl;
                final isImage = mediaUrl != null &&
                    (attachment?.contentType?.startsWith('image/') ?? false);
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: existing
                          ? isImage
                              ? Image.network(mediaUrl,
                                  headers: apiImageHeaders(mediaUrl),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                        width: 100,
                                        height: 100,
                                        child:
                                            Icon(Icons.broken_image_outlined),
                                      ))
                              : SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: Center(
                                      child: Icon(
                                    attachment?.linkUrl != null
                                        ? Icons.link
                                        : Icons.videocam_outlined,
                                  )),
                                )
                          : file!.mimeType?.startsWith('video/') == true
                              ? const SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: Center(
                                      child: CommunityIcon('play', size: 40)))
                              : Image.file(File(file.path),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                        width: 100,
                                        height: 100,
                                        child: Icon(Icons.image_outlined),
                                      )),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        key: ValueKey(existing
                            ? 'community-existing-attachment-remove-$index'
                            : 'community-new-attachment-remove-${index - existingAttachments.length}'),
                        onTap: () => existing
                            ? onRemoveExistingAttachment?.call(index)
                            : onRemoveMedia(index - existingAttachments.length),
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
          padding: EdgeInsets.zero,
          color: isDark ? Colors.white54 : appColors.mutedForeground,
          strokeWidth: 1,
          dashPattern: const [6, 6],
          borderType: BorderType.RRect,
          radius: const Radius.circular(8),
          child: GestureDetector(
            onTap: onPickMedia,
            child: Container(
              key: const ValueKey('community-media-picker'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: isDark ? AppPalette.darkGrey : AppPalette.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CommunityIcon('add', size: 40),
                    const SizedBox(height: 8),
                    Text(
                      tr(context, 'Add photo or video'),
                      style: CommunityText.body(context)
                          .copyWith(color: colors.onSurface),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}

class PostComposerSubmitBar extends StatelessWidget {
  const PostComposerSubmitBar({
    super.key,
    required this.isSubmitting,
    required this.onSubmit,
    this.onSaveDraft,
  });

  final bool isSubmitting;
  final VoidCallback onSubmit;
  final VoidCallback? onSaveDraft;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 72),
      child: Column(children: [
        if (onSaveDraft != null) ...[
          AppActionButton(
            buttonKey: const ValueKey('community-draft-save'),
            label: trUpper(context, 'Save as draft'),
            onPressed: isSubmitting ? null : onSaveDraft,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppPalette.lightGrey
                : AppPalette.white,
            foregroundColor: colors.onSurface,
          ),
          const SizedBox(height: 16),
        ],
        AppActionButton(
          buttonKey: const ValueKey('community-post-submit'),
          label: tr(context, 'POST'),
          onPressed: onSubmit,
          loading: isSubmitting,
          progressKey: const ValueKey('community-post-submitting'),
        ),
      ]),
    );
  }
}
