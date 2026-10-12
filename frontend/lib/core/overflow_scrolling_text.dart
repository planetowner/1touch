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
  final GlobalKey _textKey = GlobalKey();
  Timer? _timer;
  bool _needsScroll = false;
  bool _measured = false;

  @override
  void didUpdateWidget(covariant OverflowScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _timer?.cancel();
      _timer = null;
      _needsScroll = false;
      _measured = false;
      if (_controller.hasClients) _controller.jumpTo(0);
    }
  }

  void _checkOverflow(double availableWidth, String text) {
    if (!mounted || widget.text != text) return;
    final renderedText = _textKey.currentContext?.findRenderObject();
    if (renderedText is! RenderBox) return;
    // 실제 화면에 적용된 글꼴과 배율의 너비로 스크롤 여부를 결정해요.
    final needsScroll = renderedText.getMaxIntrinsicWidth(double.infinity) >
        availableWidth + 0.5;
    if (_measured && needsScroll == _needsScroll) return;

    _timer?.cancel();
    _timer = null;
    if (!needsScroll && _controller.hasClients) _controller.jumpTo(0);
    setState(() {
      _needsScroll = needsScroll;
      _measured = true;
    });
    if (needsScroll) {
      if (_controller.hasClients) {
        _scheduleScroll();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _needsScroll && _controller.hasClients) {
            _scheduleScroll();
          }
        });
      }
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
        duration: Duration(microseconds: (distance * 35000).ceil()),
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
          // 첫 프레임에는 기존 폭 계산으로 표시하고, 렌더링 후 실제 폭으로 보정해요.
          final painter = TextPainter(
            text: TextSpan(text: widget.text, style: widget.style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            locale: Localizations.maybeLocaleOf(context),
            maxLines: 1,
          )..layout();
          final estimatedOverflow = painter.width > constraints.maxWidth + 0.5;
          painter.dispose();
          final shouldScroll = _measured ? _needsScroll : estimatedOverflow;
          final text = widget.text;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkOverflow(constraints.maxWidth, text);
          });
          final label = Text(
            widget.text,
            key: _textKey,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: widget.style,
          );
          return ClipRect(
            child: shouldScroll
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
