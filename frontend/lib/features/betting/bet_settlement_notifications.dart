import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/bottom_navigation.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/betting/bet_settlement_registry.dart';
import 'package:onetouch/data/betting/betting_repository.dart';
import 'package:onetouch/data/betting/betting_repository_provider.dart'
    as betting_provider;
import 'package:onetouch/data/fixtures/fixture_repository.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart'
    as fixture_provider;
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/betting.dart';
import 'package:onetouch/models/fixture.dart';

@immutable
class BetSettlementNotice {
  const BetSettlementNotice({
    required this.bet,
    required this.selectionTeamId,
    required this.selectionName,
    this.fixture,
  });

  final FixtureBet bet;
  final int? selectionTeamId;
  final String selectionName;
  final Fixture? fixture;

  bool get won => bet.status == 'won';
  bool get refunded => bet.status == 'refunded';
}

class BetSettlementNotificationController extends ChangeNotifier {
  BetSettlementNotificationController({
    BettingRepository? bettingRepository,
    FixtureRepository? fixtureRepository,
    BetSettlementRegistry? registry,
    this.pollInterval = const Duration(minutes: 1),
  })  : _bettingRepository =
            bettingRepository ?? betting_provider.bettingRepository,
        _fixtureRepository =
            fixtureRepository ?? fixture_provider.fixtureDetailRepository,
        _registry = registry ?? betSettlementRegistry;

  final BettingRepository _bettingRepository;
  final FixtureRepository _fixtureRepository;
  final BetSettlementRegistry _registry;
  final Duration pollInterval;

  Timer? _timer;
  bool _started = false;
  bool _checking = false;
  bool _disposed = false;
  BetSettlementNotice? notice;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _registry.addListener(_registryChanged);
    try {
      await _registry.initialize();
    } on Object {
      // The next track operation or app launch can retry local initialization.
    }
    if (!_started || _disposed) return;
    _timer = Timer.periodic(pollInterval, (_) => refresh());
    await refresh();
  }

  void stop({bool clearNotice = true}) {
    if (_started) _registry.removeListener(_registryChanged);
    _started = false;
    _timer?.cancel();
    _timer = null;
    if (clearNotice && notice != null) {
      notice = null;
      if (!_disposed) notifyListeners();
    }
  }

  void _registryChanged() => refresh();

  Future<void> refresh() async {
    if (!_started || _checking || notice != null || _disposed) return;
    _checking = true;
    try {
      final fixtureIds = _registry.pendingFixtureIds.toList()..sort();
      for (final fixtureId in fixtureIds) {
        if (!_started || notice != null || _disposed) break;
        try {
          final market = await _bettingRepository.loadMarket(fixtureId);
          final bet = market.bet;
          if (bet == null || bet.status == 'cancelled') {
            await _registry.remove(fixtureId);
            continue;
          }
          if (bet.isOpen) continue;
          if (!const {'won', 'lost', 'refunded'}.contains(bet.status)) {
            continue;
          }

          Fixture? fixture = _fixtureRepository.findById(fixtureId);
          try {
            fixture = (await _fixtureRepository.loadDetail(fixtureId)).fixture;
          } on Object {
            // Cached fixture names still let the result remain useful offline.
          }
          final selection = _settlementSelection(bet.outcome, fixture);
          await _registry.remove(fixtureId);
          if (!_started || _disposed) break;
          notice = BetSettlementNotice(
            bet: bet,
            selectionTeamId: selection.teamId,
            selectionName: selection.name,
            fixture: fixture,
          );
          notifyListeners();
        } on Object {
          // Keep the fixture pending so a temporary API error is retried.
        }
      }
    } finally {
      _checking = false;
    }
  }

  void dismiss() {
    if (notice == null) return;
    notice = null;
    notifyListeners();
    scheduleMicrotask(refresh);
  }

  @override
  void dispose() {
    _disposed = true;
    stop(clearNotice: false);
    super.dispose();
  }
}

