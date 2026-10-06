import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/football_names_loader.dart';
import 'package:onetouch/data/catalog/football_names.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/services/mobile_ads_service.dart';
import 'package:onetouch/services/device_notification_service.dart';
import 'package:onetouch/services/firebase_push_messaging_service.dart';
import 'package:onetouch/services/firebase_push_notification_handler.dart';
import 'package:onetouch/services/push_device_registration_service_provider.dart';
import 'package:onetouch/data/notifications/notification_unread_controller_provider.dart';
import 'package:onetouch/debug/mock_live_match.dart';

// Core & Data
import 'package:onetouch/core/style.dart' as style;
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/core/theme_controller.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/core/team_navigation.dart';
import 'package:onetouch/core/main_tab_actions.dart';
import 'package:onetouch/core/keyboard_dismiss.dart';
import 'package:onetouch/core/full_screen_back_gesture.dart';
import 'package:onetouch/core/notification_navigation.dart';
import 'package:onetouch/core/community_link_navigation.dart';
import 'package:onetouch/core/session_sync_lifecycle.dart';
import 'package:onetouch/session_screen.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/auth/auth_repository_provider.dart'
    as auth_provider;
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/data/players/player_detail_repository_provider.dart';
import 'package:onetouch/features/app_error_view.dart';
import 'package:onetouch/features/betting/bet_settlement_notifications.dart';
import 'package:onetouch/features/community/notification_post_page.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/current_user_profile.dart';
import 'package:onetouch/comm_pages/profile_activity_screen.dart';

// Feature Modules
import 'package:onetouch/screens/index.dart'; // Imports all screens
import 'package:onetouch/comm_pages/index.dart'; // Imports all profile pages
import 'package:onetouch/SignComps/index.dart'; // Imports auth components

// Root Level Pages
import 'package:onetouch/splash.dart';
import 'package:onetouch/onboarding.dart';
import 'package:onetouch/SignComps/other_login_methods.dart';
import 'package:onetouch/select_favorite_teams.dart';
import 'package:onetouch/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await firebasePushMessagingService.initialize();
  await runOneTouchApp();
  // 첫 화면이 열린 뒤 동의 창을 표시해 앱 시작이 동의 응답을 기다리지 않게 해요.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    MobileAdsService.initialize();
  });
  await firebasePushNotificationHandler.start(
    onDestination: _openNotificationPayload,
    onCommunityNotification: () => notificationUnreadController.refresh(),
  );
  final pushDestination =
      firebasePushNotificationHandler.takeInitialDestination();
  if (pushDestination != null) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _openNotificationPayload(pushDestination),
    );
  }
  await pushDeviceRegistrationService.start();
}

Future<void> runOneTouchApp({
  Future<bool> Function()? restoreSession,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await appThemeController.initialize();
  await appLocaleController.initialize();
  await (restoreSession ?? auth_provider.authService.restoreSession)();
  try {
    await deviceNotificationService.initialize(
        onPayload: _openNotificationPayload);
  } on Object catch (error) {
    debugPrint('Unable to initialize device notifications: $error');
  }
  runApp(const MyApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final payload = deviceNotificationService.takeInitialPayload();
    if (payload != null) _openNotificationPayload(payload);
  });
}

void _openNotificationPayload(String payload) {
  if (!isSupportedDestination(payload) || !authSession.isAuthenticated) return;
  final currentPath = _router.routeInformationProvider.value.uri.path;
  if (!isAppSessionReady || currentPath == '/' || currentPath == '/session') {
    notificationNavigation.queue(
      payload,
      sessionToken: authSession.accessToken!,
    );
    return;
  }
  _router.go(payload);
}

Future<void> restorePlayerDetailBeforeNavigation(
  String? rawPlayerId, {
  PlayerDetailRepository? repository,
}) async {
  final playerId = int.tryParse(rawPlayerId ?? '');
  final source = repository ?? playerDetailRepository;
  if (playerId == null || source is! CachedPlayerDetailRepository) return;
  try {
    if (source.snapshotFor(playerId) == null) {
      await source.restoreFor(playerId);
    }
  } on Object {
    // An unreadable local cache must not prevent navigation.
  }
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final _footballNames = FootballNamesRepository(apiClient);

CustomTransitionPage<void> _detailSlidePage(
  GoRouterState state,
  Widget child,
) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // 새 상세 화면이 오른쪽에서 들어와 현재 화면 위를 덮어요.
        final position = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ));
        return SlideTransition(position: position, child: child);
      },
    );

