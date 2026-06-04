import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/screens/MatchScreen_tabs/index.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/mock_data.dart';

import '../core/stylesheet_dark.dart';

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
  Fixture? fixture;

  @override
  void initState() {
    super.initState();

    // Look up fixture from mock data
    final id = int.tryParse(widget.matchId);
    fixture = id != null
        ? mockFixtures.where((f) => f.fixtureId == id).firstOrNull
        : null;

    if (widget.matchStatus == 'past') {
      tabs = ['MATCH INFO', 'HEAD TO HEAD', 'ANALYSIS'];
    } else if (widget.matchStatus == 'live') {
      tabs = ['MATCH INFO', 'HEAD TO HEAD', 'LIVE CHAT'];
    } else {
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
                            style: isSelected
                                ? Body2_b.style.copyWith(color: Colors.black)
                                : Body2_b.style,
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
    if (fixture == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: Text('Match not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final selectedTab = tabs[selectedIndex];
    switch (selectedTab) {
      case 'MATCH INFO':
        return MatchInfoTab(fixture: fixture!, matchStatus: widget.matchStatus);
      case 'MATCH PREVIEW':
        return MatchPreviewTab(fixture: fixture!);
      case 'HEAD TO HEAD':
        return H2HTab(fixture: fixture!);
      case 'ANALYSIS':
        return AnalysisTab(fixture: fixture!);
      case 'LIVE CHAT':
        return LiveChatTab(matchId: fixture!.fixtureId,);
      default:
        return const SizedBox.shrink();
    }
  }
}
