import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/post_type.dart';

enum Category {
  general,
  analysis,
  newsAndInsights,
}

class Addpost extends StatefulWidget {
  final PostType? postType;

  const Addpost({super.key, this.postType});

  @override
  State<Addpost> createState() => _AddPostState();
}

class _AddPostState extends State<Addpost> {
  Category _selectedCategory = Category.general;

  // 1. Add ScrollController
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          // Track scroll offset up to 150px
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
                        onChanged: (Category? newValue) {
                          setState(() {
                            _selectedCategory = newValue!;
                          });
                        },
                        items: Category.values.map((Category category) {
                          return DropdownMenuItem<Category>(
                            value: category,
                            child: Text(
                              category.toString().split('.').last.toUpperCase(),
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

                Text("Title goes here", style: Heading4.style),
                const SizedBox(height: 12),

                Text(
                  "FC Barcelona is more than just a football club; it's a symbol of passion and pride for its fans. "
                      "The team's style of play, known as 'tiki-taka', showcases their commitment to teamwork and skill.\n\n"
                      "With a rich history of success, including numerous La Liga and Champions League titles, "
                      "Barcelona continues to inspire young athletes around the world...",
                  style: Body2.style,
                ),
                const SizedBox(height: 24),

                DottedBorder(
                  color: Colors.white54,
                  strokeWidth: 1,
                  dashPattern: [6, 6],
                  borderType: BorderType.RRect,
                  radius: Radius.circular(12),
                  child: GestureDetector(
                    onTap: () {},
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
            onPressed: () {},
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