import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onetouch/core/favorite_team.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/teams/mock/team_catalog.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/screens/CommunityScreen_utils/PostScreen.dart';

enum Category { general, analysis, newsAndInsights }

class AddPost extends StatefulWidget {
  const AddPost({super.key});

  @override
  State<AddPost> createState() => _AddPostState();
}

class _AddPostState extends State<AddPost> {
  Category _selectedCategory = Category.general;

  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  final List<XFile> _mediaFiles = [];
  final ImagePicker _picker = ImagePicker();

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

  String _categoryLabel(Category cat) {
    switch (cat) {
      case Category.general:
        return 'General';
      case Category.analysis:
        return 'Analysis';
      case Category.newsAndInsights:
        return 'News & Insights';
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

  void _submitPost() {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Title and body are required.")),
      );
      return;
    }

    final now = DateTime.now().toIso8601String();
    final newPost = Post(
      postId: DateTime.now().millisecondsSinceEpoch, // temp local ID
      userId: 1001, // replace with auth user
      category: _mapCategory(),
      title: title,
      body: body,
      mediaUrl: _mediaFiles.isNotEmpty ? _mediaFiles.first.path : null,
      createdAt: now,
      updatedAt: now,
    );

    // Navigate to PostDetailScreen, replacing this screen in the stack
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: newPost)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 2. Calculate Opacity Factor (0.0 to 1.0)
    double opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);
    final pageBackground = mainPageBackground(context);
    final gradientHeight = responsiveBrandGradientHeight(context);
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favoriteTeamColor =
        Color(mockTeamById(FavoriteTeam.id.value).primaryColor);
    final selectedCategoryLabel =
        _categoryLabel(_selectedCategory).toUpperCase();
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text("POST TO", style: Body2_b.style),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      width: categoryFilterWidth,
                      height: 48,
                      child: PopupMenuButton<Category>(
                        initialValue: _selectedCategory,
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
                        onSelected: (value) =>
                            setState(() => _selectedCategory = value),
                        itemBuilder: (context) => Category.values.map((cat) {
                          return PopupMenuItem<Category>(
                            value: cat,
                            child: Text(
                              _categoryLabel(cat).toUpperCase(),
                              style:
                                  Body1_b.style.copyWith(color: Colors.black),
                            ),
                          );
                        }).toList(),
                        child: Container(
                          key: const ValueKey('community-category-filter'),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppPalette.white,
                            borderRadius: BorderRadius.circular(24),
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
                                  style: Body1_b.style
                                      .copyWith(color: Colors.black),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.black,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Title field
                TextField(
                  controller: _titleController,
                  style: Heading4.style.copyWith(color: colors.onSurface),
                  cursorColor: colors.onSurface,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: "Title...",
                    hintStyle: Heading4.style
                        .copyWith(color: appColors.mutedForeground),
                    border: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 12),

                // Body field
                TextField(
                  controller: _bodyController,
                  style: Body2.style.copyWith(color: colors.onSurface),
                  cursorColor: colors.onSurface,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: "Write something...",
                    hintStyle:
                        Body2.style.copyWith(color: appColors.mutedForeground),
                    border: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 24),

                // Media preview (if any picked)
                if (_mediaFiles.isNotEmpty) ...[
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _mediaFiles.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(_mediaFiles[index].path),
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _mediaFiles.removeAt(index),
                                ),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 14),
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

                // Media picker button
                DottedBorder(
                  color: isDark ? Colors.white54 : appColors.mutedForeground,
                  strokeWidth: 1,
                  dashPattern: const [6, 6],
                  borderType: BorderType.RRect,
                  radius: const Radius.circular(12),
                  child: GestureDetector(
                    onTap: _pickMedia,
                    child: Container(
                      key: const ValueKey('community-media-picker'),
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF272828)
                            : const Color(0xFFC8C8C8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add,
                              color: colors.onSurface,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Add photo or video",
                              style:
                                  Body2.style.copyWith(color: colors.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.onSurface,
              foregroundColor: colors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              "POST",
              style: Body1_b.style.copyWith(color: colors.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
