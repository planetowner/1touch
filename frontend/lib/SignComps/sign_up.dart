import 'package:flutter/material.dart';
import 'package:onetouch/core/app_snack_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/comm_pages/Profile_settings/about_detail_page.dart';
import 'package:onetouch/core/identity_name_rules.dart';
import 'package:onetouch/core/stylesheet.dart';
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
  if (email.isEmpty) return 'Enter your email address.';
  return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)
      ? null
      : 'Enter a valid email address.';
}

class EmailSignUpScreen extends StatefulWidget {
  const EmailSignUpScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends State<EmailSignUpScreen> {
  final _formKey = GlobalKey<AuthFormState>();

  final _username = TextEditingController();
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _availability = <RegistrationField, SignupAvailability>{};
  final _confirmPassword = TextEditingController();
  final _fieldFocusNodes = List.generate(5, (_) => FocusNode());

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

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      _showCodeRequestError(
          tr(context, 'Please agree to the Terms and Privacy Policy.'));
      return;
    }
    if (!RegistrationField.values.every(
        (field) => _availability[field] == SignupAvailability.available)) {
      return;
    }

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
    } on Object catch (error) {
      if (!mounted) return;
      _showCodeRequestError(
        tr(
            context,
            authRequestErrorMessage(error,
                fallback:
                    'Unable to send a verification code. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _setAvailability(RegistrationField field, SignupAvailability status) {
    if (_availability[field] == status) return;
    setState(() => _availability[field] = status);
  }

  void _showCodeRequestError(String message) {
    showAppSnackBar(context, tr(context, message), replaceCurrent: true);
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
    for (final node in _fieldFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bodyStyle = AuthStyles.signupTextStyle(Body1.style);
    final passwordDecoration =
        AuthStyles.signupInputDecoration(context, password: true);
    // Figma의 하단 여백 72 안에 기기의 안전 영역을 포함해요.
    final bottomSpacing =
        MediaQuery.viewPaddingOf(context).bottom.clamp(72.0, double.infinity);
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
        child: AuthForm(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) => Padding(
              // 키보드 높이는 스크롤 영역에서 빼고, 기존 콘텐츠 배치는 유지해요.
              padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: SingleChildScrollView(
                key: const ValueKey('signup-fields-scroll'),
                padding: EdgeInsets.fromLTRB(24, 0, 24, bottomSpacing),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight: constraints.maxHeight > bottomSpacing
                          ? constraints.maxHeight - bottomSpacing
                          : 0.0),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 48),
                        for (final (index, field) in [
                          (
                            field: RegistrationField.username,
                            label: 'ID',
                            controller: _username,
                            maxLength: 30,
                            keyboardType: null,
                            validator: usernameValidationMessage,
                            hint: usernameGuideMessage,
                            takenMessage: usernameTakenMessage,
                          ),
                          (
                            field: RegistrationField.displayName,
                            label: 'Nickname',
                            controller: _displayName,
                            maxLength: 12,
                            keyboardType: null,
                            validator: displayNameValidationMessage,
                            hint: displayNameGuideMessage,
                            takenMessage: displayNameTakenMessage,
                          ),
                          (
                            field: RegistrationField.email,
                            label: 'Email',
                            controller: _email,
                            maxLength: null,
                            keyboardType: TextInputType.emailAddress,
                            validator: _emailValidationMessage,
                            hint: null,
                            takenMessage:
                                'That email address is already in use. Try another one.',
                          ),
                        ].indexed) ...[
                          SignupAvailabilityField(
                            key: ValueKey(
                                'signup-${field.field.apiValue.replaceAll('_', '-')}-field'),
                            controller: field.controller,
                            maxLength: field.maxLength,
                            keyboardType: field.keyboardType,
                            focusNode: _fieldFocusNodes[index],
                            nextFocusNode: _fieldFocusNodes[index + 1],
                            enabled: !_submitting,
                            insetLabel: tr(context, field.label),
                            decoration:
                                AuthStyles.signupInputDecoration(context),
                            validator: field.validator,
                            guideMessage: field.hint,
                            unavailableMessage: field.takenMessage,
                            checkAvailability: (value) =>
                                _authService.isRegistrationValueAvailable(
                                    field: field.field, value: value),
                            onAvailabilityChanged: (status) =>
                                _setAvailability(field.field, status),
                          ),
                          const SizedBox(height: 24),
                        ],
                        for (final field in [
                          (
                            key: 'signup-password-field',
                            label: 'Password',
                            controller: _password,
                            obscure: _obscure,
                            toggle: () => setState(() => _obscure = !_obscure),
                            validator: (String? value) =>
                                newPasswordValidationMessage(value ?? ''),
                            guide: passwordGuideMessage,
                            confirm: false,
                          ),
                          (
                            key: 'signup-confirm-password-field',
                            label: 'Retype Password',
                            controller: _confirmPassword,
                            obscure: _obscureConfirm,
                            toggle: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                            validator: (String? value) =>
                                passwordConfirmationValidationMessage(
                                    value ?? '', _password.text),
                            guide: null,
                            confirm: true,
                          ),
                        ]) ...[
                          AuthInsetLabel(
                            key: ValueKey(field.key),
                            label: tr(context, field.label),
                            password: true,
                            keepAboveKeyboard: field.confirm,
                            child: TextFormField(
                              controller: field.controller,
                              focusNode:
                                  _fieldFocusNodes[field.confirm ? 4 : 3],
                              textInputAction: field.confirm
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              // 보기 버튼에 멈추지 않고 비밀번호 재입력 칸으로 이동해요.
                              onEditingComplete: field.confirm
                                  ? null
                                  : _fieldFocusNodes[4].requestFocus,
                              enabled: !_submitting,
                              // 비밀번호 검증 오류도 커서 색상은 바꾸지 않아요.
                              cursorErrorColor: colors.primary,
                              obscureText: field.obscure,
                              autocorrect: false,
                              enableSuggestions: false,
                              // Outline의 위쪽 정렬은 큰 상단 여백을 무시하므로 아래 여백에 맞춰요.
                              textAlignVertical: TextAlignVertical.bottom,
                              decoration: passwordDecoration.copyWith(
                                helper: field.guide == null
                                    ? null
                                    : AuthFieldMessage(
                                        text: tr(context, field.guide!),
                                        decoration: passwordDecoration,
                                      ),
                                suffixIcon: AuthPasswordVisibilityButton(
                                  obscureText: field.obscure,
                                  onPressed: field.toggle,
                                ),
                              ),
                              validator: (value) {
                                final message = _formKey.currentState!
                                    .validationMessage(value, field.validator);
                                return message == null
                                    ? null
                                    : tr(context, message);
                              },
                              errorBuilder: (context, message) =>
                                  AuthFieldMessage(
                                text: message,
                                decoration: passwordDecoration,
                                error: true,
                              ),
                              style: bodyStyle,
                            ),
                          ),
                          if (!field.confirm) const SizedBox(height: 24),
                        ],
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
                                        onChanged: (v) => setState(
                                            () => _agreed = v ?? false),
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
                                          style: Body2.style.copyWith(
                                              color: colors.onSurface),
                                          children: [
                                            TextSpan(text: consentParts[0]),
                                            TextSpan(
                                              text: tr(
                                                  context, 'Terms of Service'),
                                              style: const TextStyle(
                                                  decoration:
                                                      TextDecoration.underline),
                                              recognizer: _termsTap,
                                            ),
                                            TextSpan(text: consentParts[1]),
                                            TextSpan(
                                              text:
                                                  tr(context, 'Privacy Policy'),
                                              style: const TextStyle(
                                                  decoration:
                                                      TextDecoration.underline),
                                              recognizer: _privacyTap,
                                            ),
                                            TextSpan(text: consentParts[2]),
                                          ],
                                        ),
                                        key: const ValueKey(
                                            'signup-consent-text'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              AuthPrimaryButton(
                                buttonKey:
                                    const ValueKey('email-sign-up-button'),
                                label: trUpper(context, 'Sign up'),
                                textStyle:
                                    AuthStyles.signupTextStyle(Body2_b.style),
                                loading: _submitting,
                                onPressed: _submitting ||
                                        _availability.values.any(
                                            (status) => status.blocksSubmission)
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
      ),
    );
  }
}
