import 'package:flutter/material.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/SignComps/sign_in.dart';
import 'package:onetouch/SignComps/auth_widgets.dart';
import 'package:onetouch/SignComps/social_sign_in_buttons.dart';
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

  Widget _socialChoices() {
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
    final otherProviders = _options!.other
        .where((p) => p != LoginProvider.email && !providers.contains(p))
        .toSet()
        .toList();
    return Column(children: [
      SocialSignInButtons(
        providers: providers,
        authService: widget.authService,
        enabled: !_passwordBusy,
        onBusyChanged: (busy) => setState(() => _socialBusy = busy),
      ),
      if (otherProviders.isNotEmpty) ...[
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
              tr(context, 'Other login methods'),
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
    final colors = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final hasOtherProviders = !_loadFailed &&
        _options != null &&
        _options!.other.any((provider) =>
            provider != LoginProvider.email &&
            !_options!.recommended.contains(provider));
    return Scaffold(
      backgroundColor: AuthStyles.background(context),
      body: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                      child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        24, 0, 24, bottomInset > 48 ? bottomInset : 48),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Figma처럼 하단 폼을 기준으로 남은 공간의 중앙에 로고를 놓아요.
                          // 키보드가 열리면 최소 로고 영역을 유지하고 전체를 스크롤해요.
                          Expanded(
                              child: ConstrainedBox(
                            constraints: BoxConstraints(
                                minHeight: 30 +
                                    2 * MediaQuery.viewPaddingOf(context).top),
                            child: Center(
                                child: SvgPicture.asset('assets/auth/logo.svg',
                                    key: const ValueKey('onboarding-logo'),
                                    width: 207,
                                    height: 30,
                                    colorFilter: ColorFilter.mode(
                                        colors.onSurface, BlendMode.srcIn))),
                          )),
                          _socialChoices(),
                          SizedBox(height: hasOtherProviders ? 16 : 22),
                          SvgPicture.asset('assets/auth/divider.svg',
                              key: const ValueKey('onboarding-divider'),
                              height: 2,
                              fit: BoxFit.fill),
                          const SizedBox(height: 24),
                          PasswordSignInForm(
                              authService: widget.authService,
                              enabled: !_socialBusy,
                              onBusyChanged: (busy) =>
                                  setState(() => _passwordBusy = busy)),
                        ]),
                  )),
                ),
              )),
    );
  }
}
