import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The latest round starts at the center; the chart stops at round one.
class RoundChartWindow {
  const RoundChartWindow._(this.firstRound, this.lastRound);

  static const int visibleIntervalCount = 14;
  static const int centerIntervalCount = visibleIntervalCount ~/ 2;

  factory RoundChartWindow.endingAt(int latestRound) {
    final lastCompletedRound = math.max(1, latestRound);
    return RoundChartWindow._(
      math.max(1, lastCompletedRound - 12),
      math.max(7, lastCompletedRound),
    );
  }

  /// Leaves future slots to center the latest round without scrolling past one.
  factory RoundChartWindow.centeredThrough(int latestRound) =>
      RoundChartWindow._(
        0,
        math.max(visibleIntervalCount,
            math.max(1, latestRound) + centerIntervalCount),
      );

  final int firstRound;
  final int lastRound;

  int get firstVisibleRound =>
      math.max(firstRound, lastRound - visibleIntervalCount);
  int get lastVisibleRound => lastRound;
  int get centerRound => firstVisibleRound + centerIntervalCount;
  int get intervalCount => lastRound - firstRound;

  double contentWidth(double viewportWidth) =>
      viewportWidth * intervalCount / visibleIntervalCount;

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
            (globalX - _dragStartX!) /
                (widget.viewportSize.width /
                    RoundChartWindow.visibleIntervalCount))
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
      final geometryChanged = _initialWidth != viewportWidth ||
          _initialFirstRound != widget.roundWindow.firstRound ||
          _initialLastRound != widget.roundWindow.lastRound;
      _initialWidth = viewportWidth;
      _initialFirstRound = widget.roundWindow.firstRound;
      _initialLastRound = widget.roundWindow.lastRound;
      _centeredRound = widget.selectedRound;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller!.hasClients) {
          final target = widget.selectedRound == null
              ? 0.0
              : widget.roundWindow
                  .centeredScrollOffset(widget.selectedRound!, viewportWidth);
          if (geometryChanged) {
            _controller!.jumpTo(target);
          } else {
            unawaited(_controller!.animateTo(
              target,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
            ));
          }
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
    return AnimatedPositioned(
      left: x - (onDrag == null ? tipInset : 22),
      bottom: 0,
      width: onDrag == null ? width : 44,
      height: onDrag == null ? height : 44,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
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
