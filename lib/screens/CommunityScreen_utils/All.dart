import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/screens/CommunityScreen_utils/PostScreen.dart';
import 'package:onetouch/data/post_type.dart';
import 'package:onetouch/screens/CommunityScreen_utils/GroundRules.dart';

class All extends StatefulWidget {
  final int selectedTabIndex;

  const All({super.key, required this.selectedTabIndex});

  @override
  State<All> createState() => _AllState();
}

class _AllState extends State<All> {
  String _selectedFilter = "Newest";
  late int _selectedTabIndex;

  List<PostType> _filteredPosts() {
    // For now, let's just return hardcoded logic --> need to build our own logic
    if (widget.selectedTabIndex == 1) {
      return [PostType.textOnly]; // General
    } else if (widget.selectedTabIndex == 2) {
      return [PostType.video]; // Analysis
    } else if (widget.selectedTabIndex == 3) {
      return [PostType.image]; // News & Insights
    } else {
      return [PostType.video, PostType.image, PostType.textOnly]; // All
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.selectedTabIndex;
  }

  @override
  Widget build(BuildContext context) {
    final posts = _filteredPosts();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // 🔘 Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 12,
            children: [
              _buildFilterChip("Newest"),
              _buildFilterChip("Popular"),
              _buildFilterChip("Best"),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 📜 Ground Rules button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GestureDetector(
            onTap: () {
              showGroundRulesModal(context); // We'll define this next
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF3D3D3D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.push_pin_outlined,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    "Community Ground Rules",
                    style: Heading5.style.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),
        // 🧵 Post list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: posts.length,
            itemBuilder: (context, index) => _buildPostCard(posts[index]),
            separatorBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(
                height: 1,
                color: const Color(0xFF3A3A3A), // matches the divider image
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFF272828),
          borderRadius: BorderRadius.circular(16), // Full pill shape
        ),
        child: Text(
          label.toUpperCase(),
          style: Body2_b.style.copyWith(
            color: isSelected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildPostCard(PostType type) {
    return GestureDetector(
      onTap: (){
        Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PostDetailScreen(postType: type)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 👤 User Info Row
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.white24,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          Text("Username", style: Body1.style),
                          Text("# hrs ago",
                              style: Body2.style.copyWith(color: Colors.white54)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 4),

                  Text("Title goes here", style: Body1_b.style),
                  const SizedBox(height: 4),

                  Text(
                    "First sentence goes here. Second sentence goes here. Third sentence goes here. Fourth sentence goes here...",
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Body2.style,
                  ),
                  const SizedBox(height: 8),

                  // ❤️ Like count
                  Row(
                    children: [
                      const Icon(Icons.thumb_up_alt_outlined,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text("1,290", style: Body2.style),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Right: Media preview (if video or image)
            if (type != PostType.textOnly)
              Stack(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: type == PostType.video
                        ? const Center(
                        child: Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 32))
                        : Image.asset("assets/highlight1.png", fit: BoxFit.cover),
                  ),
                  if (type == PostType.video)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child:
                        Text("+2", style: Body2.style.copyWith(fontSize: 12)),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRule(int i, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: RichText(
        text: TextSpan(
          style: Body2.style,
          children: [
            TextSpan(text: "${i + 1}. ", style: Body1_b.style),
            TextSpan(text: title, style: Body1_b.style),
            const TextSpan(text: "\n"),
            TextSpan(text: subtitle, style: Body1.style),
          ],
        ),
      ),
    );
  }
}
