import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/data/home/home_repository_provider.dart'
    as home_provider;
import 'package:onetouch/data/home/news_repository.dart';
import 'package:onetouch/data/home/news_repository_provider.dart'
    as news_provider;
import 'package:onetouch/data/teams/following_teams_repository.dart';
import 'package:onetouch/data/teams/following_teams_repository_provider.dart'
    as following_teams_provider;
import '../core/style.dart';
import '../core/stylesheet.dart';
import '../core/user_preferences.dart';
import '../models/home_content_item.dart';
import '../models/home_data.dart';
import '../models/team_overview.dart';
import 'package:onetouch/features/index.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.repository,
    this.newsRepository,
    this.followingTeamsRepository,
  });

  final HomeRepository? repository;
  final NewsRepository? newsRepository;
  final FollowingTeamsRepository? followingTeamsRepository;

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
  String _newsLanguage = '';
  bool? _wasTickerEnabled;
  int _homeRequestId = 0;
  int _newsRequestId = 0;
  bool _teamPreferenceRefreshScheduled = false;

  HomeRepository get _repository =>
      widget.repository ?? home_provider.homeRepository;
  NewsRepository get _newsRepository =>
      widget.newsRepository ?? news_provider.newsRepository;
  FollowingTeamsRepository get _followingTeamsRepository =>
      widget.followingTeamsRepository ??
      following_teams_provider.followingTeamsRepository;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });

    currentUserPreferences.favoriteTeamId
        .addListener(_onTeamPreferencesChanged);
    currentUserPreferences.followedTeamIds
        .addListener(_onTeamPreferencesChanged);
    _loadHome(refreshContent: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).toLanguageTag();
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final languageChanged =
        _newsLanguage.isNotEmpty && _newsLanguage != language;
    final returnedToTab = _wasTickerEnabled == false && tickerEnabled;
    _newsLanguage = language;
    _wasTickerEnabled = tickerEnabled;

    final homeData = _homeData;
    if (homeData != null && (languageChanged || returnedToTab)) {
      _loadNews(homeData.favoriteTeam.teamId);
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

  Future<void> _loadHome({bool refreshContent = false}) async {
    final requestId = ++_homeRequestId;
    if (_homeData == null) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final data = await _repository.load(
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

      if (refreshContent) {
        _loadNews(data.favoriteTeam.teamId);
      }
    } on Object {
      if (!mounted || requestId != _homeRequestId) return;
      setState(() {
        _homeData = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _switchFavoriteTeam(int teamId) async {
    final homeData = _homeData;
    if (homeData == null || homeData.favoriteTeam.teamId == teamId) return;

    final savedTeams = await _followingTeamsRepository.replaceFollowing(
      teamIds: homeData.followingTeams.map((team) => team.teamId),
      favoriteTeamId: teamId,
    );

    currentUserPreferences.applyServerSelection(UserTeamPreferences(
      favoriteTeamId: teamId,
      followedTeamIds: savedTeams.map((team) => team.teamId).toList(),
    ));
  }

  void _loadCalendarMonth(DateTime month) {
    _calendarMonth = month;
    _loadHome();
  }

  Future<void> _loadNews(int teamId) async {
    final requestId = ++_newsRequestId;
    setState(() {
      _news = const [];
      _isNewsLoading = true;
      _hasNewsError = false;
    });
    try {
      final news = await _newsRepository.loadForTeam(
        teamId,
        language: _newsLanguage,
      );
      if (!mounted || requestId != _newsRequestId) return;
      setState(() {
        _news = news;
        _isNewsLoading = false;
      });
    } on Object {
      if (!mounted || requestId != _newsRequestId) return;
      setState(() {
        _news = const [];
        _isNewsLoading = false;
        _hasNewsError = true;
      });
    }
  }

  @override
  void dispose() {
    currentUserPreferences.favoriteTeamId
        .removeListener(_onTeamPreferencesChanged);
    currentUserPreferences.followedTeamIds
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
              Text('Unable to load Home.', style: Body1.style),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const ValueKey('home-retry-button'),
                onPressed: () => _loadHome(refreshContent: true),
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }

    final team = homeData.favoriteTeam;
    final favoriteTeam = TeamOverview(
      id: team.teamId,
      name: team.name,
      shortName: team.shortCode ?? '',
      imagePath: team.imagePath ?? '',
      liveMatch: homeData.liveMatch,
      nextMatch: homeData.nextMatch,
      lastMatch: homeData.lastMatch,
    );
    final favoriteTeamId = favoriteTeam.id;
    return Scaffold(
      backgroundColor: pageBackground,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
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
                        // New Dropdown Feature
                        GestureDetector(
                          onTap: () => TeamSelectionSheet.show(
                            context,
                            initialFavoriteTeamId: favoriteTeamId,
                            followingTeams: homeData.followingTeams,
                            onSwitch: _switchFavoriteTeam,
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
                                  favoriteTeam.imagePath,
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
                  const SectionHeader(title: "FAVORITE TEAM"),
                  FavoriteTeamCard(team: favoriteTeam),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      const SectionHeader(title: "CALENDAR"),
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
                    favoriteTeamId: favoriteTeamId,
                    onMonthChanged: _loadCalendarMonth,
                  ),
                  const SizedBox(height: 32),
                  const SectionHeader(title: "HIGHLIGHTS"),
                  MyHighlights(
                    highlights: homeData.highlights,
                    fallbacks: const [],
                  ),
                  const SizedBox(height: 32),
                  const SectionHeader(title: "NEWS"),
                  MyNews(
                    news: _news,
                    isLoading: _isNewsLoading,
                    hasError: _hasNewsError,
                    isKorean: _newsLanguage.toLowerCase().startsWith('ko'),
                    onRetry: () => _loadNews(homeData.favoriteTeam.teamId),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      width: 395,
                      height: 108,
                      padding: const EdgeInsets.all(8),
                      decoration: ShapeDecoration(
                        color: Theme.of(context).brightness == Brightness.light
                            ? AppPalette.black
                            : AppPalette.darkGrey,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Center(
                        child: Text(
                          "Ad",
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
      child: Text(title, style: Body2_b.style),
    );
  }
}
