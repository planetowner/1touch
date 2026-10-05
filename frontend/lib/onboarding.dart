import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/SignComps/sign_in.dart';
import 'package:onetouch/SignComps/auth_widgets.dart';
import 'package:onetouch/SignComps/social_sign_in_buttons.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/auth/auth_repository_provider.dart'
    as auth_provider;
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.authService, this.loadOptions});

  final AuthService? authService;
  final Future<LoginOptions> Function()? loadOptions;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  bool _socialBusy = false;
  LoginOptions? _options;
  bool _loadFailed = false;
  bool _passwordBusy = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadOptions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) => _loadOptions();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_socialBusy && !_passwordBusy) {
      _loadOptions();
    }
  }

  Future<void> _loadOptions() async {
    final request = ++_requestId;
    setState(() => _loadFailed = false);
    try {
      final options =
          await (widget.loadOptions ?? auth_provider.loadLoginOptions)();
      if (mounted && request == _requestId) setState(() => _options = options);
    } catch (_) {
      if (mounted && request == _requestId) setState(() => _loadFailed = true);
    }
  }

  Widget _socialChoices(BuildContext context) {
    if (_loadFailed) {
      return Column(children: [
        Text(tr(context, 'Unable to load login methods. Please try again.'),
            textAlign: TextAlign.center),
        TextButton(onPressed: _loadOptions, child: Text(tr(context, 'Retry'))),
      ]);
    }
    if (_options == null) {
      return const Center(child: FootballLoadingIndicator());
    }
    final providers = _options!.recommended
        .where((p) => p != LoginProvider.email)
        .toSet()
        .toList();
    final hasSocialProviders = providers.isNotEmpty ||
        _options!.other.any((provider) => provider != LoginProvider.email);
    return Column(children: [
      SocialSignInButtons(
        providers: providers.take(3).toList(),
        authService: widget.authService,
        enabled: !_passwordBusy,
        iconOnly: true,
        onBusyChanged: (busy) => setState(() => _socialBusy = busy),
      ),
      if (hasSocialProviders) ...[
        const SizedBox(height: 16),
        SizedBox(
          height: 22 * MediaQuery.textScalerOf(context).scale(1),
          child: TextButton(
            key: const ValueKey('other-login-methods'),
            onPressed: _socialBusy || _passwordBusy
                ? null
                : () => context.push('/auth/other-methods', extra: _options),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              tr(context, 'Other ways to sign in'),
              style: AuthStyles.label.copyWith(
                decoration: TextDecoration.underline,
                decorationColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        brightness: Brightness.dark,
        colorScheme: theme.colorScheme.copyWith(
          brightness: Brightness.dark,
          surface: AppPalette.black,
          onSurface: AppPalette.white,
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Builder(builder: (context) {
          final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
          return Scaffold(
            backgroundColor: AppPalette.black,
            body: LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth =
                    (constraints.maxWidth - 48).clamp(0.0, 345.0).toDouble();
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            24, 0, 24, bottomInset > 48 ? bottomInset : 48),
                        child: Column(
                          children: [
                            Expanded(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: 30 +
                                      2 * MediaQuery.viewPaddingOf(context).top,
                                ),
                                child: Center(
                                  child: SvgPicture.asset(
                                    'assets/auth/logo.svg',
                                    key: const ValueKey('onboarding-logo'),
                                    width: 207,
                                    height: 30,
                                    colorFilter: const ColorFilter.mode(
                                        AppPalette.white, BlendMode.srcIn),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: contentWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  PasswordSignInForm(
                                    authService: widget.authService,
                                    enabled: !_socialBusy,
                                    onboardingLayout: true,
                                    onBusyChanged: (busy) =>
                                        setState(() => _passwordBusy = busy),
                                  ),
                                  const SizedBox(height: 32),
                                  SvgPicture.asset('assets/auth/divider.svg',
                                      key: const ValueKey('onboarding-divider'),
                                      height: 2,
                                      fit: BoxFit.fill),
                                  const SizedBox(height: 32),
                                  _socialChoices(context),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
