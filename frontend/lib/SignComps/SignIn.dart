import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/auth/auth_repository_provider.dart'
    as auth_provider;
import 'package:onetouch/data/auth/auth_service.dart';

class EmailSignInScreen extends StatefulWidget {
  const EmailSignInScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends State<EmailSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _submitting = false;

  AuthService get _authService =>
      widget.authService ?? auth_provider.authService;

  bool get _canSubmit =>
      !_submitting &&
      _username.text.trim().isNotEmpty &&
      _password.text.length >= 8;

  InputDecoration _fieldDecoration(BuildContext context, String hint) {
    final appColors = AppColors.of(context);
    return InputDecoration(
      hintText: hint,
      hintStyle: Body1.style.copyWith(color: appColors.mutedForeground),
      filled: true,
      fillColor: appColors.subtleBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final status = await _authService.signInWithPassword(
        username: _username.text.trim(),
        password: _password.text,
        rememberMe: _rememberMe,
      );
      if (!mounted) return;
      context.go(
        status.onboardingComplete
            ? '/home'
            : status.profileComplete
                ? '/onboarding/welcome'
                : '/onboarding/profile',
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to sign in. Check your username and password.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);

    return Scaffold(
      backgroundColor: appColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: colors.onSurface, onPressed: _goBack),
        centerTitle: true,
        title: Text('Sign in', style: Body1.style),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  onChanged: () => setState(() {}),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Username', style: Body1.style),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: const ValueKey('sign-in-username'),
                          controller: _username,
                          enabled: !_submitting,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          style: Body1.style,
                          decoration: _fieldDecoration(context, 'john_doe'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter username'
                                  : null,
                        ),
                        const SizedBox(height: 24),
                        const Text('Password', style: Body1.style),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: const ValueKey('sign-in-password'),
                          controller: _password,
                          enabled: !_submitting,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) {
                            if (_canSubmit) _submit();
                          },
                          style: Body1.style,
                          decoration:
                              _fieldDecoration(context, '••••••••').copyWith(
                            suffixIcon: IconButton(
                              key: const ValueKey('sign-in-password-toggle'),
                              onPressed: _submitting
                                  ? null
                                  : () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              value != null && value.length >= 8
                                  ? null
                                  : 'At least 8 characters',
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            SizedBox(
                              width: 32,
                              height: 40,
                              child: Checkbox(
                                key: const ValueKey('sign-in-remember-me'),
                                value: _rememberMe,
                                onChanged: _submitting
                                    ? null
                                    : (value) => setState(
                                          () => _rememberMe = value ?? false,
                                        ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Remember me',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Body1.style,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              key: const ValueKey('sign-in-sign-up-link'),
                              onPressed: _submitting
                                  ? null
                                  : () => context.push('/auth/signup'),
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Need sign up?'),
                            ),
                          ],
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            key: const ValueKey('email-sign-in-button'),
                            onPressed: _canSubmit ? _submit : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.onSurface,
                              foregroundColor: colors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _submitting
                                ? SizedBox.square(
                                    key: const ValueKey(
                                      'email-sign-in-progress',
                                    ),
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.surface,
                                    ),
                                  )
                                : Text(
                                    'SIGN IN',
                                    style: Body2_b.style.copyWith(
                                      color: colors.surface,
                                    ),
                                  ),
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
