import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cross_file/cross_file.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/favorite_team.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/post_attachments/post_attachment_repository.dart';
import 'package:onetouch/data/post_attachments/post_attachment_repository_provider.dart'
    as attachment_providers;
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/data/posts/post_repository_provider.dart'
    as post_providers;
import 'package:onetouch/data/posts/api/api_post_draft_repository.dart';
import 'package:onetouch/data/posts/post_draft_repository.dart';
import 'package:onetouch/features/community/community_header_slivers.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'package:onetouch/features/community/post_attachment_publisher.dart';
import 'package:onetouch/features/community/post_composer_widgets.dart';
import 'package:onetouch/features/media/asset_media_picker.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/post_draft.dart';
import 'package:onetouch/l10n/app_localizations.dart';

typedef PostMediaPicker = Future<List<XFile>> Function();

class AddPost extends StatefulWidget {
  const AddPost(
      {super.key,
      this.teamId,
      this.editingPost,
      this.postRepository,
      this.attachmentRepository,
      this.pickMedia,
      this.draftRepository});
  final int? teamId;
  final Post? editingPost;
  final PostRepository? postRepository;
  final PostAttachmentRepository? attachmentRepository;
  final PostMediaPicker? pickMedia;
  final PostDraftRepository? draftRepository;
  @override
  State<AddPost> createState() => _AddPostState();
}

class _AddPostState extends State<AddPost> {
  PostCategory _selectedCategory = PostCategory.general;
  bool _isSubmitting = false,
      _isPickingMedia = false,
      _draftsLoaded = false,
      _draftLoadFailed = false;
  PostDraft? _draft;
  List<PostDraft> _drafts = [];
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final List<XFile> _mediaFiles = [];
  final List<PostAttachment> _existingAttachments = [];
  PostRepository get _postRepository =>
      widget.postRepository ?? post_providers.postRepository;
  PostAttachmentRepository get _attachmentRepository =>
      widget.attachmentRepository ??
      attachment_providers.postAttachmentRepository;
  late final PostDraftRepository _draftRepository =
      widget.draftRepository ?? ApiPostDraftRepository(api: apiClient);
  PostAttachmentPublisher get _publisher => PostAttachmentPublisher(
      postRepository: _postRepository,
      attachmentRepository: _attachmentRepository);

  @override
  void initState() {
    super.initState();
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_draftsLoaded && widget.editingPost == null) {
      _draftsLoaded = true;
      unawaited(_loadDrafts());
    }
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
      final drafts = <PostDraft>[];
      var offset = 0;
      while (true) {
        final page = await _draftRepository.loadDrafts(offset: offset);
        drafts.addAll(page.where(
            (draft) => draft.teamId == team && draft.language == language));
        if (page.length < 50) break;
        offset += page.length;
      }
      if (mounted) {
        setState(() {
          _drafts = drafts;
          _draftLoadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _draftLoadFailed = true);
    }
  }

  Future<void> _resumeDraft() async {
    final draft = await showModalBottomSheet<PostDraft>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .5,
                child: ListView(children: [
                  Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(tr(context, 'Drafts'),
                          style: CommunityText.title(context))),
                  for (final item in _drafts)
                    ListTile(
                        title: Text(item.title.isEmpty
                            ? tr(context, 'Untitled post')
                            : item.title),
                        subtitle: Text(item.body,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.pop(context, item)),
                ]))));
    if (draft == null || !mounted) return;
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
    final draft = await _publisher.withUploadedAttachments<PostDraft>(
        mediaFiles: List.unmodifiable(_mediaFiles),
        existingIds: _existingAttachments.map((a) => a.attachmentId).toList(),
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
      if (mounted) Navigator.pop(context, false);
    } catch (_) {
      if (mounted) {
        _showMessage(tr(context, 'Unable to save draft. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
    setState(() => _isSubmitting = true);
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
            post: _input([]), mediaFiles: List.unmodifiable(_mediaFiles));
      } else {
        final update =
            await _publisher.withUploadedAttachments<UpdatePostInput>(
                mediaFiles: List.unmodifiable(_mediaFiles),
                existingIds:
                    _existingAttachments.map((a) => a.attachmentId).toList(),
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
    } catch (_) {
      if (mounted) {
        _showMessage(tr(
            context,
            widget.editingPost == null
                ? 'Unable to publish post. Please try again.'
                : 'Unable to update post. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
  @override
  Widget build(BuildContext context) {
    final untouched = _draft == null &&
        _titleController.text.isEmpty &&
        _bodyController.text.isEmpty &&
        _mediaFiles.isEmpty;
    return Scaffold(
      backgroundColor: communityPageBackground(context),
      appBar: AppBar(
          backgroundColor: communityPageBackground(context),
          toolbarHeight: 56,
          elevation: 0,
          leading: IconButton(
              icon: const CommunityIcon('back'),
              onPressed: () => Navigator.pop(context)),
          actions: const [CommunityHeaderActions()]),
      body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (untouched && (_drafts.isNotEmpty || _draftLoadFailed))
              GestureDetector(
                  key: const ValueKey('community-resume-draft'),
                  onTap: _isSubmitting
                      ? null
                      : _draftLoadFailed
                          ? _loadDrafts
                          : _resumeDraft,
                  child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppPalette.lightGrey
                              : AppPalette.white,
                          borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        Expanded(
                            child: Text(
                                tr(
                                    context,
                                    _draftLoadFailed
                                        ? 'Unable to load drafts. Tap to retry.'
                                        : 'Pick up where you left off?'),
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
                    existingAttachments:
                        _isSubmitting && widget.editingPost != null
                            ? const []
                            : _existingAttachments,
                    onCategoryChanged: (category) =>
                        setState(() => _selectedCategory = category),
                    onPickMedia:
                        _isPickingMedia || _isSubmitting ? null : _pickMedia,
                    onRemoveMedia: (index) =>
                        setState(() => _mediaFiles.removeAt(index)),
                    onRemoveExistingAttachment: (index) =>
                        setState(() => _existingAttachments.removeAt(index)))),
            PostComposerSubmitBar(
                isSubmitting: _isSubmitting,
                onSubmit: _submitPost,
                onSaveDraft: widget.editingPost == null ? _saveDraft : null),
          ])),
    );
  }
}
