import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onetouch/core/favorite_team.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/data/posts/post_repository_provider.dart'
    as post_providers;
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/features/community/post_composer_widgets.dart';
import 'package:onetouch/models/post.dart';

export 'package:onetouch/features/community/post_composer_widgets.dart'
    show Category;

class AddPost extends StatefulWidget {
  final int? teamId;
  final PostRepository? postRepository;

  const AddPost({super.key, this.teamId, this.postRepository});

  @override
  State<AddPost> createState() => _AddPostState();
}

class _AddPostState extends State<AddPost> {
  Category _selectedCategory = Category.general;
  bool _isSubmitting = false;

  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  final List<XFile> _mediaFiles = [];
  final ImagePicker _picker = ImagePicker();

  PostRepository get _postRepository =>
      widget.postRepository ?? post_providers.postRepository;

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
    final List<XFile> picked = await _picker.pickMultipleMedia();
    if (picked.isNotEmpty) {
      setState(() {
        _mediaFiles.addAll(picked);
      });
    }
  }

  PostCategory _mapCategory() {
    switch (_selectedCategory) {
      case Category.analysis:
        return PostCategory.analysis;
      case Category.newsAndInsights:
        return PostCategory.news;
      default:
        return PostCategory.general;
    }
  }

  Future<void> _submitPost() async {
    if (_isSubmitting) return;

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Title and body are required.")),
      );
      return;
    }

    // ImagePicker returns a device-local path, while POST /v1/posts expects a
    // remotely accessible media_url. TODO: Revisit when the API provides an
    // upload contract; upload selected media and submit the returned URL.
    // Until then, keep the draft intact and block media submission.
    if (_mediaFiles.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Media upload is not available yet.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _postRepository.createPost(
        CreatePostInput(
          teamId: widget.teamId ?? FavoriteTeam.id.value,
          category: _mapCategory(),
          title: title,
          body: body,
        ),
      );
      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to publish post. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2. Calculate Opacity Factor (0.0 to 1.0)
    double opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);
    final pageBackground = mainPageBackground(context);
    final gradientHeight = responsiveBrandGradientHeight(context);
    final colors = Theme.of(context).colorScheme;
    final favoriteTeamColor = Color(
      teamRepository.requireById(FavoriteTeam.id.value).primaryColor,
    );

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
          // 5. Background Gradient (Fades out on scroll)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: gradientHeight,
            child: AnimatedOpacity(
              opacity: (1 - opacityFactor), // Fades to 0
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: const ValueKey('community-add-brand-gradient'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      favoriteTeamColor,
                      favoriteTeamColor.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),

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
