// ignore_for_file: file_names

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/chat/chat_repository.dart';
import 'package:onetouch/data/chat/chat_socket.dart';
import 'package:onetouch/data/fixtures/fixture_repository.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart'
    as fixture_provider;
import 'package:onetouch/data/match_analysis/match_analysis_repository.dart';
import 'package:onetouch/data/standings/standing_repository.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_detail.dart';
import 'package:onetouch/data/betting/betting_repository.dart';
import 'package:onetouch/features/betting/betting_controller.dart';
import 'package:onetouch/screens/MatchScreen_tabs/index.dart';

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
  final int? perspectiveTeamId;

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
    this.perspectiveTeamId,
  });

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with WidgetsBindingObserver {
  final ScrollController _tabScrollController = ScrollController();
  int selectedIndex = 0;
  late List<String> tabs;
  Fixture? fixture;
  FixtureDetail? _fixtureDetail;
  int? _fixtureId;
  bool _isLoading = false;
  bool _hasLoadError = false;
  BettingController? _betting;
  Timer? _refreshTimer;
  bool _requestInFlight = false;

  bool get _isLiveChatSelected =>
      selectedIndex < tabs.length && tabs[selectedIndex] == 'LIVE CHAT';

  List<String> _tabsFor(String status) => switch (status) {
        'past' => ['MATCH INFO', 'HEAD TO HEAD', 'Analysis'],
        'live' => ['MATCH INFO', 'HEAD TO HEAD', 'LIVE CHAT'],
        _ => ['MATCH PREVIEW', 'HEAD TO HEAD'],
      };

  FixtureRepository get _repository =>
      widget.repository ?? fixture_provider.fixtureDetailRepository;

  void _handleCachedDetail() {
    final fixtureId = _fixtureId;
    if (fixtureId == null) return;
    final cached = _repository.cachedDetail(fixtureId);
    if (cached == null || identical(_fixtureDetail, cached)) return;
    _applyDetail(cached);
  }

  void _applyDetail(FixtureDetail detail) {
    setState(() {
      final selectedTab = tabs[selectedIndex];
      fixture = detail.fixture;
      _fixtureDetail = detail;
      tabs = _tabsFor(detail.fixture.status.name);
      final nextIndex = tabs.indexOf(selectedTab);
      selectedIndex = nextIndex < 0 ? 0 : nextIndex;
      _isLoading = false;
      _hasLoadError = false;
    });
    _ensureLiveChatTabVisible();
  }

  void _selectTab(int index) {
    setState(() => selectedIndex = index);
    _ensureLiveChatTabVisible();
  }

  void _ensureLiveChatTabVisible() {
    if (!_isLiveChatSelected) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_tabScrollController.hasClients) return;
      _tabScrollController.animateTo(
        _tabScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    tabs = _tabsFor(widget.matchStatus);
    _repository.cachedDetails.addListener(_handleCachedDetail);

    _fixtureId = int.tryParse(widget.matchId);
    if (_fixtureId != null) {
      // 두 탭이 같은 잔액·참여 내역을 공유해 변경 직후에도 비율이 일치해요.
      _betting = BettingController(
        fixtureId: _fixtureId!,
        repository: widget.bettingRepository,
      )..load();
      final initialFixture = widget.initialFixture;
      _fixtureDetail = _repository.cachedDetail(_fixtureId!);
      fixture = _fixtureDetail?.fixture ??
          (initialFixture?.fixtureId == _fixtureId ? initialFixture : null);
      if (_fixtureDetail != null) {
        tabs = _tabsFor(fixture!.status.name);
      }
      _isLoading = fixture == null;
      _loadFixture(_fixtureId!);
    }
  }

  Future<void> _loadFixture(int fixtureId, {bool refresh = false}) async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    _refreshTimer?.cancel();
    try {
      var detail = await (refresh
          ? _repository.refreshDetail(fixtureId)
          : _repository.loadDetail(fixtureId));
      if (!refresh && _repository.isRefreshingDetail(fixtureId)) {
        detail = await _repository.refreshDetail(fixtureId);
      }
      if (!mounted) return;
      if (!identical(_fixtureDetail, detail)) _applyDetail(detail);
    } on Object {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // 재조회 실패로 이미 표시한 경기 전체를 오류 화면으로 바꾸지 않아요.
        if (!refresh && _fixtureDetail == null) _hasLoadError = true;
      });
    } finally {
      _requestInFlight = false;
      _scheduleRefresh();
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (!mounted || _fixtureId == null || _fixtureDetail == null) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    if (fixture?.status != FixtureStatus.live &&
        fixture?.status != FixtureStatus.upcoming) {
      return;
    }
    // 서버의 라이브 수집 주기에 맞춰 점수·상태·시계를 함께 다시 받아요.
    _refreshTimer = Timer(const Duration(seconds: 15),
        () => _loadFixture(_fixtureId!, refresh: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _refreshTimer?.cancel();
    if (state == AppLifecycleState.resumed &&
        _fixtureId != null &&
        (fixture?.status == FixtureStatus.live ||
            fixture?.status == FixtureStatus.upcoming)) {
      _loadFixture(_fixtureId!, refresh: true);
    }
  }

  @override
  void dispose() {
    _repository.cachedDetails.removeListener(_handleCachedDetail);
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _betting?.dispose();
    _tabScrollController.dispose();
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
    final foreground = Theme.of(context).colorScheme.onSurface;
    // 상단 바와 본문이 같은 배경을 써야 색 경계가 생기지 않아요.
    final pageBackground = mainPageBackground(context);
    final liveChatSelected = _isLiveChatSelected;

    return Scaffold(
      key: const ValueKey('match-screen-scaffold'),
      backgroundColor: pageBackground,
      body: NestedScrollView(
        key: const ValueKey('match-nested-scroll'),
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: pageBackground,
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
              Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('match-search-button'),
                      tooltip: tr(context, 'Search'),
                      onPressed: () => context.push('/search'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(Icons.search, size: 28, color: foreground),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      key: const ValueKey('match-profile-button'),
                      tooltip: tr(context, 'Profile'),
                      onPressed: () => context.push('/profile'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(
                        Icons.account_circle_outlined,
                        size: 28,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SliverPersistentHeader(
            pinned: liveChatSelected,
            delegate: _MatchTabsHeaderDelegate(
              extent: liveChatSelected ? 70 : 58,
              backgroundColor: pageBackground,
              child: Padding(
                padding: EdgeInsets.only(
                  top: 12,
                  bottom: liveChatSelected ? 24 : 12,
                ),
                child: SingleChildScrollView(
                  key: const ValueKey('match-tab-scroll'),
                  controller: _tabScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    key: const ValueKey('match-tab-list'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < tabs.length; index++) ...[
                        if (index > 0) const SizedBox(width: 8),
                        _MatchPillTab(
                          surfaceKey: ValueKey('match-tab-$index'),
                          label: trUpper(context, tabs[index]),
                          selected: selectedIndex == index,
                          onTap: () => _selectTab(index),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        body: liveChatSelected && _fixtureId != null
            ? LiveChatTab(
                matchId: _fixtureId!,
                repository: widget.chatRepository,
                socket: widget.chatSocket,
              )
            : SingleChildScrollView(
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
          child: FootballLoadingIndicator(
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
          detail: _fixtureDetail,
        );
      case 'MATCH PREVIEW':
        return MatchPreviewTab(
          perspectiveTeamId: widget.perspectiveTeamId,
          standingRepository: widget.standingRepository,
          fixture: fixture!,
          fixtureRepository: _repository,
          bettingController: _betting!,
        );
      case 'HEAD TO HEAD':
        return H2HTab(
          perspectiveTeamId: widget.perspectiveTeamId,
          fixture: fixture!,
          fixtureRepository: _repository,
          bettingController: _betting!,
        );
      case 'Analysis':
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
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _MatchTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _MatchTabsHeaderDelegate({
    required this.extent,
    required this.backgroundColor,
    required this.child,
  });

  final double extent;
  final Color backgroundColor;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      ColoredBox(color: backgroundColor, child: child);

  @override
  bool shouldRebuild(covariant _MatchTabsHeaderDelegate oldDelegate) =>
      extent != oldDelegate.extent ||
      backgroundColor != oldDelegate.backgroundColor ||
      child != oldDelegate.child;
}

class _MatchPillTab extends StatelessWidget {
  const _MatchPillTab({
    required this.surfaceKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key surfaceKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = appPillBackground(context, selected: selected);
    final foreground = appPillForeground(context, selected: selected);
    const radius = BorderRadius.all(Radius.circular(16));

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          child: Container(
            key: surfaceKey,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: const BoxDecoration(borderRadius: radius).copyWith(
              color: background,
            ),
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: Body2_b.style.copyWith(
                color: foreground,
                height: 1.3,
                leadingDistribution: TextLeadingDistribution.even,
              ),
              textHeightBehavior: const TextHeightBehavior(
                leadingDistribution: TextLeadingDistribution.even,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
