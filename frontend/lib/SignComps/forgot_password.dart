import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/core/app_close_header.dart';
import 'package:onetouch/core/app_snack_bar.dart';
import 'package:flutter/services.dart';
import 'package:onetouch/SignComps/auth_widgets.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/auth/auth_request_exception.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/email_code_challenge.dart';
import 'package:onetouch/l10n/app_localizations.dart';

typedef _ResetTicket = ({
  EmailCodeChallenge challenge,
  String code,
  String email,
  DateTime expiresAt,
  DateTime resendAt,
});

Future<void> showForgotPasswordFlow(
    BuildContext context, AuthService authService) async {
  _ResetTicket? previousTicket;
  AuthRequestException? verificationError;
  while (true) {
    if (!context.mounted) return;
    final ticket = await showModalBottomSheet<_ResetTicket>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.of(context).cardBackground,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ResetCodeSheet(
          authService: authService,
          previousTicket: previousTicket,
          verificationError: verificationError),
    );
    if (ticket == null) return;
    if (!context.mounted) return;
    final retryError = await Navigator.of(context).push<AuthRequestException>(
        MaterialPageRoute<AuthRequestException>(
            builder: (_) =>
                _NewPasswordScreen(authService: authService, ticket: ticket)));
    if (retryError == null) return;
    previousTicket = ticket;
    verificationError = retryError;
  }
}

class _ResetCodeSheet extends StatefulWidget {
  const _ResetCodeSheet({
    required this.authService,
    this.previousTicket,
    this.verificationError,
  });
  final AuthService authService;
  final _ResetTicket? previousTicket;
  final AuthRequestException? verificationError;
  @override
  State<_ResetCodeSheet> createState() => _ResetCodeSheetState();
}

class _ResetCodeSheetState extends State<_ResetCodeSheet> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  EmailCodeChallenge? _challenge;
  Timer? _timer;
  int _expiresIn = 0;
  int _resendIn = 0;
  bool _busy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final ticket = widget.previousTicket;
    if (ticket == null) return;
    final error = widget.verificationError;
    if (error != null) {
      _errorMessage = authRequestErrorMessage(error,
          fallback: 'Unable to verify the code. Please try again.');
    }
    _email.text = ticket.email;
    _challenge = ticket.challenge;
    _expiresIn =
        ticket.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 999999);
    _resendIn =
        ticket.resendAt.difference(DateTime.now()).inSeconds.clamp(0, 999999);
    _startTimer();
  }

  void _message(String value) {
    showAppSnackBar(context, tr(context, value), replaceCurrent: true);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_expiresIn == 0 && _resendIn == 0) return timer.cancel();
      setState(() {
        if (_expiresIn > 0) _expiresIn--;
        if (_resendIn > 0) _resendIn--;
      });
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (_busy || (resend && _resendIn > 0)) return;
    final email = _email.text.trim();
    if (email.isEmpty) return _message('Enter your email address.');
    setState(() => _busy = true);
    try {
      final challenge = await widget.authService.requestEmailCode(
          email: email, purpose: EmailCodePurpose.passwordReset);
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _expiresIn = challenge.expiresInSeconds;
        _resendIn = 60;
        _code.clear();
        _errorMessage = null;
      });
      _startTimer();
      if (resend) _message('A new verification code was sent.');
    } on Object catch (error) {
      if (mounted) {
        // 배경 화면의 배너는 입력창에 가려져요. 발송 오류도 입력창 안에서 안내해요.
        setState(() => _errorMessage = authRequestErrorMessage(error,
            fallback:
                'Unable to send a verification code. Check your connection and try again.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _continue() {
    if (_busy || _challenge == null) return;
    if (_expiresIn == 0) {
      return _message('This code has expired. Send a new code.');
    }
    if (_code.text.length != 6) return _message('Enter the 6-digit code.');
    Navigator.of(context).pop((
      challenge: _challenge!,
      code: _code.text,
      email: _email.text.trim(),
      expiresAt: DateTime.now().add(Duration(seconds: _expiresIn)),
      resendAt: DateTime.now().add(Duration(seconds: _resendIn)),
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final hasCode = _challenge != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCloseHeader(
              title: trTitle(context, 'Reset password'),
              titleStyle: Body2_b.style,
              closeKey: const ValueKey('close-reset-sheet'),
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 24),
            if (!hasCode) ...[
              Text(tr(context, 'Email'), style: Body2.style),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('reset-email'),
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                onSubmitted: (_) => _sendCode(),
                decoration: _inputDecoration(context, null),
              ),
              const SizedBox(height: 12),
              Text(
                tr(context,
                    'Enter the email linked to your account. We will send you a verification code to reset your password.'),
                style: Body2.style.copyWith(color: appColors.mutedForeground),
              ),
            ] else ...[
              Text(
                  tr(context,
                      'Enter the verification code sent to your email.'),
                  style: Body2.style),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('email-verification-code'),
                controller: _code,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6)
                ],
                onSubmitted: (_) => _continue(),
                decoration: _inputDecoration(context, null),
              ),
              const SizedBox(height: 12),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(tr(context, "Didn't get code? "), style: Body2.style),
                InkWell(
                  key: const ValueKey('resend-email-code'),
                  onTap: _resendIn == 0 && !_busy
                      ? () => _sendCode(resend: true)
                      : null,
                  child: Text(
                    _resendIn > 0
                        ? tr(context, 'Send again ({seconds}s)',
                            {'seconds': _resendIn})
                        : tr(context, 'Send again'),
                    style: Body2.style.copyWith(
                        color: _resendIn == 0
                            ? colors.onSurface
                            : appColors.mutedForeground,
                        decoration: TextDecoration.underline),
                  ),
                ),
              ]),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(tr(context, _errorMessage!),
                  style: Body2.style.copyWith(color: colors.error)),
            ],
            const SizedBox(height: 32),
            AuthPrimaryButton(
              key: ValueKey(
                  hasCode ? 'continue-reset-password' : 'request-reset-code'),
              label: tr(context,
                  hasCode ? 'Reset password' : 'Send verification code'),
              loading: _busy,
              onPressed: _busy
                  ? null
                  : hasCode
                      ? _continue
                      : _sendCode,
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(BuildContext context, String? hint) {
  const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide.none);
  return InputDecoration(
    hintText: hint,
    hintStyle:
        Body2.style.copyWith(color: AppColors.of(context).mutedForeground),
    isDense: true,
    filled: true,
    fillColor: AppColors.of(context).subtleBackground,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: border,
    enabledBorder: border,
    focusedBorder: border,
  );
}

