part of 'standing_features.dart';

const double _standingTableHorizontalPadding = 16;
const double _standingStatCellWidth = 24;
const double _standingLastFiveWidth = 100;

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
  Key? key,
}) {
  return SizedBox(
    key: key,
    width: isWide ? _standingLastFiveWidth : _standingStatCellWidth,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Text(
        tr(context, title),
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        style: Body1.style,
      ),
    ),
  );
}

Widget _buildStatCell(
  BuildContext context,
  String text, {
  bool isWide = false,
  TextStyle? style,
  Key? key,
}) {
  return SizedBox(
    key: key,
    width: isWide ? _standingLastFiveWidth : _standingStatCellWidth,
    height: 20,
    child: Center(
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        style: style ?? Body2.style,
      ),
    ),
  );
}
