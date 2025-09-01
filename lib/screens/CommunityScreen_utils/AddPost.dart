import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xE5DB0030),
                Color(0x00B40000),
              ],
              stops: [0.0, 1],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                Text("POST TO", style: Body2_b.style),
                const SizedBox(width: 8),
                // POST TO dropdown
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

            // Title
            Text("Title goes here", style: Heading4.style),
            const SizedBox(height: 12),

            // Body
            Text(
              "FC Barcelona is more than just a football club; it's a symbol of passion and pride for its fans. "
              "The team's style of play, known as 'tiki-taka', showcases their commitment to teamwork and skill.\n\n"
              "With a rich history of success, including numerous La Liga and Champions League titles, "
              "Barcelona continues to inspire young athletes around the world...",
              style: Body2.style,
            ),
            const SizedBox(height: 24),

            // Media Picker placeholder
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
