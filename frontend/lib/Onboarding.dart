import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/SignComps/SignIn.dart';
import 'package:onetouch/SignComps/auth_widgets.dart';
import 'package:onetouch/data/auth/auth_repository_provider.dart'
    as auth_provider;
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/data/auth/social_identity_service.dart';
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
  LoginProvider? _signingIn;
  LoginOptions? _options;
  bool _loadFailed = false;
  bool _passwordBusy = false;
  int _requestId = 0;

  AuthService get _authService =>
      widget.authService ?? auth_provider.authService;

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
    if (state == AppLifecycleState.resumed &&
        _signingIn == null &&
        !_passwordBusy) {
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

  Future<void> _signIn(LoginProvider provider) async {
    if (_signingIn != null || _passwordBusy) return;
    setState(() => _signingIn = provider);
    try {
      await _authService.signInWithProvider(provider);
      if (mounted) context.go('/session');
    } on SocialLoginCancelled {
      // 사용자가 닫은 로그인 화면은 오류로 알리지 않아요.
    } on GoogleIdentityException catch (error) {
      if (error.type != GoogleIdentityFailureType.cancelled && mounted) {
        _showSignInError(provider);
      }
    } catch (_) {
      if (mounted) _showSignInError(provider);
    } finally {
      if (mounted) setState(() => _signingIn = null);
    }
  }

  void _showSignInError(LoginProvider provider) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(tr(
        context,
        'Unable to sign in with {provider}. Please try again.',
        {'provider': provider.displayName},
      ))));
  }

  Widget _providerButton(LoginProvider provider) {
    final busy = _signingIn != null || _passwordBusy;
    final icon = switch (provider) {
      LoginProvider.kakao =>
        SvgPicture.asset('assets/auth/kakao.svg', width: 24, height: 24),
      LoginProvider.google =>
        Image.asset('assets/auth/google.png', width: 24, height: 24),
      LoginProvider.apple =>
        SvgPicture.asset('assets/auth/apple.svg', width: 23, height: 28),
      LoginProvider.line => const SizedBox(
          width: 24,
          height: 24,
          child: Center(
              child: Text('LINE',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)))),
      LoginProvider.email => const SizedBox.shrink(),
    };
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        key: ValueKey('${provider.name}-sign-in-button'),
        onPressed: busy ? null : () => _signIn(provider),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).brightness == Brightness.light
              ? AppPalette.black
              : AppPalette.lightGrey,
          foregroundColor: AppPalette.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: _signingIn == provider
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                    key: ValueKey('${provider.name}-sign-in-progress'),
                    strokeWidth: 2,
                    color: AppPalette.white))
            : Stack(alignment: Alignment.center, children: [
                Align(alignment: Alignment.centerLeft, child: icon),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(tr(context, provider.label),
                        textAlign: TextAlign.center,
                        style:
                            AuthStyles.body.copyWith(color: AppPalette.white))),
              ]),
      ),
    );
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
      return const Center(child: CircularProgressIndicator());
    }
    final providers =
        _options!.recommended.where((p) => p != LoginProvider.email).toList();
    return Column(children: [
      for (var i = 0; i < providers.length; i++) ...[
        if (i > 0) const SizedBox(height: 16),
        _providerButton(providers[i]),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
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
                          const SizedBox(height: 22),
                          SvgPicture.asset('assets/auth/divider.svg',
                              height: 2, fit: BoxFit.fill),
                          const SizedBox(height: 24),
                          PasswordSignInForm(
                              authService: widget.authService,
                              enabled: _signingIn == null,
                              onBusyChanged: (busy) =>
                                  setState(() => _passwordBusy = busy)),
                        ]),
                  )),
                ),
              )),
    );
  }
}
