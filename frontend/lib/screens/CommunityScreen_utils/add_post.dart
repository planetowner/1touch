import 'dart:async';
import 'package:flutter/material.dart';
import 'package:onetouch/core/app_snack_bar.dart';
import 'package:cross_file/cross_file.dart';
import 'package:onetouch/core/favorite_team.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/post_attachments/post_attachment_repository.dart';
import 'package:onetouch/data/post_attachments/post_attachment_repository_provider.dart'
    as attachment_providers;
import 'package:onetouch/data/post_attachments/platform_video_encoder.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/data/posts/post_repository_provider.dart'
    as post_providers;
import 'package:onetouch/data/posts/post_draft_repository_provider.dart';
import 'package:onetouch/data/posts/post_draft_repository.dart';
import 'package:onetouch/features/community/community_header_slivers.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'package:onetouch/features/community/post_attachment_publisher.dart';
import 'package:onetouch/features/community/post_composer_widgets.dart';
import 'package:onetouch/features/media/asset_media_picker.dart';
import 'package:onetouch/features/media/attachment_transfer_progress.dart';
import 'package:onetouch/features/media/video_encoder.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/post_draft.dart';
import 'package:onetouch/l10n/app_localizations.dart';

typedef PostMediaPicker = Future<List<XFile>> Function();

class AddPost extends StatefulWidget {
  const AddPost(
      {super.key,
      required this.initialDrafts,
      this.teamId,
      this.editingPost,
      this.postRepository,
      this.attachmentRepository,
      this.videoEncoder,
      this.pickMedia,
      this.draftRepository});
  final int? teamId;
  final Post? editingPost;
  final PostRepository? postRepository;
  final PostAttachmentRepository? attachmentRepository;
  final VideoEncoder? videoEncoder;
  final PostMediaPicker? pickMedia;
  final PostDraftRepository? draftRepository;
  final List<PostDraft> initialDrafts;
  @override
  State<AddPost> createState() => _AddPostState();
}

class _AddPostState extends State<AddPost> {
  PostCategory _selectedCategory = PostCategory.general;
  bool _isSubmitting = false,
      _isPickingMedia = false,
      _draftLoadFailed = false,
      _allowPop = false;
  PostDraft? _draft;
  List<PostDraft> _drafts = [];
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final List<XFile> _mediaFiles = [];
  AttachmentTransferProgress? _transferProgress;
  final List<PostAttachment> _existingAttachments = [];
  bool get _hasDraftContent =>
      _draft != null ||
      _titleController.text.trim().isNotEmpty ||
      _bodyController.text.trim().isNotEmpty ||
      _mediaFiles.isNotEmpty ||
      _existingAttachments.isNotEmpty;
  PostRepository get _postRepository =>
      widget.postRepository ?? post_providers.postRepository;
  PostAttachmentRepository get _attachmentRepository =>
      widget.attachmentRepository ??
      attachment_providers.postAttachmentRepository;
  late final PostDraftRepository _draftRepository =
      widget.draftRepository ?? postDraftRepository;
  PostAttachmentPublisher get _publisher => PostAttachmentPublisher(
      postRepository: _postRepository,
      attachmentRepository: _attachmentRepository,
      videoEncoder: widget.videoEncoder ?? PlatformVideoEncoder());

  void _onEncodingProgress(double fraction, int fileIndex) {
    _setTransferProgress(AttachmentTransferProgress(
      phase: AttachmentTransferPhase.encoding,
      fileIndex: fileIndex,
      fileCount: _mediaFiles.length,
      fraction: fraction,
    ));
  }

  void _onVerificationProgress(double fraction, int fileIndex) {
    _setTransferProgress(AttachmentTransferProgress(
      phase: AttachmentTransferPhase.verifying,
      fileIndex: fileIndex,
      fileCount: _mediaFiles.length,
      fraction: fraction,
    ));
  }

