import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/fixtures/fixture_repository.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart'
    as fixture_provider;
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_detail.dart';
import 'package:onetouch/screens/MatchScreen_tabs/index.dart';

import '../core/stylesheet_dark.dart';

class MatchScreen extends StatefulWidget {
  final String matchId;
  final String matchStatus;
  final Fixture? initialFixture;
  final FixtureRepository? repository;

  const MatchScreen({
    super.key,
    required this.matchId,
    required this.matchStatus,
    this.initialFixture,
    this.repository,
  });

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  int selectedIndex = 0;
  late List<String> tabs;
  Fixture? fixture;
  FixtureDetail? _fixtureDetail;
  int? _fixtureId;
  bool _isLoading = false;
  bool _hasLoadError = false;

  FixtureRepository get _repository =>
      widget.repository ?? fixture_provider.fixtureDetailRepository;

  @override
  void initState() {
    super.initState();

    _fixtureId = int.tryParse(widget.matchId);
    if (_fixtureId != null) {
      final initialFixture = widget.initialFixture;
      fixture = initialFixture?.fixtureId == _fixtureId ? initialFixture : null;
      _isLoading = fixture == null;
      _loadFixture(_fixtureId!);
    }

    if (widget.matchStatus == 'past') {
      tabs = ['MATCH INFO', 'HEAD TO HEAD', 'ANALYSIS'];
    } else if (widget.matchStatus == 'live') {
      tabs = ['MATCH INFO', 'HEAD TO HEAD', 'LIVE CHAT'];
    } else {
      tabs = ['MATCH PREVIEW', 'HEAD TO HEAD'];
    }
  }

  Future<void> _loadFixture(int fixtureId) async {
    try {
      final detail = await _repository.loadDetail(fixtureId);
      if (!mounted) return;
      setState(() {
        fixture = detail.fixture;
        _fixtureDetail = detail;
        _isLoading = false;
        _hasLoadError = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasLoadError = fixture == null;
      });
    }
  }

  void _retryLoad() {
    final fixtureId = _fixtureId;
    if (fixtureId == null) return;
    setState(() {
      _isLoading = true;
      _hasLoadError = false;
    });
    _loadFixture(fixtureId);
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

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(
            key: ValueKey('match-loading-indicator'),
          ),
        ),
      );
    }

    if (_hasLoadError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Unable to load match.',
                style: TextStyle(color: foreground),
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const ValueKey('match-retry-button'),
                onPressed: _retryLoad,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

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
        return MatchInfoTab(
          fixture: fixture!,
          matchStatus: widget.matchStatus,
          detail: _fixtureDetail,
        );
      case 'MATCH PREVIEW':
        return MatchPreviewTab(
          fixture: fixture!,
          fixtureRepository: _repository,
        );
      case 'HEAD TO HEAD':
        return H2HTab(
          fixture: fixture!,
          fixtureRepository: _repository,
        );
      case 'ANALYSIS':
        return AnalysisTab(
          fixture: fixture!,
          detail: _fixtureDetail,
        );
      case 'LIVE CHAT':
        return LiveChatTab(
          matchId: fixture!.fixtureId,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
