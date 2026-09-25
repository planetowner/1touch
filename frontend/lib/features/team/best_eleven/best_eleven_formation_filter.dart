part of 'team_best_eleven_section.dart';

class _BestElevenFormationFilter extends StatelessWidget {
  const _BestElevenFormationFilter({
    required this.formations,
    required this.selectedFormation,
    required this.enabled,
    required this.appColors,
    required this.colors,
    required this.onChanged,
  });

  final List<BestElevenFormationOption> formations;
  final String? selectedFormation;
  final bool enabled;
  final AppColors appColors;
  final ColorScheme colors;
  final ValueChanged<String> onChanged;

  String _label(BestElevenFormationOption option) {
    final percentage = option.usagePercentage;
    if (percentage == null) return option.formation;
    final formatted = percentage == percentage.roundToDouble()
        ? percentage.toInt().toString()
        : percentage.toStringAsFixed(1);
    return '${option.formation} ($formatted%)';
  }

  @override
  Widget build(BuildContext context) {
    return AppDropdown<String>(
      key: const ValueKey('analysis-formation-filter'),
      value: selectedFormation,
      enabled: enabled,
      matchMenuWidth: true,
      backgroundColor: appColors.subtleBackground,
      foregroundColor: colors.onSurface,
      textStyle: Body2_b.style,
      options: formations
          .map(
            (option) => AppDropdownOption<String>(
              value: option.formation,
              label: _label(option).toUpperCase(),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
