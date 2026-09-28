import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/core/api_client_provider.dart';
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
    required this.selectionName,
  });

  final FixtureBet bet;
  final String selectionName;

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
          final selectionName = _selectionName(bet.outcome, fixture);
          await _registry.remove(fixtureId);
          if (!_started || _disposed) break;
          notice = BetSettlementNotice(
            bet: bet,
            selectionName: selectionName,
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

  String _selectionName(BetOutcome outcome, Fixture? fixture) {
    if (outcome == BetOutcome.draw) return 'Draw';
    if (fixture == null) return 'Your prediction';
    final teamId =
        outcome == BetOutcome.homeWin ? fixture.homeTeamId : fixture.awayTeamId;
    final configured = teamRepository.findById(teamId)?.displayName.trim();
    if (configured?.isNotEmpty == true) return configured!;
    final shortName = outcome == BetOutcome.homeWin
        ? fixture.homeTeamShortName
        : fixture.awayTeamShortName;
    if (shortName?.trim().isNotEmpty == true) return shortName!.trim();
    final fullName = outcome == BetOutcome.homeWin
        ? fixture.homeTeamName
        : fixture.awayTeamName;
    return _conciseTeamName(fullName ?? 'Your prediction');
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
    final colors = AppColors.of(context);
    final foreground = Theme.of(context).colorScheme.onSurface;
    final bottomOffset = reserveBottomNavigation
        ? 68.0 + MediaQuery.paddingOf(context).bottom
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
                  color: colors.cardBackground,
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
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                key: const ValueKey(
                                    'bet-settlement-close-button'),
                                onPressed: onDismiss,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 24,
                                  height: 24,
                                ),
                                icon: Icon(Icons.close,
                                    size: 24, color: foreground),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Icon(
                              notice.won
                                  ? Icons.celebration_outlined
                                  : notice.refunded
                                      ? Icons.replay_circle_filled_outlined
                                      : Icons.sports_soccer_outlined,
                              size: 56,
                              color: foreground,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _title(context),
                              textAlign: TextAlign.center,
                              style: Heading4.style.copyWith(color: foreground),
                            ),
                            const SizedBox(height: 24),
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
                              key: const ValueKey('bet-settlement-see-results'),
                              label: tr(context, 'SEE RESULTS'),
                              background: AppPalette.white,
                              foreground: AppPalette.black,
                              onTap: onSeeResults,
                            ),
                            const SizedBox(height: 16),
                            _ResultButton(
                              key: const ValueKey('bet-settlement-maybe-later'),
                              label: tr(context, 'MAYBE LATER'),
                              background: AppPalette.lightGrey,
                              foreground: AppPalette.white,
                              onTap: onDismiss,
                            ),
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
      return tr(context, '{points} points returned', {
        'points': notice.bet.payout,
      });
    }
    return tr(context, 'You won {points} points!', {
      'points': notice.bet.payout,
    });
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
    final template = notice.refunded
        ? tr(context, 'Your bet on {team} was refunded.', {
            'team': notice.selectionName,
          })
        : notice.won
            ? tr(context, 'Your bet on {team} was correct.', {
                'team': notice.selectionName,
              })
            : tr(context, 'Your bet on {team} was not correct.', {
                'team': notice.selectionName,
              });
    final teamStart = template.indexOf(notice.selectionName);
    final regular = Body1.style.copyWith(color: foreground);
    if (teamStart < 0) {
      return Text(template, textAlign: TextAlign.center, style: regular);
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: template.substring(0, teamStart), style: regular),
          TextSpan(
            text: notice.selectionName,
            style: Body1_b.style.copyWith(color: foreground),
          ),
          TextSpan(
            text: template.substring(teamStart + notice.selectionName.length),
            style: regular,
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
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
                style: Body2_b.style.copyWith(color: foreground),
              ),
            ),
          ),
        ),
      );
}
