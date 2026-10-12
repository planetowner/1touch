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
    this.focusNode,
    this.nextFocusNode,
    this.enabled = true,
    this.insetLabel,
    this.availableMessage = "It's available.",
    this.guideMessage,
    this.unavailableMessage = 'Already in use.',
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final String? Function(String) validator;
  final Future<bool> Function(String) checkAvailability;
  final ValueChanged<bool> onAvailabilityChanged;
  final int? maxLength;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final bool enabled;
  final String? insetLabel;
  final String availableMessage;
  final String? guideMessage;
  final String unavailableMessage;

  @override
  State<SignupAvailabilityField> createState() =>
      _SignupAvailabilityFieldState();
}

class _SignupAvailabilityFieldState extends State<SignupAvailabilityField> {
  late final DebouncedSearchController<bool> _availability;
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  late final _focusNode = widget.focusNode ?? FocusNode();

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
    // 입력칸을 떠난 뒤 도착한 중복 결과도 표시해요. 입력 중에는 새 오류를 띄우지 않아요.
    if (!_availability.loading &&
        _availability.result != null &&
        (!_focusNode.hasFocus || _fieldKey.currentState?.hasError == true)) {
      _fieldKey.currentState?.validate();
    }
    widget.onAvailabilityChanged(_availability.result == true &&
        !_availability.loading &&
        _availability.error == null);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_inputChanged);
    _availability.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final helper = _availability.loading
        ? 'Checking availability...'
        : _availability.error != null
            ? "We couldn't check if it's available. Please try again."
            : _availability.result == true
                ? widget.availableMessage
                : widget.guideMessage;
    final input = TextFormField(
      key: _fieldKey,
      controller: widget.controller,
      // 오류는 안내 문구로 표시하고 커서는 앱의 기본 색상을 유지해요.
      cursorErrorColor: Theme.of(context).colorScheme.primary,
      enabled: widget.enabled,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      focusNode: _focusNode,
      textInputAction: widget.nextFocusNode == null
          ? TextInputAction.done
          : TextInputAction.next,
      onEditingComplete: widget.nextFocusNode?.requestFocus,
      textAlignVertical:
          widget.insetLabel == null ? null : TextAlignVertical.bottom,
      decoration: widget.decoration.copyWith(
        helper: helper == null
            ? null
            : AuthFieldMessage(
                text: tr(context, helper),
                decoration: widget.decoration,
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
      validator: (value) =>
          AuthForm.of(context).validationMessage(value, (value) {
        final message = widget.validator(value ?? '') ??
            (_availability.result == false ? widget.unavailableMessage : null);
        return message == null ? null : tr(context, message);
      }),
      errorBuilder: (context, message) => AuthFieldMessage(
          text: message, decoration: widget.decoration, error: true),
      style: AuthStyles.signupTextStyle(Body1.style),
    );
    return widget.insetLabel == null
        ? input
        : AuthInsetLabel(label: widget.insetLabel!, child: input);
  }
}
