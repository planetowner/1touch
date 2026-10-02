import 'package:flutter/material.dart';
import 'package:onetouch/SignComps/auth_widgets.dart';
import 'package:onetouch/SignComps/signup_availability_field.dart';
import 'package:onetouch/core/identity_name_rules.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class SocialProfileSetup extends StatefulWidget {
  const SocialProfileSetup({
    super.key,
    required this.checkNicknameAvailability,
    required this.onContinue,
    required this.onBack,
    this.initialNickname,
  });

  final Future<bool> Function(String) checkNicknameAvailability;
  final Future<void> Function(String nickname) onContinue;
  final Future<void> Function() onBack;
  final String? initialNickname;

  @override
  State<SocialProfileSetup> createState() => _SocialProfileSetupState();
}

class _SocialProfileSetupState extends State<SocialProfileSetup> {
  final _formKey = GlobalKey<FormState>();
  late final _nickname = TextEditingController(text: widget.initialNickname);
  bool _nicknameAvailable = false;
  bool _saving = false;

  @override
  void dispose() {
    _nickname.dispose();
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
