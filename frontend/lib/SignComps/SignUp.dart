import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/auth/auth_repository_provider.dart'
    as auth_provider;
import 'package:onetouch/data/auth/auth_request_exception.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/SignComps/VerifyEmail.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class EmailSignUpScreen extends StatefulWidget {
  const EmailSignUpScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends State<EmailSignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _agreed = false;
  bool _submitting = false;

  AuthService get _authService =>
      widget.authService ?? auth_provider.authService;

  InputDecoration _dec(BuildContext context, String hint) {
    final appColors = AppColors.of(context);
    return InputDecoration(
      hintText: hint,
      hintStyle: Body1.style.copyWith(color: appColors.mutedForeground),
      filled: true,
      fillColor: appColors.subtleBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }

  bool get _canSubmit =>
      _agreed &&
      !_submitting &&
      _firstName.text.trim().isNotEmpty &&
      _lastName.text.trim().isNotEmpty &&
      _username.text.trim().isNotEmpty &&
      _email.text.trim().isNotEmpty &&
      isValidNewPassword(_password.text);

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    if (!_agreed) return;

    setState(() => _submitting = true);

    try {
      final email = _email.text.trim();
      final challenge = await _authService.requestEmailCode(email: email);
      if (!mounted) return;
      context.push(
        '/auth/verify',
        extra: EmailRegistrationDraft(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          username: _username.text.trim(),
          email: email,
          password: _password.text,
          challengeId: challenge.challengeId,
          expiresInSeconds: challenge.expiresInSeconds,
        ),
      );
    } on AuthRequestException catch (error) {
      if (!mounted) return;
      _showCodeRequestError(
          '${tr(context, error.message)} (${error.statusCode})');
    } on Object {
      if (!mounted) return;
      _showCodeRequestError(
        tr(
            context,
            'Unable to send a verification code. Check your connection and try '
            'again.'),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showCodeRequestError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tr(context, message))));
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
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
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/onboarding');
            }
          },
        ),
        centerTitle: true,
        title: Text(tr(context, 'Sign up'), style: Body1.style),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              // --- 1. I added the Form widget back here ---
              child: Form(
                key: _formKey,
                onChanged: () => setState(
                    () {}), // This ensures the button enables/disables correctly
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text(tr(context, 'First name'), style: Eyebrow.style),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _firstName,
                        decoration: _dec(context, 'John'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? tr(context, 'Enter first name')
                            : null,
                        style: Body1.style,
                      ),
                      const SizedBox(height: 16),

                      Text(tr(context, 'Last name'), style: Eyebrow.style),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _lastName,
                        decoration: _dec(context, 'Doe'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? tr(context, 'Enter last name')
                            : null,
                        style: Body1.style,
                      ),
                      const SizedBox(height: 16),

                      Text(tr(context, 'Username'), style: Eyebrow.style),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _username,
                        decoration: _dec(context, 'john_doe'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? tr(context, 'Enter username')
                            : null,
                        style: Body1.style,
                      ),
                      const SizedBox(height: 16),

                      Text(tr(context, 'Email'), style: Eyebrow.style),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _dec(context, 'johndoe@gmail.com'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return tr(context, 'Enter email');
                          final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                              .hasMatch(v.trim());
                          return ok ? null : tr(context, 'Enter a valid email');
                        },
                        style: Body1.style,
                      ),
                      const SizedBox(height: 16),

                      Text(tr(context, 'Password'), style: Eyebrow.style),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        decoration: _dec(context, '• • • • • • • •').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                                _obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: colors.onSurface),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => isValidNewPassword(v ?? '')
                            ? null
                            : tr(context,
                                'Use 8–128 characters with uppercase and lowercase English letters and a number.'),
                        style: Body1.style,
                      ),

                      // --- 2. The Spacer now works correctly inside SliverFillRemaining ---
                      const Spacer(),

                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.zero,
                        alignment: Alignment.topLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _agreed,
                                onChanged: (v) =>
                                    setState(() => _agreed = v ?? false),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topLeft,
                                child: Text(
                                  tr(
                                      context,
                                      "By clicking sign up, I hereby agree and consent to\n"
                                      "1Touch’s Terms & Conditions; I confirm that I have\n"
                                      "read 1Touch’s Privacy Policy."),
                                  maxLines: 3,
                                  softWrap: false,
                                  style: Body2.style,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: FilledButton(
                          key: const ValueKey('email-sign-up-button'),
                          onPressed: _canSubmit ? _submit : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.onSurface,
                            foregroundColor: colors.surface,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Text(tr(context, 'SIGN UP'),
                                  style: Body2_b.style
                                      .copyWith(color: colors.surface)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