class _NewPasswordScreen extends StatefulWidget {
  const _NewPasswordScreen({required this.authService, required this.ticket});
  final AuthService authService;
  final _ResetTicket ticket;
  @override
  State<_NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<_NewPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _busy = false;

  Future<void> _submit() async {
    if (_busy) return;
    final error = newPasswordValidationMessage(_password.text) ??
        passwordConfirmationValidationMessage(_confirm.text, _password.text);
    if (error != null) return _message(error);
    setState(() => _busy = true);
    try {
      await widget.authService.resetPassword(
          challengeId: widget.ticket.challenge.challengeId,
          code: widget.ticket.code,
          password: _password.text);
      if (!mounted) return;
      _message('Password reset. Sign in with your new password.');
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      // 문구가 바뀌어도 인증번호 오류는 같은 입력 화면에서 다시 해결해요.
      if (error is AuthRequestException && error.isVerificationCodeError) {
        Navigator.of(context).pop(error);
        return;
      }
      _message(authRequestErrorMessage(error,
          fallback: 'Unable to reset your password. Please try again.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) {
    showAppSnackBar(context, tr(context, value), replaceCurrent: true);
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Widget _passwordField({
    required Key key,
    required TextEditingController controller,
    required bool hidden,
    required VoidCallback toggle,
  }) =>
      TextField(
        key: key,
        controller: controller,
        enabled: !_busy,
        obscureText: hidden,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.newPassword],
        decoration: _inputDecoration(context, '••••••••').copyWith(
          suffixIcon: IconButton(
            onPressed: toggle,
            icon: Icon(hidden
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AuthStyles.background(context),
        appBar: AppBar(
            centerTitle: true,
            title: Text(tr(context, 'Reset password'), style: Body1.style)),
        body: SafeArea(
            child: CustomScrollView(slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(context, 'Enter a new password.'),
                        style: Body1.style),
                    const SizedBox(height: 12),
                    _passwordField(
                        key: const ValueKey('reset-new-password'),
                        controller: _password,
                        hidden: _hidePassword,
                        toggle: () =>
                            setState(() => _hidePassword = !_hidePassword)),
                    const SizedBox(height: 8),
                    Text(
                      tr(context, passwordGuideMessage),
                      style: Eyebrow.style,
                    ),
                    const SizedBox(height: 24),
                    Text(tr(context, 'Enter your new password again.'),
                        style: Body1.style),
                    const SizedBox(height: 12),
                    _passwordField(
                        key: const ValueKey('reset-confirm-password'),
                        controller: _confirm,
                        hidden: _hideConfirm,
                        toggle: () =>
                            setState(() => _hideConfirm = !_hideConfirm)),
                    const Spacer(),
                    AuthPrimaryButton(
                        key: const ValueKey('verify-email-button'),
                        label: tr(context, 'Reset password'),
                        loading: _busy,
                        onPressed: _busy ? null : _submit),
                  ]),
            ),
          ),
        ])),
      );
}
