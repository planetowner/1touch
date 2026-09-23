import 'package:flutter/material.dart';
import 'package:onetouch/SignComps/VerifyEmail.dart';
import 'package:onetouch/SignComps/auth_widgets.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/auth_request_exception.dart';
import 'package:onetouch/data/auth/email_code_challenge.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _submitting = false;

  Future<void> _submit() async {
    if (_submitting) return;
    if (_email.text.trim().isEmpty) {
      _showMessage('Enter email');
      return;
    }
    setState(() => _submitting = true);
    try {
      final email = _email.text.trim();
      final challenge = await widget.authService.requestEmailCode(
          email: email, purpose: EmailCodePurpose.passwordReset);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => EmailVerifyScreen(
              email: email,
              passwordResetChallenge: challenge,
              authService: widget.authService)));
    } on AuthRequestException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage(
            'Unable to send a verification code. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tr(context, message))));
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AuthStyles.background(context),
        appBar: AppBar(
            title: Text(tr(context, 'Reset password'), style: AuthStyles.body)),
        body: SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(context, 'Enter the email address you used to sign up.'),
                style: AuthStyles.body),
            const SizedBox(height: 24),
            AuthInput(
                label: tr(context, 'Email'),
                controller: _email,
                fieldKey: const ValueKey('reset-email'),
                enabled: !_submitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                onSubmitted: (_) => _submit()),
            const SizedBox(height: 24),
            AuthPrimaryButton(
                key: const ValueKey('request-reset-code'),
                label: tr(context, 'Send verification code'),
                loading: _submitting,
                onPressed: _submitting ? null : _submit),
          ]),
        )),
      );
}
