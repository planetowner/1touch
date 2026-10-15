import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/core/app_snack_bar.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/auth/auth_repository_provider.dart'
    as auth_provider;
import 'package:onetouch/data/auth/auth_request_exception.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class EmailRegistrationDraft {
  const EmailRegistrationDraft({
    required this.username,
    required this.displayName,
    required this.email,
    required this.password,
    required this.challengeId,
    required this.expiresInSeconds,
  });

  final String username;
  final String displayName;
  final String email;
  final String password;
  final String challengeId;
  final int expiresInSeconds;

  EmailRegistrationDraft withChallenge({
    required String challengeId,
    required int expiresInSeconds,
  }) =>
      EmailRegistrationDraft(
        username: username,
        displayName: displayName,
        email: email,
        password: password,
        challengeId: challengeId,
        expiresInSeconds: expiresInSeconds,
      );
}

class EmailVerifyScreen extends StatefulWidget {
  final String email;
  final EmailRegistrationDraft? registrationDraft;
  final AuthService? authService;

  const EmailVerifyScreen({
    super.key,
    required this.email,
    this.registrationDraft,
    this.authService,
  });

  @override
  State<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends State<EmailVerifyScreen> {
  static const _resendCooldownSeconds = 60;

  final _code = TextEditingController();
  String? get _challengeId => _draft?.challengeId;

  bool _submitting = false;
  bool _resending = false;
  late EmailRegistrationDraft? _draft;
  late int _expiresInSeconds;
  int _resendInSeconds = _resendCooldownSeconds;
  Timer? _countdown;

  AuthService get _authService =>
      widget.authService ?? auth_provider.authService;

  bool get _canSubmit =>
      !_submitting &&
      !_resending &&
      _challengeId != null &&
      _expiresInSeconds > 0 &&
      _code.text.length == 6;

  bool get _canResend => !_submitting && !_resending && _resendInSeconds == 0;

  @override
  void initState() {
    super.initState();
    _draft = widget.registrationDraft;
    _expiresInSeconds = _draft?.expiresInSeconds ?? 0;
    _startCountdown();
  }

  void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_expiresInSeconds == 0 && _resendInSeconds == 0) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_expiresInSeconds > 0) _expiresInSeconds--;
        if (_resendInSeconds > 0) _resendInSeconds--;
      });
    });
  }

  String get _expiryLabel {
    if (_expiresInSeconds == 0) return tr(context, 'Code expired');
    final minutes = _expiresInSeconds ~/ 60;
    final seconds = _expiresInSeconds % 60;
    return tr(context, 'Code expires in {time}', {
      'time':
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
    });
  }

  InputDecoration _dec(BuildContext context, String hint) {
    final appColors = AppColors.of(context);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: appColors.mutedForeground),
      filled: true,
      fillColor: appColors.subtleBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }

  Future<void> _continue() async {
    if (!_canSubmit) {
      if (_challengeId == null) {
        _showMessage(
            tr(context, 'Restart signup to request a new verification code.'));
      } else if (_expiresInSeconds == 0) {
        _showMessage(tr(context, 'This code has expired. Send a new code.'));
      } else {
        _showMessage(tr(context, 'Enter the 6-digit code.'));
      }
      return;
    }
    setState(() => _submitting = true);

    try {
      final draft = _draft!;
      await _authService.registerWithEmail(
        challengeId: draft.challengeId,
        code: _code.text,
        password: draft.password,
        username: draft.username,
        displayName: draft.displayName,
      );
      if (mounted) context.go('/session');
    } on Object catch (error) {
      if (!mounted) return;
      if (error is AuthRequestException &&
          error.statusCode == 409 &&
          error.code == 'registration_conflict' &&
          context.canPop()) {
        context.pop('duplicate');
        return;
      }
      _showMessage(
        tr(
            context,
            authRequestErrorMessage(error,
                fallback: 'Unable to verify the code. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    final draft = _draft;
    if (!_canResend || _challengeId == null) return;
    setState(() => _resending = true);

    try {
      final challenge =
          await _authService.requestEmailCode(email: widget.email);
      if (!mounted) return;
      setState(() {
        _draft = draft!.withChallenge(
            challengeId: challenge.challengeId,
            expiresInSeconds: challenge.expiresInSeconds);
        _expiresInSeconds = challenge.expiresInSeconds;
        _resendInSeconds = _resendCooldownSeconds;
        _code.clear();
      });
      _startCountdown();
      _showMessage(tr(context, 'A new verification code was sent.'));
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage(
        tr(
            context,
            authRequestErrorMessage(error,
                fallback:
                    'Unable to send a verification code. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _showMessage(String message) {
    showAppSnackBar(context, tr(context, message), replaceCurrent: true);
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/auth/signup');
    }
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          color: colors.onSurface,
          onPressed: _goBack,
        ),
        centerTitle: true,
        title: Text(tr(context, 'Verify your email'), style: Body1.style),
      ),
      body: SafeArea(
        // 1. Switch ListView to CustomScrollView
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false, // Allows content to fill the screen height
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  // 2. Use Column instead of ListView
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text.rich(
                      TextSpan(
                        text: tr(context,
                            'Enter the verification code that we sent to '),
                        children: [
                          TextSpan(
                            text: widget.email,
                            style: Body1_b.style,
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                      style: Body1.style,
                    ),
                    const SizedBox(height: 24),
                    Text(tr(context, 'Verification code'),
                        style: Eyebrow.style),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey('email-verification-code'),
                      controller: _code,
                      keyboardType: TextInputType.number,
                      enabled: !_submitting && !_resending,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: _dec(context, '204182'),
                      style: Body1.style,
                    ),
                    const SizedBox(height: 8),
                    Text(_expiryLabel, style: Body2.style),
                    const SizedBox(height: 20),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 8,
                      children: [
                        Text(tr(context, "Didn't get code? "),
                            style: Body1.style),
                        GestureDetector(
                          key: const ValueKey('resend-email-code'),
                          onTap: _canResend ? _resend : null,
                          child: Text(
                            _resending
                                ? tr(context, 'Sending...')
                                : _resendInSeconds > 0
                                    ? tr(context, 'Send again ({seconds}s)',
                                        {'seconds': _resendInSeconds})
                                    : tr(context, 'Send again'),
                            style: Body1.style.copyWith(
                              decoration: TextDecoration.underline,
                              color: _canResend
                                  ? colors.onSurface
                                  : colors.onSurface.withValues(alpha: 0.5),
                              decorationColor: _canResend
                                  ? colors.onSurface
                                  : colors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 56,
                      width: double.infinity, // Ensures button takes full width
                      child: FilledButton(
                        key: const ValueKey('verify-email-button'),
                        onPressed: _canSubmit ? _continue : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.onSurface,
                          foregroundColor: colors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Text(trUpper(context, 'Continue'),
                                style: Body1_b.style
                                    .copyWith(color: colors.surface)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