final GoRouter _router = GoRouter(
  initialLocation: '/',
  navigatorKey: _rootNavigatorKey,
  redirect: (context, state) {
    final path = state.uri.path;
    if (path == '/' ||
        path == '/session' ||
        path == '/onboarding' ||
        path.startsWith('/auth/')) {
      return null;
    }
    if (!authSession.isAuthenticated) {
      if (isCommunityPostDestination(path)) {
        communityLinkNavigation.queue(path);
      }
      return '/onboarding';
    }
    if (path.startsWith('/onboarding/') && footballCatalog.isLoaded) {
      return null;
    }
    if (isAppSessionReady) return null;
    if (isCommunityPostDestination(path)) {
      communityLinkNavigation.queue(
        path,
        sessionToken: authSession.accessToken,
      );
    }
    return '/session';
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
      path: '/auth/other-methods',
      builder: (context, state) => OtherLoginMethodsScreen(
        initialOptions:
            state.extra is LoginOptions ? state.extra! as LoginOptions : null,
      ),
    ),
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
            builder: (context, state) => ValueListenableBuilder<int>(
              valueListenable: currentUserPreferences.viewedTeamId,
              builder: (context, teamId, _) => TeamScreen(teamId: teamId),
            ),
            routes: [
              GoRoute(
                path: ':id',
                redirect: (context, state) =>
                    redirectUnsupportedTeamPath(state.pathParameters['id']),
                pageBuilder: (context, state) {
                  final teamId = int.parse(state.pathParameters['id']!);
                  return MaterialPage<void>(
                    key: state.pageKey,
                    child: TeamScreen(teamId: teamId),
                  );
                },
              ),
              GoRoute(
                path: ':id/standing',
                redirect: (context, state) =>
                    redirectUnsupportedTeamPath(state.pathParameters['id']),
                pageBuilder: (context, state) {
                  final teamId = int.parse(state.pathParameters['id']!);
                  final competitionId = int.tryParse(
                    state.uri.queryParameters['competitionId'] ?? '',
                  );
                  return _detailSlidePage(
                    state,
                    TeamScreen(
                      teamId: teamId,
                      initialTabIndex: 2,
                      initialStandingCompetitionId: competitionId,
                    ),
                  );
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
                redirect: (context, state) async {
                  await restorePlayerDetailBeforeNavigation(
                      state.pathParameters['id']);
                  return null;
                },
                pageBuilder: (context, state) {
                  final playerId = state.pathParameters['id']!;
                  return MaterialPage<void>(
                    key: state.pageKey,
                    child: PlayerCard(playerId: int.tryParse(playerId)),
                  );
                },
              ),
              GoRoute(
                path: ':id/matches',
                redirect: (context, state) async {
                  await restorePlayerDetailBeforeNavigation(
                      state.pathParameters['id']);
                  return null;
                },
                pageBuilder: (context, state) => _detailSlidePage(
                  state,
                  PlayerCard(
                    playerId: int.tryParse(state.pathParameters['id']!),
                    initialTabIndex: 2,
                  ),
                ),
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
            routes: [
              GoRoute(
                path: ':postId',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final postId =
                      int.tryParse(state.pathParameters['postId'] ?? '');
                  return postId == null || postId < 1
                      ? const AppErrorScreen(statusCode: 404)
                      : NotificationPostPage(postId: postId);
                },
              ),
            ],
          ),
        ]),
      ],
    ),

    if (mockLiveMatchEnabled)
      GoRoute(
        path: '/debug/live-match',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final mock = MockLiveMatch();
          return MatchScreen(
            matchId: '$mockLiveMatchId',
            matchStatus: 'live',
            initialFixture: mock.fixtures.findById(mockLiveMatchId),
            repository: mock.fixtures,
            bettingRepository: mock.betting,
            chatRepository: mock.chat,
            chatSocket: mock.socket,
          );
        },
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
      path: '/match-team/:teamId',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) =>
          redirectUnsupportedTeamPath(state.pathParameters['teamId']),
      builder: (context, state) => _MatchOriginDetailPage(
        selectedIndex: 1,
        child: TeamScreen(
          teamId: int.parse(state.pathParameters['teamId']!),
        ),
      ),
    ),
    GoRoute(
      path: '/match-player/:playerId',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) async {
        await restorePlayerDetailBeforeNavigation(
            state.pathParameters['playerId']);
        return null;
      },
      builder: (context, state) => _MatchOriginDetailPage(
        selectedIndex: 2,
        child: PlayerCard(
          playerId: int.tryParse(state.pathParameters['playerId']!),
        ),
      ),
    ),
    GoRoute(
      path: '/notifications',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => Scaffold(
        body: const NotificationInboxPage(),
        bottomNavigationBar: OneTouchBottomNavigationBar(
          currentIndex: 0,
          onTap: (index) {
            mainTabActions.select(index);
            if (index == 1) {
              openTeamPage(
                context,
                currentUserPreferences.viewedTeamId.value,
              );
            } else {
              context.go(
                switch (index) {
                  0 => '/home',
                  2 => '/players',
                  _ => '/community',
                },
              );
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              mainTabActions.select(index);
            });
          },
        ),
      ),
    ),
    GoRoute(
      path: '/notifications/post/:postId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final postId = int.tryParse(state.pathParameters['postId'] ?? '');
        return postId == null || postId < 1
            ? const AppErrorScreen(statusCode: 404)
            : NotificationPostPage(postId: postId);
      },
    ),
    GoRoute(
      path: '/profile',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (c, s) => Profile(),
    ),
    GoRoute(
      path: '/profile/activity',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => Scaffold(
        body: ProfileActivityScreen(
          profile: state.extra is CurrentUserProfile
              ? state.extra as CurrentUserProfile
              : null,
          initialTab: state.uri.queryParameters['tab'] == 'comments'
              ? ProfileActivityTab.comments
              : ProfileActivityTab.posts,
        ),
        bottomNavigationBar: OneTouchBottomNavigationBar(
          currentIndex: 0,
          onTap: (index) {
            mainTabActions.select(index);
            if (index == 1) {
              openTeamPage(
                context,
                currentUserPreferences.viewedTeamId.value,
              );
            } else {
              context.go(
                switch (index) {
                  0 => '/home',
                  2 => '/players',
                  _ => '/community',
                },
              );
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              mainTabActions.select(index);
            });
          },
        ),
      ),
    ),
    GoRoute(
      path: '/profile/edit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (c, s) => EditProfileScreen(
        profile: s.extra is CurrentUserProfile
            ? s.extra as CurrentUserProfile
            : null,
      ),
    ),
    GoRoute(
        path: '/profile/notification',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => NotificationListPage()),
    GoRoute(
      path: '/profile/notification/team/:name',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (c, s) => TeamNotificationDetailPage(
        teamName: s.pathParameters['name']!,
        teamId: int.tryParse(s.uri.queryParameters['id'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/profile/notification/player/:name',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (c, s) => PlayerNotificationDetailPage(
        playerName: s.pathParameters['name']!,
        playerId: int.tryParse(s.uri.queryParameters['id'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/profile/preference',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (c, s) => PreferencePage(),
    ),
    GoRoute(
      path: '/profile/about',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (c, s) => AboutPage(),
    ),
    GoRoute(
      path: '/profile/contact',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (c, s) => ContactPage(),
    ),
    GoRoute(
      path: '/search',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (c, s) => Search(),
    ),
    GoRoute(
      path: '/compare',
      parentNavigatorKey: _rootNavigatorKey,
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
          // Reset persistent pages before the destination's first frame.
          mainTabActions.select(index);

          void notifyRootScreen() {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              mainTabActions.select(index);
            });
          }

          // 팀 탭은 홈에서 현재 조회 중인 팀으로 열어요.
          if (index == 1) {
            openTeamPage(context, currentUserPreferences.viewedTeamId.value);
            notifyRootScreen();
            return; // Exit after handling the special case
          }

          // This single call handles both switching tabs and resetting the stack.
          // goBranch preserves the state of other tabs.
          // The 'initialLocation' parameter resets the stack if the tapped tab
          // is already the current one.
          navigationShell.goBranch(
            index,
            initialLocation: true,
          );
          notifyRootScreen();
        },
      ),
    );
  }
}

