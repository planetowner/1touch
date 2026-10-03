part of '../analysis.dart';

class _AnalysisFilterOption<T> {
  const _AnalysisFilterOption({
    required this.value,
    required this.seasonId,
    required this.seasonName,
    required this.teamId,
    required this.teamName,
  });

  final T value;
  final int seasonId;
  final String seasonName;
  final int teamId;
  final String teamName;
}

class _AnalysisComparisonFilterSheet<T> extends StatefulWidget {
  const _AnalysisComparisonFilterSheet({
    required this.options,
    required this.initialValue,
    required this.optionKey,
    this.seasonNames,
    this.initialSeasonName,
    this.loadSeasonOptions,
    this.onClearSelection,
  });

  final List<_AnalysisFilterOption<T>> options;
  final T? initialValue;
  final String Function(T value) optionKey;
  final List<String>? seasonNames;
  final String? initialSeasonName;
  final Future<List<_AnalysisFilterOption<T>>> Function(String seasonName)?
      loadSeasonOptions;
  final VoidCallback? onClearSelection;

  @override
  State<_AnalysisComparisonFilterSheet<T>> createState() =>
      _AnalysisComparisonFilterSheetState<T>();
}

class _AnalysisComparisonFilterSheetState<T>
    extends State<_AnalysisComparisonFilterSheet<T>> {
  final _search = TextEditingController();
  String? _seasonName;
  int? _teamId;
  bool _seasonExpanded = false;
  late List<_AnalysisFilterOption<T>> _options;
  bool _isLoading = false;
  bool _loadFailed = false;
  bool _clearRequested = false;
  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _options = widget.options;
    final initial = widget.options
        .where((option) => option.value == widget.initialValue)
        .firstOrNull;
    _seasonName = widget.initialSeasonName ??
        initial?.seasonName ??
        widget.seasonNames?.firstOrNull ??
        widget.options.firstOrNull?.seasonName;
    _teamId = initial?.teamId ??
        (widget.onClearSelection == null
            ? widget.options
                .where((option) => option.seasonName == _seasonName)
                .firstOrNull
                ?.teamId
            : null);
    _search.addListener(_refresh);
    if (widget.loadSeasonOptions != null && _seasonName != null) {
      unawaited(_loadSeason(_seasonName!));
    }
  }

  void _refresh() => setState(() {});

  void _selectSeason(String seasonName) {
    setState(() => _seasonExpanded = false);
    if (_seasonName == seasonName) return;
    setState(() {
      _seasonName = seasonName;
      _clearRequested = false;
      if (widget.loadSeasonOptions == null) _selectAvailableTeam();
    });
    if (widget.loadSeasonOptions != null) {
      unawaited(_loadSeason(seasonName));
    }
  }

  void _selectAvailableTeam() {
    final teams = _options.where((option) => option.seasonName == _seasonName);
    if (!teams.any((option) => option.teamId == _teamId)) {
      _teamId =
          widget.onClearSelection == null ? teams.firstOrNull?.teamId : null;
    }
  }

  Future<void> _loadSeason(String seasonName) async {
    final requestId = ++_loadRequestId;
    setState(() {
      _isLoading = true;
      _loadFailed = false;
      _options = [];
    });
    try {
      final options = await widget.loadSeasonOptions!(seasonName);
      // 시즌을 다시 선택하거나 창을 닫으면 이전 응답을 화면에 반영하지 않아요.
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _options = options;
        _isLoading = false;
        _selectAvailableTeam();
      });
    } on Object {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  @override
  void dispose() {
    _search.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppPalette.darkGrey : AppPalette.white;
    final fieldColor =
        isDark ? AppPalette.lightGrey : appColors.subtleBackground;
    final divider = isDark ? AppPalette.lightGrey : appColors.divider;
    final seasons = <String, String>{
      for (final name in widget.seasonNames ??
          widget.options.map((option) => option.seasonName))
        name: compactSeasonLabel(name),
    };
    final search = _search.text.trim().toLowerCase();
    final teams = _options
        .where((option) => option.seasonName == _seasonName)
        .where((option) =>
            search.isEmpty || option.teamName.toLowerCase().contains(search))
        .toList()
      ..sort((a, b) => a.teamName.compareTo(b.teamName));
    final selected = _options
        .where((option) =>
            option.seasonName == _seasonName && option.teamId == _teamId)
        .firstOrNull;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: .86,
        minChildSize: .5,
        maxChildSize: .94,
        builder: (context, controller) => Material(
          key: const ValueKey('analysis-comparison-filter-sheet'),
          color: background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: AppCloseHeader(
                  title: tr(context, 'Filter'),
                  closeKey: const ValueKey('analysis-filter-close'),
                  onClose: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  children: [
                    Text(tr(context, 'SEASON'), style: Body2_b.style),
                    const SizedBox(height: 16),
                    Material(
                      color: fieldColor,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        key: const ValueKey('analysis-filter-season'),
                        onTap: () =>
                            setState(() => _seasonExpanded = !_seasonExpanded),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(seasons[_seasonName] ?? '',
                                      style: Body2_b.style)),
                              Icon(
                                  _seasonExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: scheme.onSurface,
                                  size: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_seasonExpanded)
                      for (final season in seasons.entries)
                        ListTile(
                          key: ValueKey('analysis-filter-season-${season.key}'),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          title: Text(season.value, style: Body2.style),
                          trailing: _seasonName == season.key
                              ? Icon(Icons.check,
                                  color: scheme.onSurface, size: 20)
                              : null,
                          onTap: () => _selectSeason(season.key),
                        ),
                    const SizedBox(height: 24),
                    Text(tr(context, 'TEAM'), style: Body2_b.style),
                    const SizedBox(height: 16),
                    Container(
                      key:
                          const ValueKey('analysis-filter-team-search-surface'),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: fieldColor,
                        borderRadius:
                            BorderRadius.circular(AppSearchFieldTokens.radius),
                      ),
                      child: TextField(
                        key: const ValueKey('analysis-filter-team-search'),
                        controller: _search,
                        maxLines: 1,
                        style: Body1.style.copyWith(color: scheme.onSurface),
                        decoration: InputDecoration(
                          hintText: tr(context, 'Search a team!'),
                          hintStyle: Body1.style
                              .copyWith(color: appColors.mutedForeground),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          suffixIcon: Icon(Icons.search,
                              color: scheme.onSurface, size: 24),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(
                        child: SizedBox.square(
                          key: ValueKey('analysis-filter-loading'),
                          dimension: 40,
                          child: FootballLoadingIndicator(),
                        ),
                      )
                    else if (_loadFailed)
                      Row(
                        key: const ValueKey('analysis-filter-error'),
                        children: [
                          Expanded(
                              child: Text(tr(context, 'Unable to load team'))),
                          TextButton(
                            onPressed: () => _loadSeason(_seasonName!),
                            child: Text(tr(context, 'RETRY')),
                          ),
                        ],
                      )
                    else if (teams.isEmpty)
                      Text(tr(context, 'No teams found')),
                    for (final option in teams)
                      Column(
                        children: [
                          InkWell(
                            key: ValueKey(widget.optionKey(option.value)),
                            onTap: () {
                              setState(() {
                                if (widget.onClearSelection != null &&
                                    _teamId == option.teamId) {
                                  _teamId = null;
                                  _clearRequested = true;
                                } else {
                                  _teamId = option.teamId;
                                  _clearRequested = false;
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                      child: Text(option.teamName,
                                          style: Body1.style)),
                                  if (_teamId == option.teamId)
                                    Icon(Icons.check,
                                        color: scheme.onSurface, size: 24),
                                ],
                              ),
                            ),
                          ),
                          Divider(color: divider, height: 1),
                        ],
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  8,
                  24,
                  math.max(24, MediaQuery.paddingOf(context).bottom),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const ValueKey('analysis-filter-update'),
                    onPressed: selected != null
                        ? () => Navigator.pop<T>(context, selected.value)
                        : _clearRequested &&
                                widget.initialValue != null &&
                                !_isLoading &&
                                !_loadFailed
                            ? () {
                                Navigator.pop(context);
                                widget.onClearSelection!();
                              }
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.onSurface,
                      foregroundColor: background,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(tr(context, 'UPDATE FILTER'),
                        style: Body2_b.style.copyWith(color: background)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