  void _setTransferProgress(AttachmentTransferProgress progress) {
    if (!mounted) return;
    if (_transferProgress?.phase == progress.phase &&
        _transferProgress?.fileIndex == progress.fileIndex &&
        _transferProgress?.percent == progress.percent) {
      return;
    }
    setState(() => _transferProgress = progress);
  }

  void _onUploadProgress(int sent, int total, int fileIndex) {
    _setTransferProgress(AttachmentTransferProgress(
      phase: AttachmentTransferPhase.uploading,
      fileIndex: fileIndex,
      fileCount: _mediaFiles.length,
      fraction: total == 0 ? null : sent / total,
    ));
  }

  void _onSaving() {
    _setTransferProgress(AttachmentTransferProgress(
      phase: AttachmentTransferPhase.saving,
      fileIndex: _mediaFiles.isEmpty ? 0 : _mediaFiles.length - 1,
      fileCount: _mediaFiles.length,
    ));
  }

  @override
  void initState() {
    super.initState();
    // 조회를 마친 목록으로 첫 화면을 그려 버튼과 입력란을 함께 보여줘요.
    _drafts = List.of(widget.initialDrafts);
    _titleController.addListener(_composerChanged);
    _bodyController.addListener(_composerChanged);
    final post = widget.editingPost;
    if (post != null) {
      _selectedCategory = post.category;
      _titleController.text = post.title;
      _bodyController.text = post.body;
      _existingAttachments.addAll(post.attachments);
    }
  }

