import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
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
      case Category.general:         return 'General';
      case Category.analysis:        return 'Analysis';
      case Category.newsAndInsights: return 'News & Insights';
    }
  }

  PostCategory _mapCategory() {
    switch (_selectedCategory) {
      case Category.analysis:         return PostCategory.analysis;
      case Category.newsAndInsights:  return PostCategory.news;
      default:                        return PostCategory.general;
    }
  }

  void _submitPost() {
    final title = _titleController.text.trim();
    final body  = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Title and body are required.")),
      );
      return;
    }

    final now = DateTime.now().toIso8601String();
    final newPost = Post(
      postId:    DateTime.now().millisecondsSinceEpoch, // temp local ID
      userId:    1001,                                  // replace with auth user
      category:  _mapCategory(),
      title:     title,
      body:      body,
      mediaUrl:  _mediaFiles.isNotEmpty ? _mediaFiles.first.path : null,
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

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true, // 3. Allow content/gradient behind AppBar
      appBar: AppBar(
        // 4. Fade AppBar to Black on scroll (starts transparent)
        backgroundColor: Color.lerp(Colors.transparent, Colors.black, opacityFactor),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.star_border, color: Colors.white),
          ),
        ],
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
            height: 400,
            child: AnimatedOpacity(
              opacity: (1 - opacityFactor), // Fades to 0
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    // Using HomeScreen colors for consistency
                    colors: [Color(0xFFD82457), Color(0x00D82457)],
                    stops: [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),

          // 6. Scrollable Content
          SingleChildScrollView(
            controller: _scrollController,
            // Add top padding since we are behind the AppBar now
            padding: const EdgeInsets.fromLTRB(24, 100, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text("POST TO", style: Body2_b.style),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D3D3D),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: DropdownButton<Category>(
                        value: _selectedCategory,
                        onChanged: (value) =>
                            setState(() => _selectedCategory = value!),
                        items: Category.values.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Text(
                              _categoryLabel(cat).toUpperCase(),
                              style: Body1_b.style,
                            ),
                          );
                        }).toList(),
                        dropdownColor: const Color(0xFF3D3D3D),
                        underline: Container(),
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Title field
                TextField(
                  controller: _titleController,
                  style: Heading4.style,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: "Title...",
                    hintStyle: Heading4.style.copyWith(color: Colors.white38),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 12),

                // Body field
                TextField(
                  controller: _bodyController,
                  style: Body2.style,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: "Write something...",
                    hintStyle: Body2.style.copyWith(color: Colors.white38),
                    border: InputBorder.none,
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
                              top: 4, right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() => _mediaFiles.removeAt(index)),
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
                  color: Colors.white54,
                  strokeWidth: 1,
                  dashPattern: const [6, 6],
                  borderType: BorderType.RRect,
                  radius: const Radius.circular(12),
                  child: GestureDetector(
                    onTap: _pickMedia,
                    child: Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFF272828),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add, color: Colors.white, size: 28),
                            const SizedBox(height: 8),
                            Text("Add photo or video", style: Body2.style),
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
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text("POST",
                style: Body1_b.style.copyWith(color: Colors.black)),
          ),
        ),
      ),
    );
  }
}