part of '../Analysis.dart';

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
  });

  final List<_AnalysisFilterOption<T>> options;
  final T? initialValue;
  final String Function(T value) optionKey;

  @override
  State<_AnalysisComparisonFilterSheet<T>> createState() =>
      _AnalysisComparisonFilterSheetState<T>();
}

class _AnalysisComparisonFilterSheetState<T>
    extends State<_AnalysisComparisonFilterSheet<T>> {
  final _search = TextEditingController();
  int? _seasonId;
  int? _teamId;
  bool _seasonExpanded = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.options
        .where((option) => option.value == widget.initialValue)
        .firstOrNull;
    _seasonId = initial?.seasonId ?? widget.options.firstOrNull?.seasonId;
    _teamId = initial?.teamId ??
        widget.options
            .where((option) => option.seasonId == _seasonId)
            .firstOrNull
            ?.teamId;
    _search.addListener(_refresh);
  }

  void _refresh() => setState(() {});

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
    final seasons = <int, String>{
      for (final option in widget.options)
        option.seasonId: compactSeasonLabel(option.seasonName),
    };
    final search = _search.text.trim().toLowerCase();
    final teams = widget.options
        .where((option) => option.seasonId == _seasonId)
        .where((option) =>
            search.isEmpty || option.teamName.toLowerCase().contains(search))
        .toList()
      ..sort((a, b) => a.teamName.compareTo(b.teamName));
    final selected = widget.options
        .where((option) =>
            option.seasonId == _seasonId && option.teamId == _teamId)
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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                        child:
                            Text(tr(context, 'Filter'), style: Heading5.style)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        key: const ValueKey('analysis-filter-close'),
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close,
                            color: scheme.onSurface, size: 24),
                      ),
                    ),
                  ],
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
                                  child: Text(seasons[_seasonId] ?? '',
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
                          trailing: _seasonId == season.key
                              ? Icon(Icons.check,
                                  color: scheme.onSurface, size: 20)
                              : null,
                          onTap: () => setState(() {
                            _seasonId = season.key;
                            _seasonExpanded = false;
                            if (!widget.options.any((option) =>
                                option.seasonId == _seasonId &&
                                option.teamId == _teamId)) {
                              _teamId = widget.options
                                  .where(
                                      (option) => option.seasonId == _seasonId)
                                  .firstOrNull
                                  ?.teamId;
                            }
                          }),
                        ),
                    const SizedBox(height: 24),
                    Text(tr(context, 'TEAM'), style: Body2_b.style),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: fieldColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        key: const ValueKey('analysis-filter-team-search'),
                        controller: _search,
                        style: Body1.style,
                        decoration: InputDecoration(
                          hintText: tr(context, 'Search a team!'),
                          hintStyle: Body1.style
                              .copyWith(color: appColors.mutedForeground),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          suffixIcon: Icon(Icons.search,
                              color: scheme.onSurface, size: 24),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final option in teams)
                      Column(
                        children: [
                          InkWell(
                            key: ValueKey(widget.optionKey(option.value)),
                            onTap: () =>
                                setState(() => _teamId = option.teamId),
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
                    onPressed: selected == null
                        ? null
                        : () => Navigator.pop<T>(context, selected.value),
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
