import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/post_type.dart';
import 'package:onetouch/screens/CommunityScreen_utils/GroundRules.dart';
import 'package:onetouch/screens/CommunityScreen_utils/ReportDialog.dart';

class PostDetailScreen extends StatefulWidget {
  final PostType postType;

  const PostDetailScreen({super.key, required this.postType});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: Row(
              children: [
                const Spacer(),
                const Icon(Icons.star_border, color: Colors.white),
              ],
            ),
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
                  stops: [0.0, 0.9],
                ),
              ),
            ),
            floating: true,
            snap: true,
          ),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GestureDetector(
                    onTap: () {
                      // TODO: Add _showGroundRulesModal() like in All.dart
                      showGroundRulesModal(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D3D3D),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.push_pin_outlined,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 6),
                          Text("Community Ground Rules", style: Heading5.style),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 👤 Post content (we can modularize this later)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                              radius: 12, backgroundColor: Colors.white24),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Username", style: Body1.style),
                              Text("# hrs ago",
                                  style: Body2.style
                                      .copyWith(color: Colors.white54)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text("Title goes here", style: Body1_b.style),
                      const SizedBox(height: 12),
                      Text(
                        "FC Barcelona is more than just a football club; it's a symbol of passion and pride for its fans..."
                        "\n\nWith a rich history of success, including numerous La Liga and Champions League titles, Barcelona continues...",
                        style: Body2.style,
                      ),
                      const SizedBox(height: 16),

                      // Media section
                      if (widget.postType == PostType.video ||
                          widget.postType == PostType.image)
                        _buildMediaPreview(widget.postType),
                      const SizedBox(height: 16),

                      // Actions row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.thumb_up_alt_outlined,
                                  size: 18, color: Colors.white),
                              const SizedBox(width: 4),
                              Text("1,290", style: Body2.style),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Row(
                            children: [
                              const Icon(Icons.mode_comment_outlined,
                                  size: 18, color: Colors.white),
                              const SizedBox(width: 4),
                              Text("12", style: Body2.style),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Row(
                            children: [
                              const Icon(Icons.share,
                                  size: 18, color: Colors.white),
                              const SizedBox(width: 4),
                              Text("share", style: Body2.style),
                            ],
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              showReportDialog(
                                  context); // make sure this function is defined/imported
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.report_gmailerrorred_outlined,
                                    size: 18, color: Colors.white),
                                const SizedBox(width: 4),
                                Text("report", style: Body2.style),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 💬 Comment section (just mock for now)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(
                      3,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                                radius: 12, backgroundColor: Colors.white24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Username", style: Body2_b.style),
                                  Text(
                                    "First sentence goes here. Second sentence goes here. Third sentence goes here.",
                                    style: Body2.style,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.reply,
                                size: 18, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 64),
              ],
            ),
          ),
        ],
      ),

      // 📝 Reply bar
      bottomNavigationBar: Container(
        color: const Color(0xFF1C1C1E),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: "Write a reply...",
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.send, color: Colors.blueAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(PostType type) {
    return Row(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: type == PostType.video
                  ? const Icon(Icons.play_arrow, color: Colors.white, size: 48)
                  : Image.asset("assets/highlight1.png", fit: BoxFit.cover),
            ),
          ),
        ),
        if (type == PostType.video) const SizedBox(width: 8),
        if (type == PostType.video)
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
