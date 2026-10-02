import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/SignComps/auth_widgets.dart';
import 'package:onetouch/SignComps/social_sign_in_buttons.dart';
import 'package:onetouch/data/auth/auth_repository_provider.dart'
    as auth_provider;
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class OtherLoginMethodsScreen extends StatefulWidget {
  const OtherLoginMethodsScreen({
    super.key,
    this.initialOptions,
    this.authService,
    this.loadOptions,
  });

  final LoginOptions? initialOptions;
  final AuthService? authService;
  final Future<LoginOptions> Function()? loadOptions;

  @override
  State<OtherLoginMethodsScreen> createState() =>
      _OtherLoginMethodsScreenState();
}

class _OtherLoginMethodsScreenState extends State<OtherLoginMethodsScreen> {
  LoginOptions? _options;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _options = widget.initialOptions;
    if (_options == null) _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() => _loadFailed = false);
    try {
      final options =
          await (widget.loadOptions ?? auth_provider.loadLoginOptions)();
      if (mounted) setState(() => _options = options);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final providers = [
      ...?_options?.recommended,
      ...?_options?.other,
    ].where((provider) => provider != LoginProvider.email).toSet().toList();
    return Scaffold(
      backgroundColor: AuthStyles.background(context),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              children: [
                SizedBox(
                  key: const ValueKey('other-login-header'),
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                          child: Text(tr(context, 'Sign in'),
                              style: AuthStyles.body)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          key: const ValueKey('other-login-back'),
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/onboarding'),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_loadFailed) ...[
                  Text(
                    tr(context,
                        'Unable to load login methods. Please try again.'),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _loadOptions,
                    child: Text(tr(context, 'Retry')),
                  ),
                ] else if (_options == null)
                  const FootballLoadingIndicator()
                else
                  SocialSignInButtons(
                    providers: providers,
                    authService: widget.authService,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
