import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/comm_pages/Profile_settings/about_detail_page.dart';
import 'package:onetouch/core/identity_name_rules.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/auth/auth_repository_provider.dart'
    as auth_provider;
import 'package:onetouch/data/auth/auth_request_exception.dart';
import 'package:onetouch/data/auth/auth_service.dart';
import 'package:onetouch/data/auth/registration_field.dart';
import 'package:onetouch/SignComps/auth_widgets.dart';
import 'package:onetouch/SignComps/verify_email.dart';
import 'package:onetouch/SignComps/signup_availability_field.dart';
import 'package:onetouch/l10n/app_localizations.dart';

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
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () {
        FocusManager.instance.primaryFocus?.unfocus();
        context.push(AboutSection.terms.path);
      };
    _privacyTap = TapGestureRecognizer()
      ..onTap = () {
        FocusManager.instance.primaryFocus?.unfocus();
        context.push(AboutSection.privacy.path);
      };
  }

  AuthService get _authService =>
      widget.authService ?? auth_provider.authService;

  bool get _validInputs =>
      _agreed &&
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
    _termsTap.dispose();
    _privacyTap.dispose();
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
    final bodyStyle = AuthStyles.signupTextStyle(Body1.style);
    final labelStyle = AuthStyles.signupTextStyle(Eyebrow.style);
    final bottomSafeInset = MediaQuery.viewPaddingOf(context).bottom;
    final consentTemplate = tr(
      context,
      'By clicking sign up, I hereby agree and consent to 1touch’s {terms}; I confirm that I have read 1touch’s {privacy}.',
    );
    final termsParts = consentTemplate.split('{terms}');
    final privacyParts = termsParts[1].split('{privacy}');
    final consentParts = [termsParts[0], privacyParts[0], privacyParts[1]];

    return Scaffold(
      backgroundColor: AuthStyles.background(context),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        toolbarHeight: 24,
        leadingWidth: 56,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 24),
          child: IconButton(
            key: const ValueKey('signup-back-button'),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: SvgPicture.asset(
              'assets/auth/back.svg',
              width: 32,
              height: 24,
              colorFilter: ColorFilter.mode(colors.onSurface, BlendMode.srcIn),
            ),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/onboarding');
              }
            },
          ),
        ),
        centerTitle: true,
        title: Text(tr(context, 'Sign up'), style: bodyStyle),
      ),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              key: const ValueKey('signup-fields-scroll'),
              padding: EdgeInsets.fromLTRB(24, 0, 24,
                  bottomSafeInset + MediaQuery.viewInsetsOf(context).bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: constraints.maxHeight > bottomSafeInset
                        ? constraints.maxHeight - bottomSafeInset
                        : 0.0),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 48),
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
                        Text(tr(context, field.label), style: labelStyle),
                        const SizedBox(height: 8),
                        SignupAvailabilityField(
                          key: ValueKey(
                              'signup-${field.field.apiValue.replaceAll('_', '-')}-field'),
                          controller: field.controller,
                          maxLength: field.maxLength,
                          keyboardType: field.keyboardType,
                          enabled: !_submitting,
                          decoration: AuthStyles.inputDecoration(
                                  context, field.hint,
                                  textStyle: bodyStyle)
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
                      Text(tr(context, 'Password'), style: labelStyle),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const ValueKey('signup-password-field'),
                        controller: _password,
                        obscureText: _obscure,
                        decoration: AuthStyles.inputDecoration(
                                context, '••••••••',
                                textStyle: bodyStyle)
                            .copyWith(
                          suffixIcon: AuthPasswordVisibilityButton(
                            obscureText: _obscure,
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => isValidNewPassword(v ?? '')
                            ? null
                            : tr(context,
                                'Use 8–128 characters with uppercase and lowercase English letters and a number.'),
                        style: bodyStyle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(context,
                            'Choose a password that is 8 or more characters long.'),
                        style: labelStyle,
                      ),
                      const SizedBox(height: 16),
                      Text(tr(context, 'Retype Password'), style: labelStyle),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const ValueKey('signup-confirm-password-field'),
                        controller: _confirmPassword,
                        obscureText: _obscureConfirm,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: AuthStyles.inputDecoration(
                                context, '••••••••',
                                textStyle: bodyStyle)
                            .copyWith(
                          suffixIcon: AuthPasswordVisibilityButton(
                            obscureText: _obscureConfirm,
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        validator: (value) => value == _password.text
                            ? null
                            : tr(context, 'Passwords do not match.'),
                        style: bodyStyle,
                      ),
                      const SizedBox(height: 24),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
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
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        style: Body2.style
                                            .copyWith(color: colors.onSurface),
                                        children: [
                                          TextSpan(text: consentParts[0]),
                                          TextSpan(
                                            text:
                                                tr(context, 'Terms of Service'),
                                            style: const TextStyle(
                                                decoration:
                                                    TextDecoration.underline),
                                            recognizer: _termsTap,
                                          ),
                                          TextSpan(text: consentParts[1]),
                                          TextSpan(
                                            text: tr(context, 'Privacy Policy'),
                                            style: const TextStyle(
                                                decoration:
                                                    TextDecoration.underline),
                                            recognizer: _privacyTap,
                                          ),
                                          TextSpan(text: consentParts[2]),
                                        ],
                                      ),
                                      key:
                                          const ValueKey('signup-consent-text'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            AuthPrimaryButton(
                              buttonKey: const ValueKey('email-sign-up-button'),
                              label: trUpper(context, 'Sign up'),
                              textStyle:
                                  AuthStyles.signupTextStyle(Body2_b.style),
                              loading: _submitting,
                              onPressed: _submitting ||
                                      (_validInputs &&
                                          _availableFields.length !=
                                              RegistrationField.values.length)
                                  ? null
                                  : _submit,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
