import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

// --- Models ---
class CalendarEvent1 {
  final String logoAsset;
  final Color dotColor;
  final String? time; // Added time for future use

  const CalendarEvent1({
    required this.logoAsset,
    required this.dotColor,
    this.time,
  });
}

class CalendarWidget extends StatefulWidget {
  final Map<DateTime, List<CalendarEvent1>> events;
  final void Function(DateTime date)? onDateSelected;

  const CalendarWidget({
    super.key,
    required this.events,
    this.onDateSelected,
  });

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  // PageController allows swiping between months
  late PageController _pageController;
  late DateTime _focusedMonth;

  // Base date for calculating page indices (starting from a reference point)
  final DateTime _baseDate = DateTime(2025, 1, 1);

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime.now();

    // Calculate initial page index based on difference from base date
    int initialPage = (_focusedMonth.year - _baseDate.year) * 12 +
        (_focusedMonth.month - _baseDate.month);
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    // Calculate new month based on index relative to base date
    final newMonth = DateTime(_baseDate.year, _baseDate.month + index);
    setState(() {
      _focusedMonth = newMonth;
    });
  }

  void _changeMonth(int increment) {
    _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Calendar Container
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(28),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header (Month Name + Arrows)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut
                      ),
                      icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                    ),
                    // Animated Switcher for smooth text transition
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        DateFormat('MMMM').format(_focusedMonth),
                        key: ValueKey(_focusedMonth),
                        style: Heading3.style,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut
                      ),
                      icon: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),

              // Calendar Grid (Swipeable)
              SizedBox(
                height: 400, // Fixed height for consistency
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final month = DateTime(_baseDate.year, _baseDate.month + index);
                    return _MonthView(
                      month: month,
                      events: widget.events,
                      onDateTap: widget.onDateSelected,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // 2. Legend (Kept from your original design)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildLegendItem("UCL", Colors.red),
              const SizedBox(width: 16),
              _buildLegendItem("CDR", Colors.blue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: Body2_b.style),
      ],
    );
  }
}

// --- Internal Component: Single Month Grid ---
class _MonthView extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, List<CalendarEvent1>> events;
  final Function(DateTime)? onDateTap;

  const _MonthView({
    required this.month,
    required this.events,
    this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;

    // Adjust weekday so Monday=0 ... Sunday=6 (Standard logic usually Mon=1)
    // Your previous code treated standard flutter weekday (Mon=1..Sun=7)
    // Here we align to a standard grid.
    final startOffset = (firstWeekday - 1) % 7;

    final totalCells = startOffset + daysInMonth;
    final weekCount = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth / 7;

          return Column(
            children: List.generate(weekCount, (weekIndex) {
              // Calculate logic for dividers
              final isFirstWeek = weekIndex == 0;
              final isLastWeek = weekIndex == weekCount - 1;

              // Calculate indents for the fancy divider lines
              double leftIndent = 12.0;
              double rightIndent = 12.0;

              if (isFirstWeek) {
                leftIndent = (startOffset * cellWidth) + 12.0;
              }

              if (isLastWeek) {
                final lastDayIndex = (totalCells - 1) % 7;
                // If the last day isn't the end of the row, cut the line short
                if (lastDayIndex < 6) {
                  rightIndent = ((6 - lastDayIndex) * cellWidth) + 12.0;
                }
              }

              return Column(
                children: [
                  // Top Divider (Only for the very first week)
                  if (isFirstWeek)
                    Container(
                      margin: EdgeInsets.only(left: leftIndent),
                      height: 1,
                      color: Colors.grey.shade600,
                    ),

                  // The Week Row
                  Row(
                    children: List.generate(7, (dayIndex) {
                      final globalIndex = (weekIndex * 7) + dayIndex;
                      final dayNumber = globalIndex - startOffset + 1;

                      if (dayNumber < 1 || dayNumber > daysInMonth) {
                        return Expanded(child: Container(height: 85)); // Empty placeholder
                      }

                      final currentDate = DateTime(month.year, month.month, dayNumber);
                      return Expanded(
                        child: _DayCell(
                          date: currentDate,
                          events: events[currentDate] ?? [],
                          onTap: () => onDateTap?.call(currentDate),
                        ),
                      );
                    }),
                  ),

                  // Bottom Divider (For all weeks)
                  Container(
                    margin: EdgeInsets.only(
                        left: isLastWeek ? 12.0 : (isFirstWeek ? 12.0 : 12.0), // Simplified logic or keep specific
                        right: isLastWeek ? rightIndent : 12.0
                    ),
                    height: 1,
                    color: Colors.grey.shade600,
                  ),
                ],
              );
            }),
          );
        },
      ),
    );
  }
}

// --- Internal Component: Day Cell ---
class _DayCell extends StatelessWidget {
  final DateTime date;
  final List<CalendarEvent1> events;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.events,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 85, // Fixed height per cell
        decoration: BoxDecoration(
          color: isToday ? Colors.black : Colors.transparent, // Highlight today
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${date.day}",
              style: Heading4.style.copyWith(
                color: isWeekend ? Colors.grey.shade500 : Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            // Event Indicator
            if (events.isNotEmpty)
              Stack(
                alignment: Alignment.center,
                children: [
                  // Logo
                  SizedBox(
                    height: 30,
                    width: 30,
                    child: Image.asset(
                      events.first.logoAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (c,o,s) => Icon(Icons.shield, color: events.first.dotColor, size: 20),
                    ),
                  ),
                  // Dot Badge
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: events.first.dotColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF2A2A2A), width: 1.5),
                      ),
                    ),
                  )
                ],
              )
            else
              const SizedBox(height: 30), // Spacer to keep grid even
          ],
        ),
      ),
    );
  }
}