import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Thirteen round positions, with the middle seven visible on entry.
class RoundChartWindow {
  const RoundChartWindow._(this.firstRound);

  factory RoundChartWindow.endingAt(int latestRound) =>
      RoundChartWindow._(math.max(1, latestRound - 12));

  final int firstRound;

  int get lastRound => firstRound + 12;
  int get centerRound => firstRound + 6;
  int get firstVisibleRound => firstRound + 3;
  int get lastVisibleRound => firstRound + 9;

  bool contains(int round) => round >= firstRound && round <= lastRound;

  double fractionOf(num round) => (round - firstRound) / 12;

  double roundAt(double x, double width) =>
      firstRound + (x / width).clamp(0.0, 1.0) * 12;
}

class RoundChartViewport extends StatefulWidget {
  const RoundChartViewport({
    super.key,
    required this.viewportSize,
    required this.builder,
  });

  final Size viewportSize;
  final Widget Function(BuildContext context, Size contentSize) builder;

  @override
  State<RoundChartViewport> createState() => _RoundChartViewportState();
}

class _RoundChartViewportState extends State<RoundChartViewport> {
  ScrollController? _controller;
  double? _initialWidth;

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
      _controller = ScrollController(
        initialScrollOffset: viewportWidth / 2,
      );
    } else if (_initialWidth != viewportWidth) {
      _initialWidth = viewportWidth;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller!.hasClients) {
          _controller!.jumpTo(viewportWidth / 2);
        }
      });
    }
    final contentSize = Size(viewportWidth * 2, widget.viewportSize.height);
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
