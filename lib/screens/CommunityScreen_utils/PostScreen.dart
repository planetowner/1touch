import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/screens/CommunityScreen_utils/GroundRules.dart';
import 'package:onetouch/screens/CommunityScreen_utils/ReportDialog.dart';

String _timeAgo(String createdAt) {
  final created = DateTime.tryParse(createdAt) ?? DateTime.now();
  final diff = DateTime.now().difference(created);
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  return '${diff.inMinutes}m ago';
}


class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  // 1. Add Scroll Controller and Offset variable
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 2. Calculate opacity (0.0 at top, 1.0 when scrolled down 150px)
    double opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);
    final post = widget.post;
    final hasMedia = post.mediaUrl != null;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 3. Background Gradient with AnimatedOpacity
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 400,
            child: AnimatedOpacity(
              opacity: (1 - opacityFactor), // Fades out as you scroll down
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFD82457), Color(0x00D82457)],
                    stops: [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          CustomScrollView(
            controller: _scrollController, // Bind the controller
            slivers: [
              SliverAppBar(
                // 4. Fade AppBar background to black as you scroll
                backgroundColor: Color.lerp(Colors.transparent, Colors.black, opacityFactor),
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
                      colors: [Color(0xFFD82457), Color(0x00D82457)],
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

                    // Post content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User info
                          Row(
                            children: [
                              const CircleAvatar(
                                  radius: 12, backgroundColor: Colors.white24),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("User ${post.userId}", style: Body1.style),
                                  Text(
                                    _timeAgo(post.createdAt),
                                    style: Body2.style.copyWith(color: Colors.white54),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Text(post.title, style: Body1_b.style),
                          const SizedBox(height: 12),
                          Text(post.body, style: Body2.style),
                          const SizedBox(height: 16),

                          // Media section
                          if (hasMedia) _buildMediaPreview(post.mediaUrl!),
                          if (hasMedia) const SizedBox(height: 16),

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
                                  showReportDialog(context);
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

                    // Comment section
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

  Widget _buildMediaPreview(String mediaUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          mediaUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFF3A3A3A),
            child: const Icon(Icons.image_not_supported_outlined,
                color: Colors.white24, size: 48),
          ),
        ),
      ),
    );
  }
}