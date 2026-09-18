import 'package:intl/intl.dart';

final NumberFormat _engagementCountFormat = NumberFormat.decimalPattern(
  'en_US',
);

String formatCommunityEngagementCount(int count) {
  return _engagementCountFormat.format(count);
}
