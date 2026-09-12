import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Core & Data
import 'package:onetouch/core/style.dart' as style;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/core/theme_controller.dart';
import 'package:onetouch/core/favorite_team.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/players/player_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';

// Feature Modules
import 'package:onetouch/screens/index.dart'; // Imports all screens
import 'package:onetouch/comm_pages/index.dart'; // Imports all profile pages
import 'package:onetouch/SignComps/index.dart'; // Imports auth components

// Root Level Pages
import 'package:onetouch/Splash.dart';
import 'package:onetouch/Onboarding.dart';
import 'package:onetouch/select_favorite_teams.dart';
import 'package:onetouch/WelcomeScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appThemeController.initialize();
  // Initializes the team catalog before loading and validating stored IDs.
  await currentUserPreferences.initialize();
  await playerRepository.initializeFollowing();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // 이미 초기화된 경우 무시
  }
  runApp(const MyApp());
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GoRouter _router = GoRouter(
  initialLocation: '/',
  navigatorKey: _rootNavigatorKey,
  routes: [
    // Splash
    GoRoute(
      path: '/',
      builder: (context, state) => SplashScreen(
        nextLocation:
            ApiConfig.skipOnboardingForDevelopment ? '/home' : '/onboarding',
      ),
    ),

    // Onboarding
    GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
        routes: [
          GoRoute(
            path: 'welcome',
            builder: (context, state) => const WelcomeScreen(),
          ),
          GoRoute(
            path: 'select-favorites',
            builder: (context, state) => const SelectFavoriteTeamsScreen(),
          ),
        ]),
    GoRoute(
      path: '/auth/signup',
      builder: (context, state) => const EmailSignUpScreen(),
    ),
    GoRoute(
      path: '/auth/verify',
      builder: (context, state) {
        // 이전 화면에서 email을 query로 넘겨줌 ?email=...
        final email = state.uri.queryParameters['email'] ?? '';
        return EmailVerifyScreen(email: email);
      },
    ),

    // 메인 탭 (기존 그대로)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => HomeScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/players',
            builder: (context, state) => Players(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final playerId = state.pathParameters['id']!;
                  final player = playerRepository.findById(playerId) ??
                      playerRepository.allPlayers.first;
                  return PlayerCard(player: player);
                },
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/team',
            builder: (context, state) => const SizedBox(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  // 1. Get the ID string (default to "1")
                  final String idStr = state.pathParameters['id'] ?? '1';

                  // 2. Parse it to an integer
                  final int teamId = int.tryParse(idStr) ?? 1;

                  // 3. Pass the integer to TeamScreen
                  return TeamScreen(teamId: teamId);
                },
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/community',
            builder: (context, state) => ValueListenableBuilder<int>(
              valueListenable: FavoriteTeam.id,
              builder: (context, favoriteTeamId, _) =>
                  Community(teamId: favoriteTeamId),
            ),
          ),
        ]),
      ],
    ),

    // 기타 단일 화면 (기존 그대로)
    GoRoute(
      path: '/match/:matchId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final matchId = state.pathParameters['matchId'] ?? 'Unknown Match';
        final matchStatus = state.uri.queryParameters['status'] ?? 'upcoming';
        final routeData = state.extra;
        return MatchScreen(
          matchId: matchId,
          matchStatus: matchStatus,
          initialFixture: routeData is Fixture ? routeData : null,
        );
      },
    ),
    GoRoute(
        path: '/notifications',
        builder: (c, s) => const NotificationInboxPage()),
    GoRoute(path: '/profile', builder: (c, s) => Profile()),
    GoRoute(path: '/profile/edit', builder: (c, s) => EditProfileScreen()),
    GoRoute(
        path: '/profile/notification',
        builder: (c, s) => NotificationListPage()),
    GoRoute(
      path: '/profile/notification/team/:name',
      builder: (c, s) => TeamNotificationDetailPage(
        teamName: Uri.decodeComponent(s.pathParameters['name']!),
      ),
    ),
    GoRoute(
      path: '/profile/notification/player/:name',
      builder: (c, s) => PlayerNotificationDetailPage(
        playerName: Uri.decodeComponent(s.pathParameters['name']!),
      ),
    ),
    GoRoute(path: '/profile/preference', builder: (c, s) => PreferencePage()),
    GoRoute(path: '/profile/about', builder: (c, s) => AboutPage()),
    GoRoute(path: '/profile/contact', builder: (c, s) => ContactPage()),
    GoRoute(path: '/search', builder: (c, s) => Search()),
    GoRoute(
      path: '/compare',
      builder: (context, state) => PlayerComparisonScreen(
        initialPlayerId: state.extra as String?,
      ),
    ),
  ],
);

class MainScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  // The 'child' parameter is not needed for StatefulShellRoute.indexedStack
  const MainScreen({super.key, required this.navigationShell});

  int getFavoriteTeamName() => FavoriteTeam.id.value;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The body should simply be the navigationShell
      body: navigationShell,
      bottomNavigationBar: OneTouchBottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          // Special case for the 'Team' tab (index 2)
          if (index == 2) {
            context.go('/team/${getFavoriteTeamName()}');
            return; // Exit after handling the special case
          }

          // This single call handles both switching tabs and resetting the stack.
          // goBranch preserves the state of other tabs.
          // The 'initialLocation' parameter resets the stack if the tapped tab
          // is already the current one.
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

class OneTouchBottomNavigationBar extends StatelessWidget {
  const OneTouchBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    final background = style.AppColors.of(context).cardBackground;

    return ColoredBox(
      color: background,
      child: SafeArea(
        top: false,
        child: SizedBox(
          key: const ValueKey('main-bottom-navigation-content'),
          height: 68,
          child: Row(
            children: [
              _buildItem(
                index: 0,
                label: 'Home',
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                foreground: foreground,
              ),
              _buildItem(
                index: 1,
                label: 'Players',
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                foreground: foreground,
              ),
              _buildItem(
                index: 2,
                label: 'Team',
                icon: Icons.local_police_outlined,
                activeIcon: Icons.local_police,
                foreground: foreground,
              ),
              _buildItem(
                index: 3,
                label: 'Community',
                icon: Icons.people_alt_outlined,
                activeIcon: Icons.people_alt,
                foreground: foreground,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required Color foreground,
  }) {
    final isSelected = currentIndex == index;
    final itemColor =
        isSelected ? foreground : foreground.withValues(alpha: 0.65);

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '$label tab',
        child: InkWell(
          key: ValueKey('main-bottom-navigation-$index'),
          onTap: () => onTap(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: itemColor,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: itemColor,
                  fontSize: 14,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeController,
      builder: (context, themeMode, _) => MaterialApp.router(
        theme: style.whitetheme,
        darkTheme: style.darktheme,
        themeMode: themeMode,
        routerConfig: _router,
      ),
    );
  }
}
