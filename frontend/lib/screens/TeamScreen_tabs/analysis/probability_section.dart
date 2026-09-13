part of '../Analysis.dart';

class ProbabilitySection extends StatelessWidget {
  const ProbabilitySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("PROBABILITY", style: Body2_b.style),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _probabilityBox(
                  context,
                  title: "Chances to win\nUCL Trophy",
                  value: 16,
                  delta: 3,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _probabilityBox(
                  context,
                  title: "Chances to win\nLEAGUE Trophy",
                  value: 32,
                  delta: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _probabilityBox(
    BuildContext context, {
    required String title,
    required int value,
    required int delta,
  }) {
    final bool isUp = delta >= 0;
    final IconData arrow = isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down;
    final Color arrowColor = isUp ? Colors.blueAccent : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.of(context).subtleBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Body1.style),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$value', style: Heading1.style),
                      Text('%', style: Heading4.style),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    children: [
                      Icon(arrow, color: arrowColor, size: 24),
                      Text('$delta', style: Heading5.style),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
