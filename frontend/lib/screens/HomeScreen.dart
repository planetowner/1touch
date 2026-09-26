import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/main_tab_actions.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/data/home/home_repository_provider.dart'
    as home_provider;
import 'package:onetouch/data/home/news_repository.dart';
import 'package:onetouch/data/home/news_repository_provider.dart'
    as news_provider;
import '../core/style.dart';
import '../core/stylesheet.dart';
import '../core/user_preferences.dart';
import '../models/home_content_item.dart';
import '../models/home_data.dart';
import '../models/news_language.dart';
import '../models/team_overview.dart';
import 'package:onetouch/features/index.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.repository,
    this.newsRepository,
  });

  final HomeRepository? repository;
  final NewsRepository? newsRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  HomeData? _homeData;
  bool _isLoading = true;
  DateTime _calendarMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<HomeContentItem> _news = const [];
  bool _isNewsLoading = false;
  bool _hasNewsError = false;
  int? _newsTeamId;
  String _newsLanguage = '';
  bool? _wasTickerEnabled;
  int _homeRequestId = 0;
  int _newsRequestId = 0;
  bool _teamPreferenceRefreshScheduled = false;

  HomeRepository get _repository =>
      widget.repository ?? home_provider.homeRepository;
  NewsRepository get _newsRepository =>
      widget.newsRepository ?? news_provider.newsRepository;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });
    mainTabActions.addListener(_handleMainTabAction);

    currentUserPreferences.favoriteTeamId
        .addListener(_onTeamPreferencesChanged);
    currentUserPreferences.followedTeamIds
        .addListener(_onTeamPreferencesChanged);
    currentUserPreferences.viewedTeamId.addListener(_onTeamPreferencesChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = newsLanguageForLocale(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final initialLoad = _newsLanguage.isEmpty;
    final languageChanged = _newsLanguage != language;
    final returnedToTab = _wasTickerEnabled == false && tickerEnabled;
    _wasTickerEnabled = tickerEnabled;

    if (initialLoad) {
      // 첫 요청부터 화면 언어를 사용하고, 홈 응답을 기다리지 않아요.
      _loadHome(refreshContent: true);
    } else if (languageChanged || returnedToTab) {
      _loadNews(currentUserPreferences.viewedTeamId.value);
    }
  }

  void _onTeamPreferencesChanged() {
    if (!mounted || _teamPreferenceRefreshScheduled) return;
    _teamPreferenceRefreshScheduled = true;
    scheduleMicrotask(() {
      _teamPreferenceRefreshScheduled = false;
      if (!mounted) return;
      _loadHome(refreshContent: true);
    });
  }

  void _handleMainTabAction() {
    if (mainTabActions.tabIndex != 0 || !_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.minScrollExtent);
  }

  Future<void> _refreshHome() async {
    final teamId = currentUserPreferences.viewedTeamId.value;
    await Future.wait<void>([
      _loadHome(),
      _loadNews(teamId),
    ]);
  }

  Future<void> _loadHome({bool refreshContent = false}) async {
    final requestId = ++_homeRequestId;
    final teamId = currentUserPreferences.viewedTeamId.value;
    if (_homeData?.favoriteTeam.teamId != teamId) {
      // 다른 팀을 조회하는 동안 이전 팀의 카드와 늦게 도착한 뉴스를 보여주지 않아요.
      ++_newsRequestId;
      setState(() {
        _homeData = null;
        _isLoading = true;
      });
    }

    if (refreshContent) {
      unawaited(_loadNews(teamId));
    }

    try {
      final data = await _repository.load(
        teamId: teamId,
        start: _calendarMonth,
        end: DateTime(
          _calendarMonth.year,
          _calendarMonth.month + 1,
          0,
        ),
      );
      if (!mounted || requestId != _homeRequestId) return;

      setState(() {
        _homeData = data;
        _isLoading = false;
      });
    } on Object {
      if (!mounted || requestId != _homeRequestId) return;
      setState(() {
        _homeData = null;
        _isLoading = false;
      });
    }
  }

  void _switchViewedTeam(int teamId) => currentUserPreferences.viewTeam(teamId);

  void _loadCalendarMonth(DateTime month) {
    _calendarMonth = month;
    _loadHome();
  }

  Future<void> _loadNews(int teamId) async {
    final requestId = ++_newsRequestId;
    final language = newsLanguageForLocale(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final sameFeed = _newsTeamId == teamId && _newsLanguage == language;
    setState(() {
      // 같은 팀·언어를 갱신할 때는 기존 카드와 이미지를 유지해요.
      if (!sameFeed) _news = const [];
      _newsTeamId = teamId;
      _newsLanguage = language;
      _isNewsLoading = true;
      _hasNewsError = false;
    });
    try {
      final news = await _newsRepository.loadForTeam(
        teamId,
        language: language,
      );
      if (!mounted || requestId != _newsRequestId) return;
      setState(() {
        _news = news;
        _isNewsLoading = false;
      });
      // 아래로 스크롤하기 전에 이미지를 준비하고, 화면 표시는 기다리지 않아요.
      for (final item in news) {
        final imageUrl = item.imageUrl;
        if (imageUrl == null || imageUrl.isEmpty) continue;
        unawaited(precacheImage(
          NetworkImage(imageUrl),
          context,
          // 이미지 실패 표시는 공통 카드에서 처리하고 기사는 계속 보여줘요.
          onError: (_, __) {},
        ));
      }
    } on Object {
      if (!mounted || requestId != _newsRequestId) return;
      setState(() {
        _isNewsLoading = false;
        _hasNewsError = true;
      });
    }
  }

  @override
  void dispose() {
    mainTabActions.removeListener(_handleMainTabAction);
    currentUserPreferences.favoriteTeamId
        .removeListener(_onTeamPreferencesChanged);
    currentUserPreferences.followedTeamIds
        .removeListener(_onTeamPreferencesChanged);
    currentUserPreferences.viewedTeamId
        .removeListener(_onTeamPreferencesChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);
    final pageBackground = mainPageBackground(context);
    final colorScheme = Theme.of(context).colorScheme;
    final appBarForeground = colorScheme.onSurface;

    final homeData = _homeData;
    if (_isLoading && homeData == null) {
      return Scaffold(
        backgroundColor: pageBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (homeData == null) {
      return Scaffold(
        backgroundColor: pageBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr(context, 'Unable to load Home.'), style: Body1.style),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const ValueKey('home-retry-button'),
                onPressed: () => _loadHome(refreshContent: true),
                child: Text(tr(context, 'RETRY')),
              ),
            ],
          ),
        ),
      );
    }

    final team = homeData.favoriteTeam;
    final viewedTeam = TeamOverview(
      id: team.teamId,
      name: team.name,
      shortName: team.shortCode ?? '',
      imagePath: team.imagePath ?? '',
      standing: homeData.leaguePosition == null
          ? null
          : {
              'position': homeData.leaguePosition,
              'rank_delta': homeData.leagueRankDelta,
            },
      liveMatch: homeData.liveMatch,
      nextMatch: homeData.nextMatch,
      lastMatch: homeData.lastMatch,
    );
    final viewedTeamId = viewedTeam.id;
    return Scaffold(
      backgroundColor: pageBackground,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshHome,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Color.lerp(
                    Colors.transparent,
                    pageBackground,
                    opacityFactor,
                  ),
                  foregroundColor: appBarForeground,
                  elevation: 0,
                  floating: true,
                  snap: true,
                  toolbarHeight: 80,
                  centerTitle: false,
                  titleSpacing: 0,
                  flexibleSpace: ColoredBox(color: pageBackground),
                  clipBehavior: Clip.antiAlias,
                  title: Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: SvgPicture.asset(
                      'assets/app_logo.svg',
                      height: 23,
                      width: 120,
                      colorFilter: ColorFilter.mode(
                        appBarForeground,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              context.push('/search');
                            },
                            icon: Icon(
                              Icons.search,
                              color: appBarForeground,
                              size: 32,
                            ),
                          ),
                          SizedBox(
                            width: 16,
                          ),
                          GestureDetector(
                            onTap: () => TeamSelectionSheet.show(
                              context,
                              initialTeamId: viewedTeamId,
                              favoriteTeamId:
                                  currentUserPreferences.favoriteTeamId.value,
                              followingTeams: homeData.followingTeams,
                              onSwitch: _switchViewedTeam,
                            ),
                            child: Container(
                              padding: AppDropdownTokens.compactPadding,
                              decoration: BoxDecoration(
                                color: AppPalette.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                  AppDropdownTokens.radius,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Image.network(
                                    viewedTeam.imagePath,
                                    height: 24,
                                    width: 24,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      'TeamLogos/Barcelona.png',
                                      height: 24,
                                      width: 24,
                                    ),
                                  ),
                                  AppDropdownChevron(color: appBarForeground),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 16,
                          ),
                          IconButton(
                            onPressed: () {
                              context.push('/profile');
                            },
                            icon: Icon(
                              Icons.account_circle_outlined,
                              color: appBarForeground,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 48),
                    SectionHeader(title: tr(context, "FAVORITE TEAM")),
                    FavoriteTeamCard(team: viewedTeam),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        SectionHeader(title: tr(context, "CALENDAR")),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(right: 24),
                          child: IconButton(
                            icon: Icon(
                              Icons.sync,
                              color: colorScheme.onSurface,
                              size: 24,
                            ),
                            onPressed: () => SyncDialog.show(context),
                          ),
                        ),
                      ],
                    ),
                    FixtureCalendar(
                      allMatches: homeData.calendar,
                      favoriteTeamId: viewedTeamId,
                      participatingCompetitions:
                          footballCatalog.currentCompetitions(viewedTeamId),
                      onMonthChanged: _loadCalendarMonth,
                    ),
                    const SizedBox(height: 32),
                    SectionHeader(title: tr(context, "HIGHLIGHTS")),
                    MyHighlights(
                      highlights: homeData.highlights,
                      fallbacks: const [],
                    ),
                    const SizedBox(height: 32),
                    SectionHeader(title: tr(context, "NEWS")),
                    MyNews(
                      news: _news,
                      isLoading: _isNewsLoading,
                      hasError: _hasNewsError,
                      onRetry: () => _loadNews(homeData.favoriteTeam.teamId),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        width: 395,
                        height: 108,
                        padding: const EdgeInsets.all(8),
                        decoration: ShapeDecoration(
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? AppPalette.black
                                  : AppPalette.darkGrey,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Center(
                          child: Text(
                            tr(context, "Ad"),
                            style: Heading4.style.copyWith(
                              color: AppPalette.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Text(tr(context, title), style: Body2_b.style),
    );
  }
}
