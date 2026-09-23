import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/chat/chat_repository.dart';
import 'package:onetouch/data/chat/chat_socket.dart';
import 'package:onetouch/data/fixtures/fixture_repository.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart'
    as fixture_provider;
import 'package:onetouch/data/match_analysis/match_analysis_repository.dart';
import 'package:onetouch/data/profile/current_user_repository.dart';
import 'package:onetouch/data/standings/standing_repository.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_detail.dart';
import 'package:onetouch/data/betting/betting_repository.dart';
import 'package:onetouch/features/betting/betting_controller.dart';
import 'package:onetouch/screens/MatchScreen_tabs/index.dart';

import '../core/stylesheet_dark.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class MatchScreen extends StatefulWidget {
  final String matchId;
  final String matchStatus;
  final Fixture? initialFixture;
  final FixtureRepository? repository;
  final BettingRepository? bettingRepository;
  final MatchAnalysisRepository? analysisRepository;
  final StandingRepository? standingRepository;
  final ChatRepository? chatRepository;
  final ChatSocket? chatSocket;
  final CurrentUserRepository? currentUserRepository;

  const MatchScreen({
    super.key,
    required this.matchId,
    required this.matchStatus,
    this.initialFixture,
    this.repository,
    this.bettingRepository,
    this.analysisRepository,
    this.standingRepository,
    this.chatRepository,
    this.chatSocket,
    this.currentUserRepository,
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
  BettingController? _betting;

  FixtureRepository get _repository =>
      widget.repository ?? fixture_provider.fixtureDetailRepository;

  @override
  void initState() {
    super.initState();

    _fixtureId = int.tryParse(widget.matchId);
    if (_fixtureId != null) {
      // 두 탭이 같은 잔액·참여 내역을 공유해 변경 직후에도 비율이 일치해요.
      _betting = BettingController(
        fixtureId: _fixtureId!,
        repository: widget.bettingRepository,
      )..load();
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
        _hasLoadError = true;
      });
    }
  }

  @override
  void dispose() {
    _betting?.dispose();
    super.dispose();
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
    const selectedSurface = AppPalette.white;
    const selectedForeground = AppPalette.black;
    final unselectedSurface =
        isDark ? AppPalette.lightGrey : AppPalette.lightGreyBox;

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
              SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.only(right: 24),
                onPressed: () {
                  context.push('/profile');
                },
                icon: Icon(
                  Icons.account_circle_outlined,
                  size: 28,
                  color: foreground,
                ),
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
                          key: ValueKey('match-tab-$index'),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? selectedSurface
                                : unselectedSurface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: appCardShadows(context),
                          ),
                          child: Text(
                            tr(context, tabs[index]),
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
                tr(context, 'Unable to load match.'),
                style: TextStyle(color: foreground),
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const ValueKey('match-retry-button'),
                onPressed: _retryLoad,
                child: Text(tr(context, 'Retry')),
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
          child: Text(tr(context, 'Match not found'),
              style: TextStyle(color: foreground)),
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
          standingRepository: widget.standingRepository,
          fixture: fixture!,
          fixtureRepository: _repository,
          bettingController: _betting!,
        );
      case 'HEAD TO HEAD':
        return H2HTab(
          fixture: fixture!,
          fixtureRepository: _repository,
          bettingController: _betting!,
        );
      case 'ANALYSIS':
        return AnalysisTab(
          fixture: fixture!,
          detail: _fixtureDetail,
          repository: widget.analysisRepository,
        );
      case 'LIVE CHAT':
        return LiveChatTab(
          matchId: fixture!.fixtureId,
          repository: widget.chatRepository,
          socket: widget.chatSocket,
          currentUserRepository: widget.currentUserRepository,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