({int? teamId, String name}) _settlementSelection(
    BetOutcome outcome, Fixture? fixture) {
  if (outcome == BetOutcome.draw) return (teamId: null, name: 'Draw');
  if (fixture == null) return (teamId: null, name: 'Your prediction');
  final teamId =
      outcome == BetOutcome.homeWin ? fixture.homeTeamId : fixture.awayTeamId;
  final configured = teamRepository.findById(teamId)?.displayName.trim();
  if (configured?.isNotEmpty == true) {
    return (teamId: teamId, name: configured!);
  }
  final shortName = outcome == BetOutcome.homeWin
      ? fixture.homeTeamShortName
      : fixture.awayTeamShortName;
  if (shortName?.trim().isNotEmpty == true) {
    return (teamId: teamId, name: shortName!.trim());
  }
  final fullName = outcome == BetOutcome.homeWin
      ? fixture.homeTeamName
      : fixture.awayTeamName;
  return (
    teamId: teamId,
    name: _conciseTeamName(fullName ?? 'Your prediction'),
  );
}

String _conciseTeamName(String value) {
  final name = value.trim();
  return name.replaceFirst(RegExp(r'^(?:AFC|FC)\s+', caseSensitive: false), '');
}

class BetSettlementNotificationHost extends StatefulWidget {
  const BetSettlementNotificationHost({
    super.key,
    required this.child,
    required this.onSeeResults,
    required this.reserveBottomNavigation,
    this.controller,
  });

  final Widget child;
  final ValueChanged<int> onSeeResults;
  final bool reserveBottomNavigation;
  final BetSettlementNotificationController? controller;

  @override
  State<BetSettlementNotificationHost> createState() =>
      _BetSettlementNotificationHostState();
}

class _BetSettlementNotificationHostState
    extends State<BetSettlementNotificationHost> with WidgetsBindingObserver {
  late final BetSettlementNotificationController _controller =
      widget.controller ?? BetSettlementNotificationController();
  late final bool _ownsController = widget.controller == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    authSession.addListener(_syncAuthentication);
    _syncAuthentication();
  }

  void _syncAuthentication() {
    if (authSession.isAuthenticated) {
      _controller.start();
    } else {
      _controller.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && authSession.isAuthenticated) {
      _controller.refresh();
    }
  }

  @override
  void dispose() {
    authSession.removeListener(_syncAuthentication);
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final notice = _controller.notice;
          return Stack(
            fit: StackFit.expand,
            children: [
              child!,
              if (notice != null)
                BetSettlementResultOverlay(
                  notice: notice,
                  reserveBottomNavigation: widget.reserveBottomNavigation,
                  onDismiss: _controller.dismiss,
                  onSeeResults: () {
                    final fixtureId = notice.bet.fixtureId;
                    _controller.dismiss();
                    widget.onSeeResults(fixtureId);
                  },
                ),
            ],
          );
        },
      );
}

class BetSettlementResultOverlay extends StatelessWidget {
  const BetSettlementResultOverlay({
    super.key,
    required this.notice,
    required this.onDismiss,
    required this.onSeeResults,
    this.reserveBottomNavigation = true,
  });

  final BetSettlementNotice notice;
  final VoidCallback onDismiss;
  final VoidCallback onSeeResults;
  final bool reserveBottomNavigation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? AppPalette.white : const Color(0xFF090A0A);
    final sheetColor = isDark ? const Color(0xFF272828) : AppPalette.white;
    final bottomOffset = reserveBottomNavigation
        ? OneTouchBottomNavigationBar.heightOf(context)
        : 0.0;

