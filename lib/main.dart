import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:onetouch/comm_pages/Profile.dart';
import 'package:onetouch/comm_pages/Profile_settings/About.dart';
import 'package:onetouch/comm_pages/Profile_settings/Contact.dart';
import 'package:onetouch/comm_pages/Profile_settings/InfoEdit.dart';
import 'package:onetouch/comm_pages/Profile_settings/Notification.dart';
import 'package:onetouch/comm_pages/Profile_settings/Preference.dart';
import 'package:onetouch/comm_pages/Search.dart';
import 'package:onetouch/core/style.dart' as style;
import 'package:onetouch/data/playerdata.dart';
import 'package:onetouch/screens/CommunityScreen.dart';
import 'package:onetouch/screens/HomeScreen.dart' as homescreen;
import 'package:onetouch/screens/MatchScreen.dart' as matchscreen;
import 'package:onetouch/screens/MoreScreen.dart';
import 'package:onetouch/screens/Player.dart';
import 'package:onetouch/screens/PlayerScreen.dart' as playerscreen;
import 'package:onetouch/screens/TeamScreen.dart';
import 'package:onetouch/Splash.dart';
import 'package:onetouch/Onboarding.dart';
import 'package:onetouch/SignComps/SignUp.dart';
import 'package:onetouch/SignComps/VerifyEmail.dart';


void main() {
  runApp(MyApp());
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GoRouter _router = GoRouter(
  initialLocation: '/', // ✅ 스플래시부터 시작
  navigatorKey: _rootNavigatorKey,
  routes: [
    // ❶ Splash
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),

    // ❷ Onboarding
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
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

    // ❸ 메인 탭 (기존 그대로)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => homescreen.HomeScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/players',
            builder: (context, state) => playerscreen.Players(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  var playerId = state.pathParameters['id']!;
                  var player = getPlayerById(playerId);
                  return PlayerCard(player: player);
                },
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/team',
            builder: (context, state) => More(),
            routes: [
              GoRoute(
                path: ':teamId',
                builder: (context, state) {
                  var teamId = state.pathParameters['teamId']!;
                  return TeamScreen(teamId: int.parse(teamId));
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
        return matchscreen.MatchScreen(matchId: matchId, matchStatus: matchStatus);
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
  ],
);


class MainScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  // The 'child' parameter is not needed for StatefulShellRoute.indexedStack
  const MainScreen({super.key, required this.navigationShell});

  int getFavoriteTeamName() {
    // This is just a placeholder. Replace with real user preference later.
    return 9;
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
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
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
