part of 'home_screen_features.dart';

enum _CalendarSyncOutcome {
  googleConnected,
  appleOpened,
  stopped,
  disconnected
}

class SyncDialog extends StatefulWidget {
  const SyncDialog(
      {super.key, required this.teamId, required this.teamName, this.service});

  final int teamId;
  final String teamName;
  final CalendarSyncService? service;

  static Future<void> show(BuildContext context,
          {required int teamId, required String teamName}) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SyncDialog(teamId: teamId, teamName: teamName),
      );

  @override
  State<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<SyncDialog> {
  late final _service = widget.service ?? CalendarSyncService(api: apiClient);
  bool _busy = false;
  String? _error;
  _CalendarSyncOutcome? _outcome;
  Future<void> Function()? _retry;

  Future<void> _sync() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _run(() => _service.subscribeApple(widget.teamId),
          _CalendarSyncOutcome.appleOpened);
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _run(() => _service.syncGoogle(widget.teamId),
          _CalendarSyncOutcome.googleConnected);
    } else {
      setState(
          () => _error = 'Calendar sync is available on iPhone and Android.');
    }
  }

  Future<void> _run(
      Future<void> Function() action, _CalendarSyncOutcome outcome) async {
    // 해제 요청이 실패했을 때 재시도로 구독을 다시 켜지 않아요.
    _retry = () => _run(action, outcome);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) setState(() => _outcome = outcome);
    } on GoogleSignInException catch (error) {
      if (mounted) {
        setState(() => _error = error.code == GoogleSignInExceptionCode.canceled
            ? 'Calendar connection cancelled.'
            : 'Could not connect to Google. Please try again.');
      }
    } on CalendarSyncException catch (error) {
      if (mounted) {
        setState(() => _error = switch (error.code) {
              'calendar_account_mismatch' =>
                'Choose the Google account already connected to 1touch.',
              'calendar_permission_required' =>
                'Allow 1touch to manage its calendar, then try again.',
              'calendar_reconnect_required' =>
                'Google calendar access expired. Please connect again.',
              'calendar_missing' =>
                'The 1touch calendar was removed. Connect again to create it.',
              'calendar_feed_unavailable' =>
                'Could not load the calendar subscription. Please try again.',
              'calendar_open_failed' =>
                'Could not open Calendar. Please try again on your iPhone.',
              _ => 'Calendar sync could not finish. Please try again.',
            });
      }
    } on Object {
      if (mounted) {
        setState(
            () => _error = 'Calendar sync could not finish. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(tr(context, 'Disconnect Google Calendar?')),
              content: Text(tr(context,
                  'Automatic updates for all teams will stop. Saved events will remain in Google Calendar.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(trUpper(context, 'Cancel'))),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(tr(context, 'Disconnect'))),
              ],
            ));
    if (confirmed == true && mounted) {
      await _run(_service.disconnectGoogle, _CalendarSyncOutcome.disconnected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final connected = _outcome == _CalendarSyncOutcome.googleConnected;
    final message = switch (_outcome) {
      _CalendarSyncOutcome.googleConnected =>
        'Connected to the 1touch calendar in Google. Match changes will update even when this app is closed.',
      _CalendarSyncOutcome.appleOpened =>
        'Finish subscribing in Calendar and enable event alerts. Apple controls when subscription changes appear.',
      _CalendarSyncOutcome.stopped =>
        'Automatic sync for this team has stopped. Upcoming events shared with another synced team will remain.',
      _CalendarSyncOutcome.disconnected =>
        'Google Calendar disconnected. Automatic updates have stopped.',
      null =>
        'Sync all upcoming matches for {team}. Each event lasts 2 hours, with a reminder 30 minutes before kickoff.',
    };

    return PopScope(
      canPop: !_busy,
      child: Dialog(
        backgroundColor: AppColors.of(context).cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(context, 'Sync with your calendar?'),
                    style: Heading5.style),
                const SizedBox(height: 16),
                Text(tr(context, message, {'team': widget.teamName}),
                    style: Body1.style),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(tr(context, _error!),
                      style: Body2.style.copyWith(color: colors.error)),
                ],
                const SizedBox(height: 32),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy
                          ? null
                          : _error != null
                              ? (_retry ?? _sync)
                              : _outcome == null
                                  ? _sync
                                  : () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.onSurface,
                        foregroundColor: colors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(
                              tr(
                                  context,
                                  _error != null
                                      ? 'Retry'
                                      : _outcome == null
                                          ? 'YES, SYNC IT!'
                                          : 'Done'),
                              style: Body2_b.style),
                    )),
                if (connected) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => _service.stopGoogle(widget.teamId),
                            _CalendarSyncOutcome.stopped),
                    child: Text(tr(context, 'Stop syncing this team')),
                  ),
                  Text(
                      tr(context,
                          'Upcoming events for this team will be removed from the 1touch calendar.'),
                      style: Body2.style),
                  TextButton(
                      onPressed: _busy ? null : _disconnect,
                      child: Text(tr(context, 'Disconnect Google Calendar'))),
                ],
                if (_outcome == null || _error != null) ...[
                  const SizedBox(height: 16),
                  Center(
                      child: TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child:
                        Text(trUpper(context, 'Cancel'), style: Body2_b.style),
                  )),
                ],
              ]),
        ),
      ),
    );
  }
}
