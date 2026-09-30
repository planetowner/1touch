import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/identity_name_rules.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/auth/auth_repository_provider.dart'
    as auth_provider;
import 'package:onetouch/data/auth/auth_request_exception.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/registration_field.dart';
import 'package:onetouch/SignComps/VerifyEmail.dart';
import 'package:onetouch/SignComps/signup_availability_field.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/user_name_labels.dart';

String? _emailValidationMessage(String value) {
  final email = value.trim();
  if (email.isEmpty) return 'Enter email';
  return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)
      ? null
      : 'Enter a valid email';
}

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
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _availableFields = <RegistrationField>{};
  final _confirmPassword = TextEditingController();

  bool _obscure = true;
  bool _obscureConfirm = true;
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

  bool get _validInputs =>
      _agreed &&
      _firstName.text.trim().isNotEmpty &&
      _lastName.text.trim().isNotEmpty &&
      usernameValidationMessage(_username.text) == null &&
      displayNameValidationMessage(_displayName.text) == null &&
      _emailValidationMessage(_email.text) == null &&
      isValidNewPassword(_password.text) &&
      _confirmPassword.text == _password.text;

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) {
      _showCodeRequestError(
          tr(context, 'Please check the highlighted fields.'));
      return;
    }
    if (!_agreed) {
      _showCodeRequestError(
          tr(context, 'Please agree to the Terms and Privacy Policy.'));
      return;
    }
    if (_availableFields.length != RegistrationField.values.length) return;

    setState(() => _submitting = true);

    try {
      final email = _email.text.trim();
      final challenge = await _authService.requestEmailCode(email: email);
      if (!mounted) return;
      final registrationResult = await context.push<String>(
        '/auth/verify',
        extra: EmailRegistrationDraft(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          username: _username.text,
          displayName: _displayName.text,
          email: email,
          password: _password.text,
          challengeId: challenge.challengeId,
          expiresInSeconds: challenge.expiresInSeconds,
        ),
      );
      if (!mounted) return;
      if (registrationResult == 'duplicate') {
        _showCodeRequestError(
            tr(context, 'Email, username, or nickname is already registered'));
      }
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

  void _setAvailable(RegistrationField field, bool available) {
    if (_availableFields.contains(field) == available) return;
    setState(() {
      if (available) {
        _availableFields.add(field);
      } else {
        _availableFields.remove(field);
      }
    });
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
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
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
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                onChanged: () => setState(() {}),
                child: SingleChildScrollView(
                  key: const ValueKey('signup-fields-scroll'),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final (index, field) in orderedUserNameParts(
                            locale: Localizations.localeOf(context),
                            firstName: (_firstName, 'First name', 'John'),
                            lastName: (_lastName, 'Last name', 'Doe'),
                          ).indexed) ...[
                            if (index > 0) const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tr(context, field.$2),
                                      style: Eyebrow.style),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    key: ValueKey(
                                        'signup-${field.$2.toLowerCase().replaceAll(' ', '-')}-field'),
                                    controller: field.$1,
                                    decoration: _dec(context, field.$3),
                                    validator: (v) => (v == null ||
                                            v.trim().isEmpty)
                                        ? tr(context,
                                            'Enter ${field.$2.toLowerCase()}')
                                        : null,
                                    style: Body1.style,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      for (final field in [
                        (
                          field: RegistrationField.username,
                          label: 'Username',
                          hint: 'john_doe',
                          controller: _username,
                          maxLength: 30,
                          keyboardType: null,
                          validator: usernameValidationMessage,
                        ),
                        (
                          field: RegistrationField.displayName,
                          label: 'Nickname',
                          hint: '불광동호날두',
                          controller: _displayName,
                          maxLength: 12,
                          keyboardType: null,
                          validator: displayNameValidationMessage,
                        ),
                        (
                          field: RegistrationField.email,
                          label: 'Email',
                          hint: 'johndoe@gmail.com',
                          controller: _email,
                          maxLength: null,
                          keyboardType: TextInputType.emailAddress,
                          validator: _emailValidationMessage,
                        ),
                      ]) ...[
                        Text(tr(context, field.label), style: Eyebrow.style),
                        const SizedBox(height: 8),
                        SignupAvailabilityField(
                          key: ValueKey(
                              'signup-${field.field.apiValue.replaceAll('_', '-')}-field'),
                          controller: field.controller,
                          maxLength: field.maxLength,
                          keyboardType: field.keyboardType,
                          enabled: !_submitting,
                          decoration: _dec(context, field.hint)
                              .copyWith(counterText: ''),
                          validator: field.validator,
                          checkAvailability: (value) =>
                              _authService.isRegistrationValueAvailable(
                                  field: field.field, value: value),
                          onAvailabilityChanged: (available) =>
                              _setAvailable(field.field, available),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(tr(context, 'Password'), style: Eyebrow.style),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const ValueKey('signup-password-field'),
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
                      const SizedBox(height: 8),
                      Text(
                        tr(context,
                            'Choose a password that is 8 or more characters long.'),
                        style: Body1.style,
                      ),
                      const SizedBox(height: 24),
                      Text(tr(context, 'Retype Password'),
                          style: Eyebrow.style),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const ValueKey('signup-confirm-password-field'),
                        controller: _confirmPassword,
                        obscureText: _obscureConfirm,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: _dec(context, '• • • • • • • •').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: colors.onSurface),
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        validator: (value) => value == _password.text
                            ? null
                            : tr(context, 'Passwords do not match.'),
                        style: Body1.style,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                          child: Text(
                            tr(
                                    context,
                                    "By clicking sign up, I hereby agree and consent to\n"
                                    "1Touch’s Terms & Conditions; I confirm that I have\n"
                                    "read 1Touch’s Privacy Policy.")
                                .replaceAll('\n', ' '),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Body2.style,
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
                      onPressed: _submitting ||
                              (_validInputs &&
                                  _availableFields.length !=
                                      RegistrationField.values.length)
                          ? null
                          : _submit,
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
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(tr(context, 'SIGN UP'),
                              style: Body2_b.style
                                  .copyWith(color: colors.surface)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