/// Keeps the source match beneath a team or player detail page so system back
/// and iOS swipe-back return to that exact match.
class _MatchOriginDetailPage extends StatelessWidget {
  const _MatchOriginDetailPage({
    required this.selectedIndex,
    required this.child,
  });

  final int selectedIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: OneTouchBottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          mainTabActions.select(index);
          if (index == 1) {
            context.go('/team/${currentUserPreferences.viewedTeamId.value}');
          } else {
            context.go(
              switch (index) {
                0 => '/home',
                2 => '/players',
                _ => '/community',
              },
            );
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            mainTabActions.select(index);
          });
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
                style: Body2.style.copyWith(color: itemColor),
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
            return ColoredBox(
              color: style.mainPageBackground(context),
              child: SafeArea(
                left: false,
                right: false,
                bottom: false,
                child: SessionSyncLifecycle(
                  child: AnimatedBuilder(
                    animation: _router.routeInformationProvider,
                    builder: (context, _) => AppKeyboardDismissBoundary(
                      child: BetSettlementNotificationHost(
                        reserveBottomNavigation: _usesMainBottomNavigation(
                          _router.routeInformationProvider.value.uri.path,
                        ),
                        onSeeResults: (fixtureId) => _router.push(
                          '/match/$fixtureId?status=past',
                        ),
                        child: ListenableBuilder(
                          listenable: authSession,
                          builder: (context, _) => FootballNamesLoader(
                            repository: _footballNames,
                            enabled: authSession.isAuthenticated,
                            child: FullScreenBackGesture(
                              canGoBack: _router.canPop,
                              goBack: _router.routerDelegate.popRoute,
                              child: child!,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          theme: style.lightThemeForLocale(locale),
          darkTheme: style.darkThemeForLocale(locale),
          themeMode: themeMode,
          routerConfig: _router,
        ),
      ),
    );
  }
}

bool _usesMainBottomNavigation(String path) =>
    path == '/home' ||
    path == '/profile/activity' ||
    path == '/notifications' ||
    path == '/team' ||
    path.startsWith('/team/') ||
    path == '/players' ||
    path.startsWith('/players/') ||
    path == '/community';
