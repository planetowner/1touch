import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Core & Data
import 'package:onetouch/core/style.dart' as style;
import 'package:onetouch/data/playerdata.dart';

// Feature Modules
import 'package:onetouch/screens/index.dart';     // Imports all screens
import 'package:onetouch/comm_pages/index.dart'; // Imports all profile pages
import 'package:onetouch/SignComps/index.dart';  // Imports auth components

// Root Level Pages
import 'package:onetouch/Splash.dart';
import 'package:onetouch/Onboarding.dart';
import 'package:onetouch/select_favorite_teams.dart';
import 'package:onetouch/WelcomeScreen.dart';



void main() {
  runApp(MyApp());
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GoRouter _router = GoRouter(
  // initialLocation: '/', // 스플래시부터 시작
  initialLocation: '/home', // 테스팅 페이지
  navigatorKey: _rootNavigatorKey,
  routes: [
    // Splash
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
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
      ]
    ),
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
                  var playerId = state.pathParameters['id']!;
                  var player = getPlayerById(playerId);
                  return PlayerCard(player: player);
                },
              ),
              GoRoute(
                path: '/compare',
                builder: (context, state) => PlayerComparisonScreen(
                  initialPlayerName: state.extra as String?,
                ),
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
            builder: (context, state) => const Community(),
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
        return MatchScreen(matchId: matchId, matchStatus: matchStatus);
      },
    ),
    GoRoute(path: '/profile', builder: (c, s) => Profile()),
    GoRoute(path: '/profile/edit', builder: (c, s) => EditProfileScreen()),
    GoRoute(path: '/profile/notification', builder: (c, s) => NotificationListPage()),
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
        initialPlayerName: state.extra as String?,
      ),
    ),
  ],
);


class MainScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  // The 'child' parameter is not needed for StatefulShellRoute.indexedStack
  const MainScreen({super.key, required this.navigationShell});

  int getFavoriteTeamName() {
    // This is just a placeholder. Replace with real user preference later.
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The body should simply be the navigationShell
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.grey[900],
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
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        showSelectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            label: 'Home',
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home), // filled icon
          ),
          BottomNavigationBarItem(
            label: 'Players',
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
          ),
          BottomNavigationBarItem(
            label: 'Team',
            icon: Icon(Icons.local_police_outlined),
            activeIcon: Icon(Icons.local_police),
          ),
          BottomNavigationBarItem(
            label: 'Community',
            icon: Icon(Icons.people_alt_outlined),
            activeIcon: Icon(Icons.people_alt),
          ),
        ],
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      theme: style.darktheme,
      routerConfig: _router,
    );
  }
}
