part of '../Analysis.dart';

class _AnalysisSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _AnalysisSectionHeader({
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final control = trailing;
    if (control == null) return Text(title, style: Body2_b.style);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Body2_b.style),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: control),
            ],
          );
        }

        return Row(
          children: [
            Text(title, style: Body2_b.style),
            const SizedBox(width: 12),
            const Spacer(),
            control,
          ],
        );
      },
    );
  }
}

String _compactSeasonLabel(String label) {
  final parts = label.split('/');
  if (parts.length != 2) return label.toUpperCase();

  String compact(String part) => part.length == 4 ? part.substring(2) : part;
  return '${compact(parts[0])}/${compact(parts[1])}'.toUpperCase();
}
