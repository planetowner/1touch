part of 'standing_features.dart';

const double _standingTableHorizontalPadding = 16;

Widget _buildStandingRightFade(BuildContext context) {
  final colors = AppColors.of(context);

  LinearGradient fadeTo(Color color) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [color.withValues(alpha: 0), color],
      );

  return Positioned(
    key: const ValueKey('standing-right-fade'),
    top: 0,
    right: 0,
    bottom: 0,
    width: 16,
    child: IgnorePointer(
      child: Column(
        children: [
          Container(
            height: 59,
            decoration:
                BoxDecoration(gradient: fadeTo(colors.subtleBackground)),
          ),
          Expanded(
            child: Container(
              decoration:
                  BoxDecoration(gradient: fadeTo(colors.cardBackground)),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildHeaderCell(
  BuildContext context,
  String title, {
  bool isWide = false,
}) {
  return Container(
    width: isWide ? 100 : 24,
    alignment: Alignment.center,
    color: AppColors.of(context).subtleBackground,
    child: Text(tr(context, title), style: Body1.style),
  );
}

Widget _buildStatCell(
  BuildContext context,
  String text, {
  bool isWide = false,
  TextStyle? style,
}) {
  return Container(
    width: isWide ? 100 : 24,
    height: 20,
    alignment: Alignment.center,
    color: AppColors.of(context).cardBackground,
    child: Text(text, style: style ?? Body2.style),
  );
}
