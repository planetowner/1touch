import 'package:flutter/material.dart';
import 'package:onetouch/SignComps/auth_widgets.dart';
import 'package:onetouch/SignComps/signup_availability_field.dart';
import 'package:onetouch/core/identity_name_rules.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/user_name_labels.dart';

class SocialProfileSetup extends StatefulWidget {
  const SocialProfileSetup({
    super.key,
    required this.checkNicknameAvailability,
    required this.onContinue,
    required this.onBack,
    this.initialNickname,
    this.initialFirstName,
    this.initialLastName,
  });

  final Future<bool> Function(String) checkNicknameAvailability;
  final Future<void> Function(
      String nickname, String firstName, String lastName) onContinue;
  final Future<void> Function() onBack;
  final String? initialNickname;
  final String? initialFirstName;
  final String? initialLastName;

  @override
  State<SocialProfileSetup> createState() => _SocialProfileSetupState();
}

class _SocialProfileSetupState extends State<SocialProfileSetup> {
  final _formKey = GlobalKey<FormState>();
  late final _nickname = TextEditingController(text: widget.initialNickname);
  late final _firstName = TextEditingController(text: widget.initialFirstName);
  late final _lastName = TextEditingController(text: widget.initialLastName);
  bool _nicknameAvailable = false;
  bool _saving = false;

  @override
  void dispose() {
    _nickname.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  InputDecoration _dec(BuildContext context, String hint) {
    final colors = AppColors.of(context);
    return InputDecoration(
      hintText: hint,
      hintStyle: Body1.style.copyWith(color: colors.mutedForeground),
      filled: true,
      fillColor: colors.subtleBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _submit() async {
    if (_saving || !_nicknameAvailable || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onContinue(
        _nickname.text.trim(),
        _firstName.text.trim(),
        _lastName.text.trim(),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(tr(context, 'Unable to save your profile. Please try again.')),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AuthStyles.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: BackButton(
          color: colors.onSurface,
          onPressed: _saving ? null : () => widget.onBack(),
        ),
        title: Text(tr(context, 'Pick a nickname'), style: Body1.style),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),
                    Text(tr(context, 'Nickname'), style: Eyebrow.style),
                    const SizedBox(height: 8),
                    SignupAvailabilityField(
                      key: const ValueKey('social-nickname-field'),
                      controller: _nickname,
                      enabled: !_saving,
                      maxLength: 12,
                      decoration:
                          _dec(context, 'Nickname').copyWith(counterText: ''),
                      validator: displayNameValidationMessage,
                      checkAvailability: widget.checkNicknameAvailability,
                      onAvailabilityChanged: (available) {
                        if (_nicknameAvailable != available) {
                          setState(() => _nicknameAvailable = available);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (index, field) in orderedUserNameParts(
                          locale: Localizations.localeOf(context),
                          firstName: (_firstName, 'First name'),
                          lastName: (_lastName, 'Last name'),
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
                                    'social-${field.$2.toLowerCase().replaceAll(' ', '-')}-field',
                                  ),
                                  controller: field.$1,
                                  enabled: !_saving,
                                  style: Body1.style,
                                  decoration: _dec(context, field.$2),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                          ? tr(context,
                                              'Enter ${field.$2.toLowerCase()}')
                                          : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: AuthPrimaryButton(
              label: tr(context, 'CONTINUE'),
              loading: _saving,
              onPressed: _saving || !_nicknameAvailable ? null : _submit,
            ),
          ),
        ]),
      ),
    );
  }
}
