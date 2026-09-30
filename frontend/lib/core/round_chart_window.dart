import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Up to thirteen completed rounds, with the latest seven visible on entry.
class RoundChartWindow {
  const RoundChartWindow._(this.firstRound, this.lastRound);

  factory RoundChartWindow.endingAt(int latestRound) {
    final lastCompletedRound = math.max(1, latestRound);
    return RoundChartWindow._(
      math.max(1, lastCompletedRound - 12),
      math.max(7, lastCompletedRound),
    );
  }

  final int firstRound;
  final int lastRound;

  int get firstVisibleRound => math.max(firstRound, lastRound - 6);
  int get lastVisibleRound => lastRound;
  int get centerRound => firstVisibleRound + 3;
  int get intervalCount => lastRound - firstRound;

  double contentWidth(double viewportWidth) =>
      viewportWidth * intervalCount / 6;

  double initialScrollOffset(double viewportWidth) =>
      contentWidth(viewportWidth) - viewportWidth;

  bool contains(int round) => round >= firstRound && round <= lastRound;

  double fractionOf(num round) => (round - firstRound) / intervalCount;

  double roundAt(double x, double width) =>
      firstRound + (x / width).clamp(0.0, 1.0) * intervalCount;
}

class RoundChartViewport extends StatefulWidget {
  const RoundChartViewport({
    super.key,
    required this.roundWindow,
    required this.viewportSize,
    required this.builder,
  });

  final RoundChartWindow roundWindow;
  final Size viewportSize;
  final Widget Function(BuildContext context, Size contentSize) builder;

  @override
  State<RoundChartViewport> createState() => _RoundChartViewportState();
}

class _RoundChartViewportState extends State<RoundChartViewport> {
  ScrollController? _controller;
  double? _initialWidth;
  int? _initialFirstRound;
  int? _initialLastRound;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewportWidth = widget.viewportSize.width;
    if (_controller == null) {
      _initialWidth = viewportWidth;
      _initialFirstRound = widget.roundWindow.firstRound;
      _initialLastRound = widget.roundWindow.lastRound;
      _controller = ScrollController(
        initialScrollOffset:
            widget.roundWindow.initialScrollOffset(viewportWidth),
      );
    } else if (_initialWidth != viewportWidth ||
        _initialFirstRound != widget.roundWindow.firstRound ||
        _initialLastRound != widget.roundWindow.lastRound) {
      _initialWidth = viewportWidth;
      _initialFirstRound = widget.roundWindow.firstRound;
      _initialLastRound = widget.roundWindow.lastRound;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller!.hasClients) {
          _controller!
              .jumpTo(widget.roundWindow.initialScrollOffset(viewportWidth));
        }
      });
    }
    final contentSize = Size(
      widget.roundWindow.contentWidth(viewportWidth),
      widget.viewportSize.height,
    );
    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: SizedBox.fromSize(
        size: contentSize,
        child: widget.builder(context, contentSize),
      ),
    );
  }
}
