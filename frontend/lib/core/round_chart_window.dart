import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    this.selectedRound,
    this.onPointerMove,
  });

  final RoundChartWindow roundWindow;
  final Size viewportSize;
  final Widget Function(BuildContext context, Size contentSize) builder;
  final int? selectedRound;
  final ValueChanged<double>? onPointerMove;

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
    final plotSize = Size(
      contentSize.width,
      contentSize.height - RoundChartSelectionHandle.height,
    );
    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: SizedBox.fromSize(
        size: contentSize,
        child: Stack(
          children: [
            Positioned.fill(
              bottom: RoundChartSelectionHandle.height,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerMove: widget.onPointerMove == null
                    ? null
                    : (event) {
                        if (event.delta.dx.abs() >= event.delta.dy.abs()) {
                          widget.onPointerMove!(event.localPosition.dx);
                        }
                      },
                child: widget.builder(context, plotSize),
              ),
            ),
            if (widget.selectedRound != null)
              RoundChartSelectionHandle(
                x: contentSize.width *
                    widget.roundWindow.fractionOf(widget.selectedRound!),
                color: Theme.of(context).colorScheme.onSurface,
              ),
          ],
        ),
      ),
    );
  }
}

class RoundChartSelectionHandle extends StatelessWidget {
  const RoundChartSelectionHandle({
    super.key,
    required this.x,
    required this.color,
  });

  static const double width = 11;
  static const double height = 16;
  static const double tipInset = 5.333;

  final double x;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x - tipInset,
      bottom: 0,
      width: width,
      height: height,
      child: IgnorePointer(
        child: SvgPicture.asset(
          'assets/round_chart_selection_handle.svg',
          key: const ValueKey('round-chart-selection-handle'),
          width: width,
          height: height,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ),
    );
  }
}
