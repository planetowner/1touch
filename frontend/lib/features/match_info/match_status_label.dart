import 'dart:async';
import 'package:clock/clock.dart' as time;
import 'package:flutter/widgets.dart';
import 'package:onetouch/l10n/match_status_labels.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_clock.dart';

class MatchStatusLabel extends StatefulWidget {
  const MatchStatusLabel({super.key, required this.fixture, this.clock});

  final Fixture fixture;
  final FixtureClock? clock;

  @override
  State<MatchStatusLabel> createState() => _MatchStatusLabelState();
}

class _MatchStatusLabelState extends State<MatchStatusLabel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant MatchStatusLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clock != widget.clock ||
        oldWidget.fixture != widget.fixture) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (!fixtureHasPlayingClock(widget.fixture) ||
        !(widget.clock?.isRunningAt(time.clock.now()) ?? false)) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});
      if (!widget.clock!.isRunningAt(time.clock.now())) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
        matchStatusLabel(widget.fixture,
            clock: widget.clock,
            now: time.clock.now(),
            locale: Localizations.localeOf(context)),
        key: const ValueKey('match-status-label'),
        textAlign: TextAlign.center,
      );
}
