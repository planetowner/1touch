import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/football_names_loader.dart';
import 'package:onetouch/data/catalog/football_names.dart';
import 'package:go_router/go_router.dart';

// Core & Data
import 'package:onetouch/core/style.dart' as style;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/core/theme_controller.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/core/team_navigation.dart';
import 'package:onetouch/SessionScreen.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/auth/auth_repository_provider.dart'
    as auth_provider;
import 'package:onetouch/features/app_error_view.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/current_user_profile.dart';

// Feature Modules
import 'package:onetouch/screens/index.dart'; // Imports all screens
import 'package:onetouch/comm_pages/index.dart'; // Imports all profile pages
import 'package:onetouch/SignComps/index.dart'; // Imports auth components

// Root Level Pages
import 'package:onetouch/Splash.dart';
import 'package:onetouch/Onboarding.dart';
import 'package:onetouch/select_favorite_teams.dart';
import 'package:onetouch/WelcomeScreen.dart';

Future<void> main() => runOneTouchApp();

Future<void> runOneTouchApp({
  Future<bool> Function()? restoreSession,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await appThemeController.initialize();
  await appLocaleController.initialize();
  await (restoreSession ?? auth_provider.authService.restoreSession)();
  runApp(const MyApp());
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final _footballNames = FootballNamesRepository(apiClient);
final GoRouter _router = GoRouter(
  initialLocation: '/',
  navigatorKey: _rootNavigatorKey,
  redirect: (context, state) {
    final path = state.uri.path;
    if (path == '/' ||
        path == '/session' ||
        path == '/onboarding' ||
        path.startsWith('/auth/')) return null;
    if (!authSession.isAuthenticated) return '/onboarding';
    if (path.startsWith('/onboarding/') && footballCatalog.isLoaded)
      return null;
    return isAppSessionReady ? null : '/session';
  },
  errorBuilder: (context, state) => const AppErrorScreen(statusCode: 404),
  routes: [
    // Splash
    GoRoute(
      path: '/',
      builder: (context, state) => SplashScreen(
        nextLocation: ApiConfig.skipOnboardingForDevelopment ||
                authSession.isAuthenticated
            ? '/session'
            : '/onboarding',
      ),
    ),

    GoRoute(
        path: '/session', builder: (context, state) => const SessionScreen()),

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
      path: '/auth/signin',
      builder: (context, state) => const EmailSignInScreen(),
    ),
    GoRoute(
      path: '/auth/signup',
      builder: (context, state) => const EmailSignUpScreen(),
    ),
    GoRoute(
      path: '/auth/verify',
      builder: (context, state) {
        final draft = state.extra is EmailRegistrationDraft
            ? state.extra! as EmailRegistrationDraft
            : null;
        final email = draft?.email ?? state.uri.queryParameters['email'] ?? '';
        return EmailVerifyScreen(
          email: email,
          registrationDraft: draft,
        );
      },
    ),

    // 라우터와 하단 메뉴는 홈 → 팀 → 선수 → 커뮤니티 순서를 함께 사용해요.
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
            path: '/team',
            builder: (context, state) => const SizedBox(),
            routes: [
              GoRoute(
                path: ':id',
                redirect: (context, state) =>
                    redirectUnsupportedTeamPath(state.pathParameters['id']),
                builder: (context, state) {
                  final teamId = int.parse(state.pathParameters['id']!);
                  return TeamScreen(teamId: teamId);
                },
              ),
            ],
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
                  return PlayerCard(playerId: int.tryParse(playerId));
                },
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/community',
            builder: (context, state) => ValueListenableBuilder<int>(
              valueListenable: currentUserPreferences.viewedTeamId,
              builder: (context, teamId, _) => Community(teamId: teamId),
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
    GoRoute(
      path: '/profile/edit',
      builder: (c, s) => EditProfileScreen(
        profile: s.extra is CurrentUserProfile
            ? s.extra as CurrentUserProfile
            : null,
      ),
    ),
    GoRoute(
        path: '/profile/notification',
        builder: (c, s) => NotificationListPage()),
    GoRoute(
      path: '/profile/notification/team/:name',
      builder: (c, s) => TeamNotificationDetailPage(
        teamName: Uri.decodeComponent(s.pathParameters['name']!),
        teamId: int.tryParse(s.uri.queryParameters['id'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/profile/notification/player/:name',
      builder: (c, s) => PlayerNotificationDetailPage(
        playerName: Uri.decodeComponent(s.pathParameters['name']!),
        playerId: int.tryParse(s.uri.queryParameters['id'] ?? ''),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The body should simply be the navigationShell
      body: navigationShell,
      bottomNavigationBar: OneTouchBottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          // 팀 탭은 홈에서 현재 조회 중인 팀으로 열어요.
          if (index == 1) {
            openTeamPage(context, currentUserPreferences.viewedTeamId.value);
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
                context: context,
                index: 0,
                label: tr(context, 'Home'),
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                foreground: foreground,
              ),
              _buildItem(
                context: context,
                index: 1,
                label: tr(context, 'Team'),
                icon: Icons.local_police_outlined,
                activeIcon: Icons.local_police,
                foreground: foreground,
              ),
              _buildItem(
                context: context,
                index: 2,
                label: tr(context, 'Players'),
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                foreground: foreground,
              ),
              _buildItem(
                context: context,
                index: 3,
                label: tr(context, 'Community'),
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
    required BuildContext context,
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
                tr(context, label),
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
      builder: (context, themeMode, _) => ValueListenableBuilder<Locale>(
        valueListenable: appLocaleController,
        builder: (context, locale, _) => MaterialApp.router(
          locale: locale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          localeListResolutionCallback: resolveAppLocale,
          builder: (context, child) {
            Intl.defaultLocale = Localizations.localeOf(context).languageCode;
            return ListenableBuilder(
              listenable: authSession,
              builder: (context, _) => FootballNamesLoader(
                repository: _footballNames,
                enabled: authSession.isAuthenticated,
                child: child!,
              ),
            );
          },
          theme: style.whitetheme,
          darkTheme: style.darktheme,
          themeMode: themeMode,
          routerConfig: _router,
        ),
      ),
    );
  }
}
