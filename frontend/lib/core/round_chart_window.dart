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

  /// Adds three empty round slots at either end so any round can be centered.
  factory RoundChartWindow.centeredThrough(int latestRound) =>
      RoundChartWindow._(-2, math.max(7, latestRound) + 3);

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

  double centeredScrollOffset(int round, double viewportWidth) =>
      (contentWidth(viewportWidth) * fractionOf(round) - viewportWidth / 2)
          .clamp(0.0, contentWidth(viewportWidth) - viewportWidth);

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
    required this.selectedRound,
    required this.selectableRounds,
    required this.onRoundChanged,
  });

  final RoundChartWindow roundWindow;
  final Size viewportSize;
  final Widget Function(BuildContext context, Size contentSize) builder;
  final int? selectedRound;
  final List<int> selectableRounds;
  final ValueChanged<int> onRoundChanged;

  @override
  State<RoundChartViewport> createState() => _RoundChartViewportState();
}

class _RoundChartViewportState extends State<RoundChartViewport> {
  ScrollController? _controller;
  double? _initialWidth;
  int? _initialFirstRound;
  int? _initialLastRound;
  int? _centeredRound;
  double? _dragStartX;
  int? _dragStartRound;

  void _moveHandle(double globalX) {
    if (_dragStartX == null ||
        _dragStartRound == null ||
        widget.selectableRounds.isEmpty) {
      return;
    }
    final rounds = widget.selectableRounds;
    final draggedRound = (_dragStartRound! +
            (globalX - _dragStartX!) / (widget.viewportSize.width / 6))
        .clamp(rounds.first.toDouble(), rounds.last.toDouble());
    var nearest = rounds.first;
    for (final round in rounds.skip(1)) {
      if ((round - draggedRound).abs() < (nearest - draggedRound).abs()) {
        nearest = round;
      }
    }
    if (nearest != widget.selectedRound) {
      widget.onRoundChanged(nearest);
    }
  }

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
      _centeredRound = widget.selectedRound;
      _controller = ScrollController(
        initialScrollOffset: widget.selectedRound == null
            ? 0
            : widget.roundWindow
                .centeredScrollOffset(widget.selectedRound!, viewportWidth),
      );
    } else if (_initialWidth != viewportWidth ||
        _initialFirstRound != widget.roundWindow.firstRound ||
        _initialLastRound != widget.roundWindow.lastRound ||
        _centeredRound != widget.selectedRound) {
      _initialWidth = viewportWidth;
      _initialFirstRound = widget.roundWindow.firstRound;
      _initialLastRound = widget.roundWindow.lastRound;
      _centeredRound = widget.selectedRound;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller!.hasClients) {
          _controller!.jumpTo(
            widget.selectedRound == null
                ? 0
                : widget.roundWindow
                    .centeredScrollOffset(widget.selectedRound!, viewportWidth),
          );
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
      physics: const NeverScrollableScrollPhysics(),
      child: SizedBox.fromSize(
        size: contentSize,
        child: Stack(
          children: [
            Positioned.fill(
              bottom: RoundChartSelectionHandle.height,
              child: widget.builder(context, plotSize),
            ),
            if (widget.selectedRound != null)
              RoundChartSelectionHandle(
                x: contentSize.width *
                    widget.roundWindow.fractionOf(widget.selectedRound!),
                color: Theme.of(context).colorScheme.onSurface,
                onDragDown: (globalX) {
                  _dragStartX = globalX;
                  _dragStartRound = widget.selectedRound;
                },
                onDrag: _moveHandle,
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
    this.onDragDown,
    this.onDrag,
  });

  static const double width = 11;
  static const double height = 16;
  static const double tipInset = 5.333;

  final double x;
  final Color color;
  final ValueChanged<double>? onDragDown;
  final ValueChanged<double>? onDrag;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x - (onDrag == null ? tipInset : 22),
      bottom: 0,
      width: onDrag == null ? width : 44,
      height: onDrag == null ? height : 44,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragDown: onDrag == null
            ? null
            : (details) => onDragDown?.call(details.globalPosition.dx),
        onHorizontalDragStart: onDrag == null
            ? null
            : (details) => onDrag!(details.globalPosition.dx),
        onHorizontalDragUpdate: onDrag == null
            ? null
            : (details) => onDrag!(details.globalPosition.dx),
        child: Stack(
          children: [
            Positioned(
              left: onDrag == null ? 0 : 22 - tipInset,
              bottom: 0,
              width: width,
              height: height,
              child: SvgPicture.asset(
                'assets/round_chart_selection_handle.svg',
                key: const ValueKey('round-chart-selection-handle'),
                width: width,
                height: height,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
