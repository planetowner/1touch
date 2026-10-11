part of 'team_screen_features.dart';

class Transfer extends StatefulWidget {
  const Transfer({
    super.key,
    this.teams,
    this.repository,
    this.onAvailabilityChanged,
    this.showIncoming,
    this.onDirectionChanged,
  });

  final TeamOverview? teams;
  final TransferRepository? repository;
  final ValueChanged<bool>? onAvailabilityChanged;
  final bool? showIncoming;
  final ValueChanged<bool>? onDirectionChanged;

  @override
  State<Transfer> createState() => _TransferState();
}

class _TransferState extends State<Transfer>
    with PageRefreshParticipant<Transfer> {
  @override
  Future<void> refreshPage() async {
    final teamId = _teamId;
    if (teamId == null) return;
    await _loadTransfers(teamId, ++_loadRequestId, forceRefresh: true);
  }

  bool showIn = true; // true = IN, false = OUT
  TeamTransferWindow? _window;
  bool _isLoading = false;
  bool _loadFailed = false;
  bool _isUnavailable = false;
  int _loadRequestId = 0;

  TransferRepository get _repository => widget.repository ?? transferRepository;
  bool get _showIn => widget.showIncoming ?? showIn;

  void _changeDirection(bool value) {
    if (widget.showIncoming == null) {
      setState(() => showIn = value);
    }
    widget.onDirectionChanged?.call(value);
  }

  int? get _teamId => widget.teams?.id;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(Transfer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldTeamId = oldWidget.teams?.id;
    if (_teamId != oldTeamId || widget.repository != oldWidget.repository) {
      _startLoad();
    }
  }

  void _startLoad() {
    final teamId = _teamId;
    final requestId = ++_loadRequestId;
    final cached = teamId == null ? null : _repository.cachedForTeam(teamId);

    _window = cached;
    _isLoading = teamId != null && cached == null;
    _loadFailed = false;
    _isUnavailable = false;

    if (_isLoading) {
      unawaited(_loadTransfers(teamId!, requestId));
    }
  }

  Future<void> _loadTransfers(int teamId, int requestId,
      {bool forceRefresh = false}) async {
    try {
      final window =
          await _repository.loadForTeam(teamId, forceRefresh: forceRefresh);
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _window = window;
        _isLoading = false;
        _loadFailed = false;
        _isUnavailable = false;
      });
      widget.onAvailabilityChanged?.call(true);
    } on TeamFeatureUnavailableException {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _isUnavailable = true;
      });
      widget.onAvailabilityChanged?.call(false);
    } on Object {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _loadFailed = _window == null;
      });
    }
  }

  void _retryLoad() => setState(_startLoad);

  @override
  Widget build(BuildContext context) {
    if (_isUnavailable) {
      return const SizedBox.shrink(
        key: ValueKey('transfer-unavailable'),
      );
    }
    final incoming = _window?.incoming ?? const <TransferEntry>[];
    final outgoing = _window?.outgoing ?? const <TransferEntry>[];
    final list = _showIn ? incoming : outgoing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TRANSFER SWITCH BUTTON
        Padding(
          padding:
              const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 16),
          child: AppSegmentedToggle<bool>(
            containerKey: const ValueKey('transfer-toggle'),
            indicatorSurfaceKey: const ValueKey('transfer-toggle-indicator'),
            value: _showIn,
            options: [
              AppSegmentedToggleOption(
                value: true,
                label: tr(context, 'IN'),
                contentKey: const ValueKey('transfer-in-toggle'),
              ),
              AppSegmentedToggleOption(
                value: false,
                label: tr(context, 'OUT'),
                contentKey: const ValueKey('transfer-out-toggle'),
              ),
            ],
            onChanged: _changeDirection,
          ),
        ),

        // PLAYER LIST
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox.square(
                key: ValueKey('transfer-loading'),
                dimension: 56,
                child: FootballLoadingIndicator(),
              ),
            ),
          )
        else if (_loadFailed)
          Padding(
            key: const ValueKey('transfer-error'),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(tr(context, 'Unable to load transfers'),
                      style: Body2.style),
                ),
                TextButton(
                    onPressed: _retryLoad,
                    child: Text(trUpper(context, 'Retry'))),
              ],
            ),
          )
        else if (list.isEmpty)
          Padding(
            key: const ValueKey('transfer-empty'),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(tr(context, 'No transfers'), style: Body2.style),
          )
        else
          ...list.map((transfer) => TransferTile(transfer: transfer)),

        const SizedBox(height: 8),
      ],
    );
  }
}
