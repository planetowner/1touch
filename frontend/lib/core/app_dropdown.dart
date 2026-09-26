import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';

/// Shared measurements exported from the app dropdown component in Figma.
abstract final class AppDropdownTokens {
  static const double height = 40;
  static const double radius = 16;
  static const double iconSize = 24;
  static const double gap = 8;

  static const EdgeInsets triggerPadding = EdgeInsets.fromLTRB(16, 8, 8, 8);
  static const EdgeInsets compactPadding = EdgeInsets.all(8);
  static const EdgeInsets menuPadding = EdgeInsets.symmetric(vertical: 8);
  static const EdgeInsets optionPadding = EdgeInsets.fromLTRB(16, 4, 8, 4);

  static const double optionHeight = 32;
  static const double selectedOptionRadius = 8;
}

class AppDropdownOption<T> {
  const AppDropdownOption({
    required this.value,
    required this.label,
    this.selected,
    this.enabled = true,
    this.dividerBefore = false,
    this.optionKey,
    this.selectedIconKey,
  });

  final T value;
  final String label;
  final bool? selected;
  final bool enabled;
  final bool dividerBefore;
  final Key? optionKey;
  final Key? selectedIconKey;
}

/// Shared dropdown trigger and overlay menu.
///
/// The menu lives in the navigator overlay, so opening it never changes the
/// surrounding layout. Its width follows the widest option (or the trigger
/// when that is wider), and option labels stay left aligned.
class AppDropdown<T> extends StatefulWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.selectedLabel,
    this.hintText,
    this.triggerKey,
    this.chevronKey,
    this.width,
    this.minWidth,
    this.maxMenuHeight,
    this.matchMenuWidth = false,
    this.enabled = true,
    this.backgroundColor,
    this.foregroundColor,
    this.textStyle,
    this.boxShadow,
  });

  final T? value;
  final List<AppDropdownOption<T>> options;
  final ValueChanged<T> onChanged;
  final String? selectedLabel;
  final String? hintText;
  final Key? triggerKey;
  final Key? chevronKey;
  final double? width;
  final double? minWidth;
  final double? maxMenuHeight;
  final bool matchMenuWidth;
  final bool enabled;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final TextStyle? textStyle;
  final List<BoxShadow>? boxShadow;

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>> {
  bool _isOpen = false;

  String get _label {
    if (widget.selectedLabel != null) return widget.selectedLabel!;
    for (final option in widget.options) {
      if (option.value == widget.value) return option.label;
    }
    return widget.hintText ?? '';
  }

  Future<void> _openMenu() async {
    if (!widget.enabled || widget.options.isEmpty || _isOpen) return;

    final trigger = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final triggerOrigin = trigger.localToGlobal(Offset.zero, ancestor: overlay);
    final textStyle = widget.textStyle ?? Body2_b.style;
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    var longestOptionWidth = 0.0;
    for (final option in widget.options) {
      final painter = TextPainter(
        text: TextSpan(text: option.label, style: textStyle),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      if (painter.width > longestOptionWidth) {
        longestOptionWidth = painter.width;
      }
    }

    final availableWidth = overlay.size.width - 16;
    final optionChromeWidth = AppDropdownTokens.optionPadding.horizontal +
        AppDropdownTokens.gap +
        AppDropdownTokens.iconSize +
        AppDropdownTokens.gap;
    final menuWidth = widget.matchMenuWidth
        ? trigger.size.width.clamp(0.0, availableWidth).toDouble()
        : (longestOptionWidth + optionChromeWidth)
            .clamp(trigger.size.width, availableWidth)
            .toDouble();
    final triggerRight = triggerOrigin.dx + trigger.size.width;
    final alignToRight =
        triggerOrigin.dx + trigger.size.width / 2 >= overlay.size.width / 2;
    final desiredLeft =
        alignToRight ? triggerRight - menuWidth : triggerOrigin.dx;
    final left =
        desiredLeft.clamp(8.0, overlay.size.width - menuWidth - 8).toDouble();
    final top = triggerOrigin.dy + trigger.size.height + 4;
    final foreground =
        widget.foregroundColor ?? Theme.of(context).colorScheme.onSurface;
    final menuColor =
        widget.backgroundColor ?? AppColors.of(context).subtleBackground;

    setState(() => _isOpen = true);
    final selected = await showMenu<T>(
      context: context,
      useRootNavigator: true,
      color: menuColor,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDropdownTokens.radius),
      ),
      menuPadding: AppDropdownTokens.menuPadding,
      constraints: BoxConstraints(
        minWidth: menuWidth,
        maxWidth: menuWidth,
        maxHeight: widget.maxMenuHeight ?? double.infinity,
      ),
      position: RelativeRect.fromLTRB(
        left,
        top,
        overlay.size.width - left - menuWidth,
        0,
      ),
      items: [
        for (final option in widget.options) ...[
          if (option.dividerBefore)
            PopupMenuItem<T>(
              enabled: false,
              height: 9,
              padding: EdgeInsets.zero,
              child: Divider(
                height: 1,
                color: AppColors.of(context).divider,
              ),
            ),
          PopupMenuItem<T>(
            key: option.optionKey ??
                ValueKey('app-dropdown-option-${option.value}'),
            value: option.value,
            enabled: option.enabled,
            height: AppDropdownTokens.optionHeight,
            padding: AppDropdownTokens.optionPadding,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: textStyle.copyWith(color: foreground),
                  ),
                ),
                const SizedBox(width: AppDropdownTokens.gap),
                SizedBox(
                  width: AppDropdownTokens.iconSize,
                  height: AppDropdownTokens.iconSize,
                  child: (option.selected ?? option.value == widget.value)
                      ? Icon(
                          Icons.check,
                          key: option.selectedIconKey,
                          size: AppDropdownTokens.iconSize,
                          color: foreground,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ],
    );

    if (!mounted) return;
    setState(() => _isOpen = false);
    if (selected != null) widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final foreground =
        widget.foregroundColor ?? Theme.of(context).colorScheme.onSurface;
    final background =
        widget.backgroundColor ?? AppColors.of(context).subtleBackground;
    final textStyle =
        (widget.textStyle ?? Body2_b.style).copyWith(color: foreground);
    final labelPainter = TextPainter(
      text: TextSpan(text: _label, style: textStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    const triggerChromeWidth = 16.0 + 40.0 + AppDropdownTokens.gap;
    var intrinsicWidth = labelPainter.width + triggerChromeWidth;
    if (widget.matchMenuWidth) {
      var longestOptionWidth = 0.0;
      for (final option in widget.options) {
        final optionPainter = TextPainter(
          text: TextSpan(text: option.label, style: textStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        if (optionPainter.width > longestOptionWidth) {
          longestOptionWidth = optionPainter.width;
        }
      }
      final optionChromeWidth = AppDropdownTokens.optionPadding.horizontal +
          AppDropdownTokens.gap +
          AppDropdownTokens.iconSize +
          AppDropdownTokens.gap;
      final widestMenuContent = longestOptionWidth + optionChromeWidth;
      if (widestMenuContent > intrinsicWidth) {
        intrinsicWidth = widestMenuContent;
      }
    }
    final triggerWidth = widget.width ??
        intrinsicWidth.clamp(widget.minWidth ?? 0, double.infinity).toDouble();

    return Semantics(
      button: true,
      enabled: widget.enabled,
      expanded: _isOpen,
      child: GestureDetector(
        onTap: widget.enabled ? _openMenu : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          key: widget.triggerKey,
          width: triggerWidth,
          height: AppDropdownTokens.height,
          constraints: BoxConstraints(minWidth: widget.minWidth ?? 0),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppDropdownTokens.radius),
            boxShadow: widget.boxShadow,
          ),
          child: Stack(
            children: [
              Positioned(
                left: 16,
                right: 40,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: textStyle,
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: SizedBox(
                  key: widget.chevronKey,
                  width: AppDropdownTokens.iconSize,
                  height: AppDropdownTokens.iconSize,
                  child: AppDropdownChevron(
                    expanded: _isOpen,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppDropdownChevron extends StatelessWidget {
  const AppDropdownChevron({
    super.key,
    this.expanded = false,
    this.color,
  });

  final bool expanded;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
      size: AppDropdownTokens.iconSize,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }
}
