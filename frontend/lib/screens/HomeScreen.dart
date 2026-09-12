import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/data/home/home_content_repository.dart';
import 'package:onetouch/data/home/home_content_repository_provider.dart'
    as content_provider;
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/data/home/home_repository_provider.dart'
    as home_provider;
import '../core/style.dart';
import '../core/stylesheet.dart';
import '../core/user_preferences.dart';
import '../models/home_content.dart';
import '../models/home_data.dart';
import '../models/team_overview.dart';
import 'package:onetouch/features/index.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.repository,
    this.contentRepository,
  });

  final HomeRepository? repository;
  final HomeContentRepository? contentRepository;

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
  late final HomeContent _fallbackContent;
  late HomeContent _content;
  int _homeRequestId = 0;
  int _contentRequestId = 0;

  HomeRepository get _repository =>
      widget.repository ?? home_provider.homeRepository;
  HomeContentRepository get _contentRepository =>
      widget.contentRepository ?? content_provider.homeContentRepository;

  @override
  void initState() {
    super.initState();
    _fallbackContent = _contentRepository.fallback;
    _content = _fallbackContent;
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });

    currentUserPreferences.favoriteTeamId.addListener(_onFavoriteTeamChanged);
    _loadHome(refreshContent: true);
  }

  void _onFavoriteTeamChanged() {
    if (!mounted) return;
    _loadHome(refreshContent: true);
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
        _loadHomeContent(data.favoriteTeam.teamId);
      }
    } on Object {
      if (!mounted || requestId != _homeRequestId) return;
      setState(() {
        _homeData = null;
        _isLoading = false;
      });
    }
  }

  void _switchFavoriteTeam(int teamId) {
    currentUserPreferences.setFavoriteTeam(teamId);
  }

  void _loadCalendarMonth(DateTime month) {
    _calendarMonth = month;
    _loadHome();
  }

  Future<void> _loadHomeContent(int favoriteTeamId) async {
    final requestId = ++_contentRequestId;
    try {
      final content = await _contentRepository.loadForTeam(favoriteTeamId);
      if (!mounted || requestId != _contentRequestId) return;
      setState(() {
        _content = content;
      });
    } on Object {
      if (!mounted || requestId != _contentRequestId) return;
      setState(() {
        _content = _fallbackContent;
      });
    }
  }

  @override
  void dispose() {
    currentUserPreferences.favoriteTeamId
        .removeListener(_onFavoriteTeamChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);
    final pageBackground = mainPageBackground(context);
    final gradientHeight = responsiveBrandGradientHeight(context);
    final colorScheme = Theme.of(context).colorScheme;
    const appBarForeground = AppPalette.white;

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
    final teamColor = Color(team.primaryColor);

    return Scaffold(
      backgroundColor: pageBackground,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: gradientHeight,
            child: AnimatedOpacity(
              opacity: (1 - opacityFactor),
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: const ValueKey('home-brand-gradient'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [teamColor, pageBackground],
                    stops: const [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),
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
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        teamColor,
                        teamColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                title: Padding(
                  padding: const EdgeInsets.only(left: 24, top: 30),
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
                    padding: const EdgeInsets.only(right: 8, top: 30),
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
                        // New Dropdown Feature
                        GestureDetector(
                          onTap: () => TeamSelectionSheet.show(
                            context,
                            initialFavoriteTeamId: favoriteTeamId,
                            followingTeams: homeData.followingTeams,
                            onSwitch: _switchFavoriteTeam,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppPalette.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
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
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color: appBarForeground,
                                ),
                              ],
                            ),
                          ),
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
                    highlights: _content.highlights,
                    fallbacks: _fallbackContent.highlights,
                  ),
                  const SizedBox(height: 32),
                  const SectionHeader(title: "NEWS"),
                  MyNews(
                    news: _content.news,
                    fallbacks: _fallbackContent.news,
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