    return Material(
      key: const ValueKey('bet-settlement-result-overlay'),
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            key: const ValueKey('bet-settlement-dismiss-area'),
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: const SizedBox.expand(),
          ),
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            bottom: bottomOffset,
            child: IgnorePointer(
              child: ColoredBox(
                color: AppPalette.black.withValues(alpha: 0.50),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomOffset,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Container(
                key: const ValueKey('bet-settlement-sheet'),
                decoration: BoxDecoration(
                  color: sheetColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  bottom: !reserveBottomNavigation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              notice.won
                                  ? Icons.celebration_outlined
                                  : notice.refunded
                                      ? Icons.undo
                                      : Icons.sports_soccer_outlined,
                              size: 56,
                              color: foreground,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _title(context),
                              textAlign: TextAlign.center,
                              style: Heading4.style.copyWith(color: foreground),
                            ),
                            const SizedBox(height: 8),
                            _ResultDescription(
                              notice: notice,
                              foreground: foreground,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                        child: Column(
                          children: [
                            _ResultButton(
                              key: ValueKey(notice.refunded
                                  ? 'bet-settlement-continue'
                                  : 'bet-settlement-see-results'),
                              label: tr(context,
                                  notice.refunded ? 'CONTINUE' : 'SEE RESULTS'),
                              background: isDark
                                  ? AppPalette.white
                                  : const Color(0xFF090A0A),
                              foreground: isDark
                                  ? const Color(0xFF090A0A)
                                  : AppPalette.white,
                              onTap: notice.refunded ? onDismiss : onSeeResults,
                            ),
                            if (!notice.refunded) ...[
                              const SizedBox(height: 16),
                              _ResultButton(
                                key: const ValueKey(
                                    'bet-settlement-maybe-later'),
                                label: tr(context, 'MAYBE LATER'),
                                background: isDark
                                    ? AppPalette.lightGrey
                                    : AppPalette.lightModeDarkGrey,
                                foreground: foreground,
                                onTap: onDismiss,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _title(BuildContext context) {
    if (notice.refunded) {
      return tr(context, 'Your {points} points\nhave been returned', {
        'points': notice.bet.payout,
      });
    }
    if (notice.won) {
      return tr(context, 'You won {points} points!', {
        'points': notice.bet.payout,
      });
    }
    return tr(context, 'No points this time.');
  }
}

class _ResultDescription extends StatelessWidget {
  const _ResultDescription({
    required this.notice,
    required this.foreground,
  });

  final BetSettlementNotice notice;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final selectionName = notice.bet.outcome == BetOutcome.draw
        ? tr(context, 'Draw')
        : teamNameLabel(context, notice.selectionTeamId, notice.selectionName,
            short: true);
    var message = notice.refunded
        ? 'Your bet on {team} was refunded.'
        : notice.won
            ? 'Your bet on {team} was correct.'
            : 'Your bet on {team} was not correct.';
    var teams = {'team': selectionName};
    final fixture = notice.fixture;
    // 경기의 현재 상태가 바뀌어도 환불 당시 서버가 기록한 사유를 안내해요.
    final refundMessage = switch (notice.bet.settlementReason) {
      'CANCELLED' => '{home_team} vs {away_team} was cancelled.',
      'POSTPONED' => '{home_team} vs {away_team} was postponed.',
      'WO' => '{home_team} vs {away_team} was decided by walkover.',
      'ABANDONED' => '{home_team} vs {away_team} was abandoned.',
      'AWARDED' =>
        '{home_team} vs {away_team}: the result was decided by the organizer.',
      'DELETED' =>
        '{home_team} vs {away_team}: the match record was deleted or changed.',
      _ => null,
    };
    if (notice.refunded && fixture != null && refundMessage != null) {
      message = refundMessage;
      teams = {
        for (final entry in {
          'home_team': BetOutcome.homeWin,
          'away_team': BetOutcome.awayWin,
        }.entries)
          entry.key: _teamLabel(context, entry.value, fixture),
      };
    }
    final template = tr(context, message);
    final lineHeight =
        Localizations.localeOf(context).languageCode == 'ko' ? 1.60 : 1.30;
    final regular = Body1.style.copyWith(
      color: foreground,
      height: lineHeight,
    );
    final bold = Body1_b.style.copyWith(
      color: foreground,
      height: lineHeight,
    );
    final spans = <TextSpan>[];
    var offset = 0;
    // 이름 자체를 검색하지 않아 두 팀의 이름이 겹쳐도 각각 강조해요.
    for (final match in RegExp(r'\{(\w+)\}').allMatches(template)) {
      spans.add(TextSpan(text: template.substring(offset, match.start)));
      spans.add(TextSpan(text: teams[match[1]], style: bold));
      offset = match.end;
    }
    spans.add(TextSpan(text: template.substring(offset)));
    return Text.rich(
      TextSpan(style: regular, children: spans),
      textAlign: TextAlign.center,
    );
  }

  String _teamLabel(BuildContext context, BetOutcome side, Fixture fixture) {
    final team = _settlementSelection(side, fixture);
    return teamNameLabel(context, team.teamId, team.name, short: true);
  }
}

class _ResultButton extends StatelessWidget {
  const _ResultButton({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Body2_b.style.copyWith(
                  color: foreground,
                  height: Localizations.localeOf(context).languageCode == 'ko'
                      ? 1.60
                      : 1.30,
                ),
              ),
            ),
          ),
        ),
      );
}
