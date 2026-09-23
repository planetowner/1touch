import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/SignComps/forgot_password.dart';
import 'package:onetouch/SignComps/auth_widgets.dart';
import 'package:onetouch/data/auth/auth_repository_provider.dart'
    as auth_provider;
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/l10n/app_localizations.dart';

/// 기존 이메일 로그인 경로도 온보딩과 같은 입력·인증 동작을 사용해요.
class EmailSignInScreen extends StatelessWidget {
  const EmailSignInScreen({super.key, this.authService});
  final AuthService? authService;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AuthStyles.background(context),
        appBar: AppBar(title: Text(tr(context, 'Sign in'))),
        body: SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: PasswordSignInForm(authService: authService),
        )),
      );
}

class PasswordSignInForm extends StatefulWidget {
  const PasswordSignInForm(
      {super.key, this.authService, this.enabled = true, this.onBusyChanged});
  final AuthService? authService;
  final bool enabled;
  final ValueChanged<bool>? onBusyChanged;

  @override
  State<PasswordSignInForm> createState() => _PasswordSignInFormState();
}

class _PasswordSignInFormState extends State<PasswordSignInForm> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  AuthService get _service => widget.authService ?? auth_provider.authService;
  bool get _enabled => widget.enabled && !_submitting;

  Future<void> _submit() async {
    if (!_enabled) return;
    if (_identifier.text.trim().isEmpty || _password.text.isEmpty) {
      _message('Enter your email or username and password.');
      return;
    }
    setState(() => _submitting = true);
    widget.onBusyChanged?.call(true);
    try {
      // API의 username 필드는 기존 클라이언트 호환용이며 이메일도 받아요.
      await _service.signInWithPassword(
          username: _identifier.text.trim(), password: _password.text);
      if (mounted) context.go('/session');
    } catch (_) {
      if (mounted) {
        _message(
            'Unable to sign in. Check your email or username and password.');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tr(context, message))));
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AuthInput(
          label: tr(context, 'Email or username'),
          controller: _identifier,
          fieldKey: const ValueKey('sign-in-username'),
          enabled: _enabled,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username, AutofillHints.email]),
      const SizedBox(height: 16),
      AuthInput(
          label: tr(context, 'Password'),
          controller: _password,
          fieldKey: const ValueKey('sign-in-password'),
          enabled: _enabled,
          obscureText: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submit()),
      const SizedBox(height: 8),
      SizedBox(
          height: 22 * scale,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
                button: true,
                child: InkWell(
                  key: const ValueKey('forgot-password-link'),
                  onTap: _enabled
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  ForgotPasswordScreen(authService: _service)))
                      : null,
                  child: Text(tr(context, 'Forgot password?'),
                      style: AuthStyles.label.copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: colors.onSurface)),
                )),
          )),
      const SizedBox(height: 24),
      AuthPrimaryButton(
          key: const ValueKey('email-sign-in-button'),
          label: tr(context, 'Sign in'),
          onPressed: _enabled ? _submit : null,
          loading: _submitting,
          progressKey: const ValueKey('email-sign-in-progress')),
      const SizedBox(height: 8),
      // 두 문구가 길어지는 언어에서도 가입 링크를 가리지 않아요.
      Center(
          child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Localizations.localeOf(context).languageCode == 'zh' ? 0 : 4,
        children: [
          SizedBox(
              height: 22 * scale,
              child: Text(tr(context, "Don't have an account?"),
                  style: AuthStyles.label.copyWith(
                      color: colors.onSurface.withValues(alpha: .6)))),
          Semantics(
              button: true,
              child: InkWell(
                key: const ValueKey('sign-in-sign-up-link'),
                onTap: _enabled ? () => context.push('/auth/signup') : null,
                child: SizedBox(
                    height: 22 * scale,
                    child: Text(tr(context, 'Sign up'),
                        style: AuthStyles.emphasis)),
              )),
        ],
      )),
    ]));
  }
}
