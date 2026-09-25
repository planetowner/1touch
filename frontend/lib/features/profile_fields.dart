import 'package:flutter/material.dart';
import 'package:onetouch/data/profile/current_user_repository_provider.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/user_name_labels.dart';

class ProfileFields extends StatefulWidget {
  const ProfileFields(
      {super.key,
      this.username,
      this.firstName,
      this.lastName,
      this.showNameFields = true,
      required this.onSaved});
  final String? username, firstName, lastName;
  final VoidCallback onSaved;
  final bool showNameFields;

  @override
  State<ProfileFields> createState() => _ProfileFieldsState();
}

class _ProfileFieldsState extends State<ProfileFields> {
  final _form = GlobalKey<FormState>();
  late final _username = TextEditingController(text: widget.username);
  late final _firstName = TextEditingController(text: widget.firstName);
  late final _lastName = TextEditingController(text: widget.lastName);
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await currentUserRepository.updateProfile(
          username: _username.text.trim(),
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim());
      if (mounted) widget.onSaved();
    } catch (_) {
      if (mounted)
        setState(() => _error = tr(context,
            'Unable to save profile. Check your username and try again.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
      key: _form,
      child: Column(children: [
        for (final field in [
          if (widget.showNameFields)
            ...orderedUserNameParts(
              locale: Localizations.localeOf(context),
              firstName: (_firstName, 'First name', 100),
              lastName: (_lastName, 'Last name', 100),
            ),
          (_username, 'Username', 50)
        ])
          Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: TextFormField(
                key: ValueKey(
                    'profile-${field.$2.toLowerCase().replaceAll(' ', '-')}-field'),
                controller: field.$1,
                enabled: !_saving,
                maxLength: field.$3,
                decoration: InputDecoration(
                    labelText: tr(context, field.$2), counterText: ''),
                validator: (value) => value == null || value.trim().isEmpty
                    ? tr(context, 'Enter ${field.$2.toLowerCase()}')
                    : null,
              )),
        if (_error != null) Text(_error!),
        FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving
                ? tr(context, 'Saving…')
                : tr(context, 'Save profile'))),
      ]));
}
