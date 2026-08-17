import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart';
import 'package:onetouch/screens/MatchScreen_tabs/index.dart';
import 'package:onetouch/models/fixture.dart';

import '../core/stylesheet_dark.dart';

class MatchScreen extends StatefulWidget {
  final String matchId;
  final String matchStatus;

  const MatchScreen(
      {super.key, required this.matchId, required this.matchStatus});

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

    final id = int.tryParse(widget.matchId);
    fixture = id != null ? fixtureRepository.findById(id) : null;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final scaffoldBackground =
        isDark ? Colors.black : AppPalette.lightModeDarkGrey;
    final appBarBackground = isDark
        ? AppColors.of(context).pageBackground
        : AppPalette.lightModeDarkGrey;
    final selectedSurface = isDark ? AppPalette.white : AppPalette.black;
    final selectedForeground = isDark ? AppPalette.black : AppPalette.white;
    final unselectedSurface = isDark ? AppPalette.lightGrey : AppPalette.white;

    return Scaffold(
      key: const ValueKey('match-screen-scaffold'),
      backgroundColor: scaffoldBackground,
      body: NestedScrollView(
        key: const ValueKey('match-nested-scroll'),
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: appBarBackground,
            elevation: 0,
            floating: true,
            snap: true,
            pinned: false,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12), // or more if needed
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: foreground),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: () {
                  context.push('/search');
                },
                icon: Icon(Icons.search, size: 28, color: foreground),
              ),
              SizedBox(
                width: 8,
              ),
              IconButton(
                padding: EdgeInsets.only(right: 24),
                onPressed: () {
                  context.push('/profile');
                },
                icon: Icon(Icons.account_circle_outlined,
                    size: 28, color: foreground),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SingleChildScrollView(
                key: const ValueKey('match-tab-scroll'),
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
                            color: isSelected
                                ? selectedSurface
                                : unselectedSurface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            tabs[index],
                            style: Body2_b.style.copyWith(
                              color:
                                  isSelected ? selectedForeground : foreground,
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
    final foreground = Theme.of(context).colorScheme.onSurface;

    if (fixture == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Text('Match not found', style: TextStyle(color: foreground)),
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
        return LiveChatTab(
          matchId: fixture!.fixtureId,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
