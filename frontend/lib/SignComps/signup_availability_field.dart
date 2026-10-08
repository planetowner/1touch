import 'package:flutter/material.dart';
import 'package:onetouch/SignComps/auth_widgets.dart';
import 'package:onetouch/core/debounced_search_controller.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class SignupAvailabilityField extends StatefulWidget {
  const SignupAvailabilityField({
    super.key,
    required this.controller,
    required this.decoration,
    required this.validator,
    required this.checkAvailability,
    required this.onAvailabilityChanged,
    this.maxLength,
    this.keyboardType,
    this.enabled = true,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final String? Function(String) validator;
  final Future<bool> Function(String) checkAvailability;
  final ValueChanged<bool> onAvailabilityChanged;
  final int? maxLength;
  final TextInputType? keyboardType;
  final bool enabled;

  @override
  State<SignupAvailabilityField> createState() =>
      _SignupAvailabilityFieldState();
}

class _SignupAvailabilityFieldState extends State<SignupAvailabilityField> {
  late final DebouncedSearchController<bool> _availability;

  @override
  void initState() {
    super.initState();
    _availability = DebouncedSearchController(search: widget.checkAvailability)
      ..addListener(_availabilityChanged);
    widget.controller.addListener(_inputChanged);
  }

  void _inputChanged() {
    final value = widget.controller.text;
    // 형식이 맞는 입력만 조회하고, 값이 바뀌면 이전 사용 가능 결과를 바로 지워요.
    _availability.updateQuery(widget.validator(value) == null ? value : '');
  }

  void _availabilityChanged() {
    setState(() {});
    widget.onAvailabilityChanged(_availability.result == true &&
        !_availability.loading &&
        _availability.error == null);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_inputChanged);
    _availability.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final helper = _availability.loading
        ? 'Checking availability...'
        : _availability.error != null
            ? 'Unable to check availability. Try again.'
            : _availability.result == true
                ? 'Available.'
                : null;
    final border = widget.decoration.border;
    final statusInset = (widget.decoration.contentPadding
                ?.resolve(Directionality.of(context))
                .left ??
            0) +
        (Theme.of(context).useMaterial3 && border is OutlineInputBorder
            ? border.gapPadding
            : 0);
    Widget alignStatus(String message, {TextStyle? style}) =>
        Transform.translate(
          offset: Offset(-statusInset, 0),
          // Material 3의 기본 간격 4에 더해 Figma의 안내문 간격 8을 맞춰요.
          child: Padding(
            padding:
                EdgeInsets.only(top: Theme.of(context).useMaterial3 ? 4 : 0),
            child: Text(message,
                style: style ?? AuthStyles.signupTextStyle(Eyebrow.style)),
          ),
        );
    return TextFormField(
      controller: widget.controller,
      // 오류는 안내 문구로 표시하고 커서는 앱의 기본 색상을 유지해요.
      cursorErrorColor: Theme.of(context).colorScheme.primary,
      enabled: widget.enabled,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: widget.decoration.copyWith(
        helper: helper == null
            ? null
            : alignStatus(
                tr(context, helper),
                style: AuthStyles.signupTextStyle(Eyebrow.style).copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
        helperMaxLines: 2,
        suffixIcon: _availability.error == null
            ? null
            : IconButton(
                tooltip: tr(context, 'Try again'),
                onPressed: widget.enabled ? _availability.search : null,
                icon: const Icon(Icons.refresh),
              ),
      ),
      validator: (value) {
        final message = widget.validator(value ?? '') ??
            (_availability.result == false ? 'Already in use.' : null);
        return message == null ? null : tr(context, message);
      },
      errorBuilder: (context, message) => alignStatus(message),
      style: AuthStyles.signupTextStyle(Body1.style),
    );
  }
}
