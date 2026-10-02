import 'dart:async';

import 'package:flutter/material.dart';

/// Keeps text at its normal size and scrolls only when it exceeds its slot.
class OverflowScrollingText extends StatefulWidget {
  const OverflowScrollingText({
    super.key,
    required this.text,
    required this.style,
    this.alignment = Alignment.centerLeft,
  });

  final String text;
  final TextStyle style;
  final Alignment alignment;

  @override
  State<OverflowScrollingText> createState() => _OverflowScrollingTextState();
}

class _OverflowScrollingTextState extends State<OverflowScrollingText> {
  final ScrollController _controller = ScrollController();
  Timer? _timer;
  bool _needsScroll = false;

  @override
  void didUpdateWidget(covariant OverflowScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _timer?.cancel();
      _needsScroll = false;
      if (_controller.hasClients) _controller.jumpTo(0);
    }
  }

  void _scheduleScroll() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 800), () async {
      if (!mounted || !_needsScroll || !_controller.hasClients) return;
      final distance = _controller.position.maxScrollExtent;
      if (distance <= 0) return;
      await _controller.animateTo(
        distance,
        duration:
            Duration(milliseconds: (distance * 35).round().clamp(1200, 6000)),
        curve: Curves.linear,
      );
      if (!mounted || !_needsScroll || !_controller.hasClients) return;
      _timer = Timer(const Duration(milliseconds: 800), () {
        if (!mounted || !_needsScroll || !_controller.hasClients) return;
        _controller.jumpTo(0);
        _scheduleScroll();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: widget.text, style: widget.style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            locale: Localizations.maybeLocaleOf(context),
            maxLines: 1,
          )..layout();
          final overflow = painter.width > constraints.maxWidth + 0.5;
          painter.dispose();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || overflow == _needsScroll) return;
            _needsScroll = overflow;
            if (overflow) {
              _scheduleScroll();
            } else {
              _timer?.cancel();
              if (_controller.hasClients) _controller.jumpTo(0);
            }
          });
          final label = Text(
            widget.text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: widget.style,
          );
          return ClipRect(
            child: overflow
                ? SingleChildScrollView(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: label,
                  )
                : Align(
                    widthFactor: 1,
                    heightFactor: 1,
                    alignment: widget.alignment,
                    child: label,
                  ),
          );
        },
      );
}
