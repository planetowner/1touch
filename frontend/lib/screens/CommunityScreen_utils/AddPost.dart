import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onetouch/core/favorite_team.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/post_attachments/post_attachment_repository.dart';
import 'package:onetouch/data/post_attachments/post_attachment_repository_provider.dart'
    as attachment_providers;
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/data/posts/post_repository_provider.dart'
    as post_providers;
import 'package:onetouch/features/community/post_attachment_publisher.dart';
import 'package:onetouch/features/community/post_composer_widgets.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/l10n/app_localizations.dart';

typedef PostMediaPicker = Future<List<XFile>> Function();

class AddPost extends StatefulWidget {
  final int? teamId;
  final PostRepository? postRepository;
  final PostAttachmentRepository? attachmentRepository;
  final PostMediaPicker? pickMedia;

  const AddPost({
    super.key,
    this.teamId,
    this.postRepository,
    this.attachmentRepository,
    this.pickMedia,
  });

  @override
  State<AddPost> createState() => _AddPostState();
}

class _AddPostState extends State<AddPost> {
  PostCategory _selectedCategory = PostCategory.general;
  bool _isSubmitting = false;

  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  final List<XFile> _mediaFiles = [];
  final ImagePicker _picker = ImagePicker();

  PostRepository get _postRepository =>
      widget.postRepository ?? post_providers.postRepository;
  PostAttachmentRepository get _attachmentRepository =>
      widget.attachmentRepository ??
      attachment_providers.postAttachmentRepository;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    const maximumAttachments = 10;
    if (_mediaFiles.length >= maximumAttachments) {
      _showMessage(tr(context, 'You can attach up to 10 files.'));
      return;
    }

    final picked =
        await (widget.pickMedia?.call() ?? _picker.pickMultipleMedia());
    if (!mounted || picked.isEmpty) return;

    final remaining = maximumAttachments - _mediaFiles.length;
    setState(() => _mediaFiles.addAll(picked.take(remaining)));
    if (picked.length > remaining) {
      _showMessage(tr(context, 'You can attach up to 10 files.'));
    }
  }

  Future<void> _submitPost() async {
    if (_isSubmitting) return;

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, "Title and body are required."))),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await PostAttachmentPublisher(
        postRepository: _postRepository,
        attachmentRepository: _attachmentRepository,
      ).publish(
        post: CreatePostInput(
          teamId: widget.teamId ?? FavoriteTeam.id.value,
          category: _selectedCategory,
          title: title,
          body: body,
        ),
        mediaFiles: List.unmodifiable(_mediaFiles),
      );
      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showMessage(tr(context, 'Unable to publish post. Please try again.'));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr(context, message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 2. Calculate Opacity Factor (0.0 to 1.0)
    double opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);
    final pageBackground = mainPageBackground(context);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: pageBackground,
      extendBodyBehindAppBar: true, // 3. Allow content/gradient behind AppBar
      appBar: AppBar(
        // 4. Fade AppBar to Black on scroll (starts transparent)
        backgroundColor: Color.lerp(
          Colors.transparent,
          pageBackground,
          opacityFactor,
        ),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: colors.onSurface,
          ),
          onPressed: () => context.pop(),
        ),
        toolbarHeight: 80,
        // Removed the static flexibleSpace gradient so it doesn't block the fading logic
      ),
      body: Stack(
        children: [
          // 6. Scrollable Content
          SingleChildScrollView(
            controller: _scrollController,
            // Keep interactive content below the transparent AppBar while the
            // team gradient continues behind it.
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.paddingOf(context).top + 80,
              24,
              0,
            ),
            child: PostComposerFields(
              selectedCategory: _selectedCategory,
              titleController: _titleController,
              bodyController: _bodyController,
              mediaFiles: _mediaFiles,
              onCategoryChanged: (category) {
                setState(() => _selectedCategory = category);
              },
              onPickMedia: _pickMedia,
              onRemoveMedia: (index) {
                setState(() => _mediaFiles.removeAt(index));
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: PostComposerSubmitBar(
        isSubmitting: _isSubmitting,
        onSubmit: _submitPost,
      ),
    );
  }
}
