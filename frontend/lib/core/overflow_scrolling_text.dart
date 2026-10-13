import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Keeps text at its normal size and scrolls only when it exceeds its slot.
class OverflowScrollingText extends StatefulWidget {
  const OverflowScrollingText({
    super.key,
    required this.text,
    required this.style,
    this.alignment = Alignment.centerLeft,
    this.leading,
    this.leadingWidth = 0,
  });

  final String text;
  final TextStyle style;
  final Alignment alignment;
  final Widget? leading;
  final double leadingWidth;

  @override
  State<OverflowScrollingText> createState() => _OverflowScrollingTextState();
}

class _OverflowScrollingTextState extends State<OverflowScrollingText> {
  final ScrollController _controller = ScrollController();
  final GlobalKey _contentKey = GlobalKey();
  Timer? _timer;
  bool _needsScroll = false;
  bool _measured = false;

  @override
  void didUpdateWidget(covariant OverflowScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.leadingWidth != widget.leadingWidth ||
        (oldWidget.leading == null) != (widget.leading == null)) {
      _timer?.cancel();
      _timer = null;
      _needsScroll = false;
      _measured = false;
      if (_controller.hasClients) _controller.jumpTo(0);
    }
  }

  void _checkOverflow(double availableWidth, String text) {
    if (!mounted || widget.text != text) return;
    final renderedContent = _contentKey.currentContext?.findRenderObject();
    if (renderedContent is! RenderBox) return;
    // 실제 화면에 적용된 글꼴과 배율의 너비로 스크롤 여부를 결정해요.
    final needsScroll = renderedContent.getMaxIntrinsicWidth(double.infinity) >
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
          final estimatedOverflow =
              painter.width + widget.leadingWidth > constraints.maxWidth + 0.5;
          painter.dispose();
          final shouldScroll = _measured ? _needsScroll : estimatedOverflow;
          final text = widget.text;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkOverflow(constraints.maxWidth, text);
          });
          final label = Text(
            widget.text,
            key: widget.leading == null ? _contentKey : null,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: widget.style,
          );
          // 로고와 문구가 하나의 스크롤 콘텐츠로 함께 움직이게 해요.
          final content = widget.leading == null
              ? label
              : Row(
                  key: _contentKey,
                  mainAxisSize: MainAxisSize.min,
                  children: [widget.leading!, label],
                );
          return ClipRect(
            child: shouldScroll
                ? SingleChildScrollView(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: content,
                  )
                : Align(
                    widthFactor: 1,
                    heightFactor: 1,
                    alignment: widget.alignment,
                    // 첫 프레임의 폭 추정이 빗나가도 로고 Row의 레이아웃은 넘치지 않게 해요.
                    child: widget.leading == null
                        ? content
                        : OverflowBox(
                            maxWidth: double.infinity,
                            fit: OverflowBoxFit.deferToChild,
                            alignment: widget.alignment,
                            child: content,
                          ),
                  ),
          );
        },
      );
}
