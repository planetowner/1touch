import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/screens/MatchScreen_tabs/matchinfo.dart';
import 'package:onetouch/screens/MatchScreen_tabs/H2H.dart';
import 'package:onetouch/screens/MatchScreen_tabs/Anal.dart';
import 'package:onetouch/screens/MatchScreen_tabs/livechat.dart';
import 'package:onetouch/screens/MatchScreen_tabs/matchpreview.dart';

class MatchScreen extends StatefulWidget {
  final String matchId;
  final String matchStatus;

  const MatchScreen({super.key, required this.matchId, required this.matchStatus});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  int selectedIndex = 0;

  late List<String> tabs;

  @override
  void initState() {
    super.initState();

    // Assume you are passing matchStatus when navigating
    if (widget.matchStatus == 'past') {
      tabs = ['MATCH INFO', 'HEAD TO HEAD', 'ANALYSIS'];
    } else if (widget.matchStatus == 'live') {
      tabs = ['MATCH INFO', 'HEAD TO HEAD', 'LIVE CHAT'];
    } else {
      // upcoming
      tabs = ['MATCH PREVIEW', 'HEAD TO HEAD'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            elevation: 0,
            floating: true,
            snap: true,
            pinned: false,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12), // or more if needed
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // title: Text(
            //   tabs[selectedIndex].toUpperCase(), // ✅ dynamic title
            //   style: const TextStyle(
            //     color: Colors.white,
            //     fontSize: 16,
            //     fontWeight: FontWeight.bold,
            //     letterSpacing: 1.2,
            //   ),
            // ),
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: () {
                  context.push('/search');
                },
                icon: const Icon(Icons.search, size: 28, color: Colors.white),
              ),
              SizedBox(
                width: 8,
              ),
              IconButton(
                padding: EdgeInsets.only(right: 24),
                onPressed: () {
                  context.push('/profile');
                },
                icon: const Icon(Icons.account_circle_outlined,
                    size: 28, color: Colors.white),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: List.generate(tabs.length, (index) {
                    final isSelected = selectedIndex == index;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedIndex = index;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected ? Colors.white : Color(0xFF3D3D3D),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            tabs[index],
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildTabContent(),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    final selectedTab = tabs[selectedIndex];

    switch (selectedTab) {
      case 'MATCH INFO':
        return MatchInfoTab(matchId: widget.matchId, matchStatus: widget.matchStatus,);
      case 'MATCH PREVIEW':
        return MatchPreviewTab(matchId: widget.matchId);
      case 'HEAD TO HEAD':
        return H2HTab();
      case 'ANALYSIS':
        return AnalysisTab();
      case 'LIVE CHAT':
        return LiveChatTab();
      default:
        return const SizedBox.shrink();
    }
  }
}
