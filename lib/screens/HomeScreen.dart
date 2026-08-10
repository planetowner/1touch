import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/data/home/mock/home_content_catalog.dart';
import 'package:onetouch/data/matches/mock/fixture_catalog.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import '../core/style.dart';
import '../core/stylesheet.dart';
import '../core/user_preferences.dart';
import '../models/team_overview.dart';
import '../models/fixture.dart';
import '../models/home_content_item.dart';
import '../data/home/home_content_service.dart';
import 'package:onetouch/features/index.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  List<TeamOverview> myTeam = [];
  bool isLoading = true;
  Color _teamColor = const Color(0xFFD82457);
  int? _activeFavoriteTeamId;
  final HomeContentService _contentService = HomeContentService();
  List<HomeContentItem> _highlights = List.of(homeContentFallbackItems);
  List<HomeContentItem> _news = List.of(homeContentFallbackItems);
  int _contentRequestId = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });

    _reloadWithFavorite(currentUserPreferences.favoriteTeamId.value);
    currentUserPreferences.favoriteTeamId
        .addListener(_onUserTeamPreferencesChanged);
    currentUserPreferences.followedTeamIds
        .addListener(_onUserTeamPreferencesChanged);
  }

  void _onUserTeamPreferencesChanged() {
    if (!mounted) return;
    _reloadWithFavorite(currentUserPreferences.favoriteTeamId.value);
  }

  void _reloadWithFavorite(int newFavoriteId) {
    final favoriteTeam = teamRepository.requireById(newFavoriteId);
    _activeFavoriteTeamId = newFavoriteId;

    final followingIds = currentUserPreferences.followedTeamIds.value;
    final ordered = [
      newFavoriteId,
      ...followingIds.where((id) => id != newFavoriteId),
    ];

    final teams = <TeamOverview>[];
    for (final id in ordered) {
      final team = teamRepository.requireById(id);
      final fixtures = fixturesByTeam(id);
      teams.add(TeamOverview(
        id: team.teamId,
        name: team.name,
        shortName: team.shortCode ?? '',
        imagePath: team.imagePath ?? '',
        nextMatch: fixtures
            .where((f) => f.status == FixtureStatus.upcoming)
            .firstOrNull,
        lastMatch:
            fixtures.where((f) => f.status == FixtureStatus.past).lastOrNull,
      ));
    }

    setState(() {
      _teamColor = Color(favoriteTeam.primaryColor);
      myTeam = teams;
      isLoading = false;
    });

    _loadHomeContent(newFavoriteId);
  }

  void _switchFavoriteTeam(int teamId) {
    currentUserPreferences.setFavoriteTeam(teamId);
  }

  Future<void> _loadHomeContent(int favoriteTeamId) async {
    final requestId = ++_contentRequestId;
    final results = await Future.wait([
      _contentService.fetchHighlights(favoriteTeamId: favoriteTeamId),
      _contentService.fetchNews(),
    ]);

    if (!mounted || requestId != _contentRequestId) return;
    setState(() {
      _highlights = _withFallbacks(results[0]);
      _news = _withFallbacks(results[1]);
    });
  }

  List<HomeContentItem> _withFallbacks(List<HomeContentItem> items) {
    final result = items.take(homeContentFallbackItems.length).toList();
    while (result.length < homeContentFallbackItems.length) {
      result.add(homeContentFallbackItems[result.length]);
    }
    return result;
  }

  @override
  void dispose() {
    currentUserPreferences.favoriteTeamId
        .removeListener(_onUserTeamPreferencesChanged);
    currentUserPreferences.followedTeamIds
        .removeListener(_onUserTeamPreferencesChanged);
    _scrollController.dispose();
    _contentService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);
    final pageBackground = mainPageBackground(context);
    final gradientHeight = responsiveBrandGradientHeight(context);
    final colorScheme = Theme.of(context).colorScheme;
    final appBarForeground = Color.lerp(
      AppPalette.white,
      colorScheme.onSurface,
      opacityFactor,
    )!;

    if (isLoading) {
      return Scaffold(
        backgroundColor: pageBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final favoriteTeamId = _activeFavoriteTeamId ?? myTeam.first.id;
    final favoriteMatches = fixturesByTeam(favoriteTeamId)
      ..sort((a, b) => a.startingAt.compareTo(b.startingAt));

    Fixture? liveMatch;
    if (myTeam.isNotEmpty && myTeam[0].nextMatch != null) {
      final match = myTeam[0].nextMatch!;
      final status = determineMatchStatus(DateTime.parse(match.startingAt));

      if (status == 'LIVE') {
        liveMatch = match;
      }
    }

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
                    colors: [_teamColor, pageBackground],
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
                        _teamColor.withValues(alpha: 1 - opacityFactor),
                        _teamColor.withValues(alpha: 0),
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
                                  myTeam.isNotEmpty ? myTeam[0].imagePath : '',
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
                  MyTeams(teams: myTeam),
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
                    allMatches: favoriteMatches,
                    favoriteTeamId: favoriteTeamId,
                  ),
                  const SizedBox(height: 32),
                  const SectionHeader(title: "HIGHLIGHTS"),
                  MyHighlights(highlights: _highlights),
                  const SizedBox(height: 32),
                  const SectionHeader(title: "NEWS"),
                  MyNews(news: _news),
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
