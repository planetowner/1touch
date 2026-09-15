part of 'standing_features.dart';

Widget _buildHeaderCell(
  BuildContext context,
  String title, {
  bool isWide = false,
}) {
  return Container(
    width: isWide ? 100 : 44,
    padding: const EdgeInsets.only(right: 8),
    alignment: Alignment.center,
    color: AppColors.of(context).subtleBackground,
    child: Text(title, style: Body2.style),
  );
}

Widget _buildStatCell(
  BuildContext context,
  String text, {
  bool isWide = false,
  TextStyle? style,
}) {
  return Container(
    width: isWide ? 100 : 44,
    height: 44,
    padding: const EdgeInsets.only(right: 8),
    alignment: Alignment.center,
    color: AppColors.of(context).cardBackground,
    child: Text(text, style: style ?? Body2.style),
  );
}