  void _composerChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadDrafts() async {
    final language = Localizations.localeOf(context).languageCode;
    final team = widget.teamId ?? FavoriteTeam.id.value;
    try {
      final drafts = await _draftRepository.loadDraftsFor(
          teamId: team, language: language);
      if (mounted) {
        setState(() {
          _drafts = drafts;
          _draftLoadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        _draftLoadFailed = true;
        showAppSnackBar(
          context,
          tr(context, 'Unable to load drafts. Tap to retry.'),
          onTap: _loadDrafts,
        );
      }
    }
  }

  Future<void> _resumeDraft() async {
    int? deletingId;
    final draft = await showModalBottomSheet<PostDraft>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppPalette.darkGrey
            : AppPalette.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetContext) => StatefulBuilder(
            builder: (sheetContext, setSheetState) => SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * .77,
                child: ScaffoldMessenger(
                    child: Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Builder(builder: (noticeContext) {
                          return SafeArea(
                              top: false,
                              child: Column(children: [
                                Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        24, 16, 16, 24),
                                    child: SizedBox(
                                        height: 32,
                                        child: Stack(children: [
                                          Center(
                                              child: Text(
                                                  tr(noticeContext, 'Drafts'),
                                                  style: CommunityText.title(
                                                      noticeContext))),
                                          Positioned(
                                              right: 0,
                                              child: IconButton(
                                                  key: const ValueKey(
                                                      'community-drafts-close'),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints
                                                          .tightFor(
                                                          width: 32,
                                                          height: 32),
                                                  icon: const CommunityIcon(
                                                      'close'),
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          sheetContext))),
                                        ]))),
                                Expanded(
                                    child: ListView.separated(
                                        // 마지막 행의 16px 여백 뒤에 시트의 24px 하단 여백을 둬요.
                                        padding: const EdgeInsets.fromLTRB(
                                            24, 0, 24, 24),
                                        itemCount: _drafts.length,
                                        separatorBuilder: (_, __) => Divider(
                                            height: 1,
                                            color: communityDividerColor(
                                                noticeContext)),
                                        itemBuilder: (itemContext, index) {
                                          final item = _drafts[index];
                                          return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16),
                                              child: Row(children: [
                                                Expanded(
                                                    child: InkWell(
                                                        onTap: deletingId ==
                                                                null
                                                            ? () =>
                                                                Navigator.pop(
                                                                    sheetContext,
                                                                    item)
                                                            : null,
                                                        child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Row(children: [
                                                                Flexible(
                                                                    child: Text(
                                                                        item.title.isEmpty
                                                                            ? tr(noticeContext,
                                                                                'Untitled post')
                                                                            : item
                                                                                .title,
                                                                        maxLines:
                                                                            1,
                                                                        overflow:
                                                                            TextOverflow
                                                                                .ellipsis,
                                                                        style: CommunityText.secondaryBold(
                                                                            noticeContext))),
                                                                const CommunityIcon(
                                                                    'chevron_right'),
                                                              ]),
                                                              const SizedBox(
                                                                  height: 4),
                                                              Text(item.body,
                                                                  maxLines: 2,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: CommunityText
                                                                      .secondary(
                                                                          noticeContext)),
                                                            ]))),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                    key: ValueKey(
                                                        'community-draft-delete-${item.postId}'),
                                                    icon: deletingId ==
                                                            item.postId
                                                        ? const SizedBox.square(
                                                            dimension: 18,
                                                            child:
                                                                CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2))
                                                        : const CommunityIcon(
                                                            'delete'),
                                                    onPressed: deletingId !=
                                                            null
                                                        ? null
                                                        : () async {
                                                            setSheetState(() =>
                                                                deletingId =
                                                                    item.postId);
                                                            try {
                                                              await _draftRepository
                                                                  .deleteDraft(
                                                                      item.postId);
                                                              if (!sheetContext
                                                                  .mounted) {
                                                                return;
                                                              }
                                                              setSheetState(() {
                                                                _drafts.removeWhere(
                                                                    (draft) =>
                                                                        draft
                                                                            .postId ==
                                                                        item.postId);
                                                                deletingId =
                                                                    null;
                                                              });
                                                              if (_draft
                                                                      ?.postId ==
                                                                  item.postId) {
                                                                // 열려 있던 초안을 지웠다면 뒤로가기에서 다시 만들지 않아요.
                                                                setState(() {
                                                                  _draft = null;
                                                                  _titleController
                                                                      .clear();
                                                                  _bodyController
                                                                      .clear();
                                                                  _existingAttachments
                                                                      .clear();
                                                                  _mediaFiles
                                                                      .clear();
                                                                  _selectedCategory =
                                                                      PostCategory
                                                                          .general;
                                                                });
                                                              }
                                                              showAppSnackBar(
                                                                  noticeContext,
                                                                  tr(noticeContext,
                                                                      'Deleted draft.'),
                                                                  duration:
                                                                      const Duration(
                                                                          seconds:
                                                                              5),
                                                                  replaceCurrent:
                                                                      true);
                                                            } catch (_) {
                                                              if (!sheetContext
                                                                  .mounted) {
                                                                return;
                                                              }
                                                              setSheetState(() =>
                                                                  deletingId =
                                                                      null);
                                                              showAppSnackBar(
                                                                  noticeContext,
                                                                  tr(noticeContext,
                                                                      'The service is temporarily unavailable. Please try again later.'),
                                                                  replaceCurrent:
                                                                      true);
                                                            }
                                                          }),
                                              ]));
                                        })),
                              ]));
                        }))))));
    if (!mounted) return;
    if (draft == null) {
      setState(() {});
      return;
    }
    setState(() {
      _draft = draft;
      _selectedCategory = draft.category;
      _titleController.text = draft.title;
      _bodyController.text = draft.body;
      _existingAttachments
        ..clear()
        ..addAll(draft.attachments);
      _mediaFiles.clear();
    });
  }

  Future<void> _pickMedia() async {
    if (_isPickingMedia || _isSubmitting) return;
    setState(() => _isPickingMedia = true);
    try {
      final maximum = await _postRepository.loadAttachmentLimit();
      if (!mounted) return;
      final remaining =
          maximum - _existingAttachments.length - _mediaFiles.length;
      if (remaining <= 0) {
        _showMessage(tr(context, 'You can attach up to {count} files.',
            {'count': maximum}));
        return;
      }
      final picked = await (widget.pickMedia?.call() ??
          pickAssetMedia(context, maxAssets: remaining.clamp(1, 10)));
      if (!mounted || picked.isEmpty) return;
      setState(() => _mediaFiles.addAll(picked.take(remaining)));
      if (picked.length > remaining) {
        _showMessage(tr(context, 'You can attach up to {count} files.',
            {'count': maximum}));
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
            tr(context, 'Unable to add attachments. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => _isPickingMedia = false);
    }
  }

  CreatePostInput _input(List<int> ids) => CreatePostInput(
      teamId: _draft?.teamId ?? widget.teamId ?? FavoriteTeam.id.value,
      language:
          _draft?.language ?? Localizations.localeOf(context).languageCode,
      category: _selectedCategory,
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      attachmentIds: ids);

  Future<void> _saveDraftContent() async {
    if (_mediaFiles.isNotEmpty) {
      _setTransferProgress(AttachmentTransferProgress(
        phase: AttachmentTransferPhase.preparing,
        fileIndex: 0,
        fileCount: _mediaFiles.length,
      ));
    }
    final draft = await _publisher.withUploadedAttachments<PostDraft>(
        mediaFiles: List.unmodifiable(_mediaFiles),
        existingIds: _existingAttachments.map((a) => a.attachmentId).toList(),
        onUploadProgress: _onUploadProgress,
        onEncodingProgress: _onEncodingProgress,
        onVerificationProgress: _onVerificationProgress,
        onSaving: _onSaving,
        save: (ids) =>
            _draftRepository.saveDraft(_input(ids), postId: _draft?.postId));
    if (!mounted) return;
    // 저장된 파일은 초안 소유예요. 게시 실패 후 재시도할 때 다시 업로드하지 않아요.
    setState(() {
      _draft = draft;
      _existingAttachments
        ..clear()
        ..addAll(draft.attachments);
      _mediaFiles.clear();
    });
  }

  Future<void> _saveDraft() async {
    if (_isSubmitting || _isPickingMedia) return;
    setState(() => _isSubmitting = true);
    try {
      await _saveDraftContent();
      if (mounted) await _finish(false);
    } catch (error) {
      if (mounted) {
        _showMessage(tr(
            context,
            error is VideoUploadException
                ? 'Unable to upload video.'
                : 'Unable to save draft. Please try again.'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _transferProgress = null;
        });
      }
    }
  }

  Future<void> _openDraftList() async {
    if (_isSubmitting || _isPickingMedia) return;
    if (_hasDraftContent) {
      setState(() => _isSubmitting = true);
      try {
        await _saveDraftContent();
        await _loadDrafts();
        // 불러오기 오류 안내는 _loadDrafts에서 재시도 동작과 함께 보여줘요.
        if (_draftLoadFailed) return;
      } catch (error) {
        if (mounted) {
          _showMessage(tr(
              context,
              error is VideoUploadException
                  ? 'Unable to upload video.'
                  : 'Unable to save draft. Please try again.'));
        }
        return;
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _transferProgress = null;
          });
        }
      }
    }
    if (mounted) await _resumeDraft();
  }

  Future<void> _finish(bool? result) async {
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, result);
  }

  Future<void> _exitComposer() async {
    if (_isSubmitting || _isPickingMedia) return;
    if (widget.editingPost != null) {
      Navigator.pop(context);
      return;
    }
    if (_hasDraftContent) {
      await _saveDraft();
    } else {
      await _finish(null);
    }
  }

  Future<void> _submitPost() async {
    if (_isSubmitting || _isPickingMedia) return;
    final title = _titleController.text.trim(),
        body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _showMessage(tr(context, 'Title and body are required.'));
      return;
    }
    setState(() {
      _isSubmitting = true;
      if (_mediaFiles.isNotEmpty) {
        _transferProgress = AttachmentTransferProgress(
          phase: AttachmentTransferPhase.preparing,
          fileIndex: 0,
          fileCount: _mediaFiles.length,
        );
      }
    });
    // 수정으로 제거될 첨부의 미리보기를 서버 삭제 전에 분리해요.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      final post = widget.editingPost;
      if (_draft != null) {
        await _saveDraftContent();
        await _draftRepository.publishDraft(_draft!.postId);
        if (_postRepository case CachedPostRepository cached) {
          await cached.invalidatePostCaches();
        }
      } else if (post == null) {
        await _publisher.publish(
            post: _input([]),
            mediaFiles: List.unmodifiable(_mediaFiles),
            onUploadProgress: _onUploadProgress,
            onEncodingProgress: _onEncodingProgress,
            onVerificationProgress: _onVerificationProgress,
            onSaving: _onSaving);
      } else {
        final update =
            await _publisher.withUploadedAttachments<UpdatePostInput>(
                mediaFiles: List.unmodifiable(_mediaFiles),
                existingIds:
                    _existingAttachments.map((a) => a.attachmentId).toList(),
                onUploadProgress: _onUploadProgress,
                onEncodingProgress: _onEncodingProgress,
                onVerificationProgress: _onVerificationProgress,
                onSaving: _onSaving,
                save: (ids) async {
                  final update = UpdatePostInput(
                      postId: post.postId,
                      category: _selectedCategory,
                      title: title,
                      body: body,
                      attachmentIds: ids);
                  await _postRepository.updatePost(update);
                  return update;
                });
        if (mounted) Navigator.pop(context, update);
        return;
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        _showMessage(tr(
            context,
            error is VideoUploadException
                ? 'Unable to upload video.'
                : widget.editingPost == null
                    ? 'Unable to publish post. Please try again.'
                    : 'Unable to update post. Please try again.'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _transferProgress = null;
        });
      }
    }
  }

  void _showMessage(String message) => showAppSnackBar(context, message);
  @override
  Widget build(BuildContext context) {
    return PopScope(
        // 저장할 내용이 없는 화면은 iOS의 기본 뒤로가기 제스처도 허용해요.
        canPop: widget.editingPost != null ||
            _allowPop ||
            (!_hasDraftContent && !_isSubmitting && !_isPickingMedia),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_exitComposer());
        },
        child: Scaffold(
          backgroundColor: communityPageBackground(context),
          appBar: AppBar(
              backgroundColor: communityPageBackground(context),
              toolbarHeight: 56,
              elevation: 0,
              leading: IconButton(
                  icon: const CommunityIcon('back'), onPressed: _exitComposer),
              actions: const [CommunityHeaderActions()]),
          body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_drafts.isNotEmpty)
                      GestureDetector(
                          key: const ValueKey('community-resume-draft'),
                          onTap: _isSubmitting || _isPickingMedia
                              ? null
                              : _openDraftList,
                          child: Container(
                              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                              decoration: BoxDecoration(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppPalette.lightGrey
                                      : AppPalette.white,
                                  borderRadius: BorderRadius.circular(16)),
                              child: Row(children: [
                                Expanded(
                                    child: Text(
                                        tr(context,
                                            'Pick up where you left off?'),
                                        style: CommunityText.body(context))),
                                const CommunityIcon('chevron_right')
                              ]))),
                    const SizedBox(height: 24),
                    AbsorbPointer(
                        absorbing: _isSubmitting,
                        child: PostComposerFields(
                            selectedCategory: _selectedCategory,
                            titleController: _titleController,
                            bodyController: _bodyController,
                            mediaFiles: _mediaFiles,
                            transferProgress: _transferProgress,
                            existingAttachments:
                                _isSubmitting && widget.editingPost != null
                                    ? const []
                                    : _existingAttachments,
                            onCategoryChanged: (category) =>
                                setState(() => _selectedCategory = category),
                            onPickMedia: _isPickingMedia || _isSubmitting
                                ? null
                                : _pickMedia,
                            onRemoveMedia: (index) =>
                                setState(() => _mediaFiles.removeAt(index)),
                            onRemoveExistingAttachment: (index) => setState(
                                () => _existingAttachments.removeAt(index)))),
                    PostComposerSubmitBar(
                        isSubmitting: _isSubmitting,
                        onSubmit: _submitPost,
                        onSaveDraft:
                            widget.editingPost == null ? _saveDraft : null),
                  ])),
        ));
  }
}
