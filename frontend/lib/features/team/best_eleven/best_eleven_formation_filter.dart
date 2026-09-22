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
    return Container(
      height: AppDropdownTokens.height,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      decoration: BoxDecoration(
        color: appColors.subtleBackground,
        borderRadius: BorderRadius.circular(AppDropdownTokens.radius),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const ValueKey('analysis-formation-filter'),
          value: selectedFormation,
          isDense: true,
          icon: AppDropdownChevron(color: colors.onSurface),
          dropdownColor: appColors.cardBackground,
          style: Body2_b.style.copyWith(color: colors.onSurface),
          onChanged: enabled
              ? (formation) {
                  if (formation != null) onChanged(formation);
                }
              : null,
          items: formations.map((option) {
            return DropdownMenuItem(
              value: option.formation,
              child: Text(
                _label(option).toUpperCase(),
                style: Body2_b.style.copyWith(color: colors.onSurface),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
