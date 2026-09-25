part of 'team_screen_features.dart';

class Transfer extends StatefulWidget {
  const Transfer({
    super.key,
    this.teams,
    this.repository,
    this.onUnavailable,
  });

  final teams;
  final TransferRepository? repository;
  final VoidCallback? onUnavailable;

  @override
  State<Transfer> createState() => _TransferState();
}

class _TransferState extends State<Transfer> {
  bool showIn = true; // true = IN, false = OUT
  TeamTransferWindow? _window;
  bool _isLoading = false;
  bool _loadFailed = false;
  bool _isUnavailable = false;
  int _loadRequestId = 0;

  TransferRepository get _repository => widget.repository ?? transferRepository;

  int? get _teamId {
    if (widget.teams is Map<String, dynamic>) {
      return (widget.teams as Map<String, dynamic>)['id'] as int?;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(Transfer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldTeamId = oldWidget.teams is Map<String, dynamic>
        ? (oldWidget.teams as Map<String, dynamic>)['id'] as int?
        : null;
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

  Future<void> _loadTransfers(int teamId, int requestId) async {
    try {
      final window = await _repository.loadForTeam(teamId);
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _window = window;
        _isLoading = false;
      });
    } on TeamFeatureUnavailableException {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _isUnavailable = true;
      });
      widget.onUnavailable?.call();
    } on Object {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
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
    final list = showIn ? incoming : outgoing;

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
            value: showIn,
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
            onChanged: (value) => setState(() => showIn = value),
          ),
        ),

        // PLAYER LIST
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox.square(
                key: ValueKey('transfer-loading'),
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
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
                    onPressed: _retryLoad, child: Text(tr(context, 'RETRY'))),
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
