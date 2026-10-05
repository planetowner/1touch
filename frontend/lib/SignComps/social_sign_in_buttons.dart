import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/SignComps/auth_widgets.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/auth/auth_repository_provider.dart'
    as auth_provider;
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/data/auth/social_identity_service.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class SocialSignInButtons extends StatefulWidget {
  const SocialSignInButtons({
    super.key,
    required this.providers,
    this.authService,
    this.enabled = true,
    this.onBusyChanged,
    this.iconOnly = false,
  });

  final List<LoginProvider> providers;
  final AuthService? authService;
  final bool enabled;
  final ValueChanged<bool>? onBusyChanged;
  final bool iconOnly;

  @override
  State<SocialSignInButtons> createState() => _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends State<SocialSignInButtons> {
  LoginProvider? _signingIn;

  Future<void> _signIn(LoginProvider provider) async {
    if (_signingIn != null || !widget.enabled) return;
    setState(() => _signingIn = provider);
    widget.onBusyChanged?.call(true);
    try {
      await (widget.authService ?? auth_provider.authService)
          .signInWithProvider(provider);
      if (mounted) context.go('/session');
    } on SocialLoginCancelled {
      // Closing a provider's sign-in screen is not a sign-in error.
    } on GoogleIdentityException catch (error) {
      if (error.type != GoogleIdentityFailureType.cancelled && mounted) {
        _showSignInError(provider);
      }
    } catch (_) {
      if (mounted) _showSignInError(provider);
    } finally {
      if (mounted) {
        setState(() => _signingIn = null);
        widget.onBusyChanged?.call(false);
      }
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final icon = switch (provider) {
      LoginProvider.kakao =>
        SvgPicture.asset('assets/auth/kakao.svg', width: 24, height: 24),
      LoginProvider.google =>
        Image.asset('assets/auth/google.png', width: 24, height: 24),
      LoginProvider.apple => SvgPicture.asset('assets/auth/apple.svg',
          width: 23,
          height: 28,
          colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn)),
      LoginProvider.line =>
        SvgPicture.asset('assets/auth/line.svg', width: 24, height: 24),
      LoginProvider.email => const SizedBox.shrink(),
    };
    return SizedBox(
      width: widget.iconOnly ? 56 : double.infinity,
      height: 56,
      child: ElevatedButton(
        key: ValueKey('${provider.name}-sign-in-button'),
        onPressed: _signingIn != null || !widget.enabled
            ? null
            : () => _signIn(provider),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isLight ? AppPalette.lightModeDarkGrey : AppPalette.lightGrey,
          foregroundColor: foreground,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          padding: widget.iconOnly
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: _signingIn == provider
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                    key: ValueKey('${provider.name}-sign-in-progress'),
                    strokeWidth: 2,
                    color: foreground))
            : widget.iconOnly
                ? Tooltip(message: tr(context, provider.label), child: icon)
                : Stack(alignment: Alignment.center, children: [
                    Align(alignment: Alignment.centerLeft, child: icon),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(tr(context, provider.label),
                            textAlign: TextAlign.center,
                            style:
                                AuthStyles.body.copyWith(color: foreground))),
                  ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.iconOnly
      ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.providers.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              _providerButton(widget.providers[i]),
            ],
          ],
        )
      : Column(
          children: [
            for (var i = 0; i < widget.providers.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              _providerButton(widget.providers[i]),
            ],
          ],
        );
}
