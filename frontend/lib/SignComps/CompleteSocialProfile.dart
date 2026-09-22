import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/auth/auth_repository_provider.dart'
    as auth_provider;
import 'package:onetouch/data/auth/auth_request_exception.dart';
import 'package:onetouch/data/auth/auth_service.dart';

class CompleteSocialProfileScreen extends StatefulWidget {
  const CompleteSocialProfileScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<CompleteSocialProfileScreen> createState() =>
      _CompleteSocialProfileScreenState();
}

class _CompleteSocialProfileScreenState
    extends State<CompleteSocialProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  bool _submitting = false;

  AuthService get _authService =>
      widget.authService ?? auth_provider.authService;

  bool get _canSubmit =>
      !_submitting &&
      _firstName.text.trim().isNotEmpty &&
      _lastName.text.trim().isNotEmpty &&
      _username.text.trim().isNotEmpty;

  InputDecoration _dec(BuildContext context, String hint) {
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
    );
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await _authService.completeSocialProfile(
        username: _username.text.trim(),
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
      );
      if (!mounted) return;
      context.go('/onboarding/welcome');
    } on AuthRequestException catch (error) {
      if (!mounted) return;
      _showError(error.displayMessage);
    } on Object {
      if (!mounted) return;
      _showError('Unable to save your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('Complete profile', style: Body1.style),
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
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('First name', style: Eyebrow.style),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: const ValueKey('social-profile-first-name'),
                          controller: _firstName,
                          enabled: !_submitting,
                          textInputAction: TextInputAction.next,
                          maxLength: 100,
                          decoration:
                              _dec(context, 'John').copyWith(counterText: ''),
                          style: Body1.style,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter first name'
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        const Text('Last name', style: Eyebrow.style),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: const ValueKey('social-profile-last-name'),
                          controller: _lastName,
                          enabled: !_submitting,
                          textInputAction: TextInputAction.next,
                          maxLength: 100,
                          decoration:
                              _dec(context, 'Doe').copyWith(counterText: ''),
                          style: Body1.style,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter last name'
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        const Text('Username', style: Eyebrow.style),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: const ValueKey('social-profile-username'),
                          controller: _username,
                          enabled: !_submitting,
                          textInputAction: TextInputAction.done,
                          maxLength: 50,
                          decoration: _dec(context, 'john_doe')
                              .copyWith(counterText: ''),
                          style: Body1.style,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter username'
                                  : null,
                          onFieldSubmitted: (_) {
                            if (_canSubmit) _submit();
                          },
                        ),
                        const Spacer(),
                        FilledButton(
                          key: const ValueKey('social-profile-continue'),
                          onPressed: _canSubmit ? _submit : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            backgroundColor: colors.onSurface,
                            foregroundColor: colors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _submitting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.surface,
                                  ),
                                )
                              : Text(
                                  'CONTINUE',
                                  style: Body2_b.style
                                      .copyWith(color: colors.surface),
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
